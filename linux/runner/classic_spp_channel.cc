#include "classic_spp_channel.h"

#include <bluetooth/bluetooth.h>
#include <bluetooth/rfcomm.h>
#include <errno.h>
#include <fcntl.h>
#include <gio/gio.h>
#include <glib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

#include <atomic>
#include <algorithm>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <map>
#include <memory>
#include <mutex>
#include <queue>
#include <string>
#include <thread>
#include <vector>

namespace {

constexpr char kMethodChannelName[] = "zerobox/classic_spp";
constexpr char kEventChannelName[] = "zerobox/classic_spp/events";
constexpr char kScanEventChannelName[] = "zerobox/classic_spp/scan_events";
constexpr char kBluezBusName[] = "org.bluez";
constexpr char kBluezObjectPath[] = "/";
constexpr char kBluezObjectManagerInterface[] = "org.freedesktop.DBus.ObjectManager";
constexpr char kBluezAdapterInterface[] = "org.bluez.Adapter1";
constexpr char kBluezDeviceInterface[] = "org.bluez.Device1";

std::mutex g_mutex;
int g_fd = -1;
std::thread g_read_thread;
std::atomic_bool g_running(false);
FlEventChannel* g_event_channel = nullptr;
FlEventChannel* g_scan_event_channel = nullptr;

struct ScanDevice {
  std::string addr;
  std::string name;
};

std::mutex g_scan_mutex;
std::map<std::string, ScanDevice> g_scan_results;
std::thread g_scan_thread;
std::atomic_bool g_scan_running(false);

struct EventPayload {
  std::vector<uint8_t> data;
};

struct ScanEventPayload {
  ScanDevice device;
};

struct SendRequest {
  std::vector<uint8_t> data;
  FlMethodCall* method_call;
  std::string error_message;
};

std::thread g_send_thread;
std::mutex g_send_mutex;
std::condition_variable g_send_cv;
std::queue<std::unique_ptr<SendRequest>> g_send_queue;
std::atomic_bool g_send_running(false);

void respond_error(FlMethodCall* method_call, const char* code,
                   const std::string& message);

gboolean send_completed_on_main(gpointer user_data) {
  auto* request = static_cast<SendRequest*>(user_data);
  g_autoptr(GError) error = nullptr;
  fl_method_call_respond_success(request->method_call, nullptr, &error);
  g_object_unref(request->method_call);
  delete request;
  return G_SOURCE_REMOVE;
}

gboolean send_failed_on_main(gpointer user_data) {
  auto* request = static_cast<SendRequest*>(user_data);
  respond_error(request->method_call, "send_failed",
                request->error_message.empty() ? "send failed"
                                               : request->error_message);
  g_object_unref(request->method_call);
  delete request;
  return G_SOURCE_REMOVE;
}

void send_worker_loop() {
  while (g_send_running) {
    std::unique_ptr<SendRequest> request;
    {
      std::unique_lock<std::mutex> lock(g_send_mutex);
      g_send_cv.wait(lock, [] { return !g_send_queue.empty() || !g_send_running; });
      if (!g_send_running) break;
      request = std::move(g_send_queue.front());
      g_send_queue.pop();
    }

    int fd = -1;
    {
      std::lock_guard<std::mutex> lock(g_mutex);
      fd = g_fd;
    }
    if (fd < 0) {
      g_main_context_invoke(nullptr, send_failed_on_main, request.release());
      continue;
    }

    const uint8_t* data = request->data.data();
    const size_t length = request->data.size();
    size_t written = 0;
    while (written < length) {
      const size_t chunk = std::min<size_t>(512, length - written);
      ssize_t n = send(fd, data + written, chunk, 0);
      if (n < 0) {
        if (errno == EINTR) continue;
        request->error_message =
            std::string("send failed after ") + std::to_string(written) +
            "/" + std::to_string(length) + " bytes: " + strerror(errno);
        break;
      }
      if (n == 0) {
        request->error_message =
            std::string("send returned 0 after ") + std::to_string(written) +
            "/" + std::to_string(length) + " bytes";
        break;
      }
      written += static_cast<size_t>(n);
    }

    g_main_context_invoke(
        nullptr,
        [](gpointer data) -> gboolean {
          auto* req = static_cast<SendRequest*>(data);
          if (!req->error_message.empty()) {
            send_failed_on_main(data);
          } else {
            send_completed_on_main(data);
          }
          return G_SOURCE_REMOVE;
        },
        request.release());
  }
}

void start_send_worker() {
  g_send_running = true;
  g_send_thread = std::thread(send_worker_loop);
}

void stop_send_worker() {
  {
    std::lock_guard<std::mutex> lock(g_send_mutex);
    g_send_running = false;
  }
  g_send_cv.notify_all();
  if (g_send_thread.joinable()) {
    g_send_thread.join();
  }
  std::queue<std::unique_ptr<SendRequest>> pending;
  {
    std::lock_guard<std::mutex> lock(g_send_mutex);
    pending.swap(g_send_queue);
  }
  while (!pending.empty()) {
    auto request = std::move(pending.front());
    pending.pop();
    request->error_message = "SPP send cancelled";
    g_main_context_invoke(nullptr, send_failed_on_main, request.release());
  }
}

void enqueue_send(std::unique_ptr<SendRequest> request) {
  {
    std::lock_guard<std::mutex> lock(g_send_mutex);
    g_send_queue.push(std::move(request));
  }
  g_send_cv.notify_one();
}

struct ConnectResult {
  bool success = false;
  int fd = -1;
  uint8_t channel = 0;
  std::string error;
  FlMethodCall* method_call = nullptr;
};

FlValue* lookup_arg(FlMethodCall* method_call, const char* key);
void respond_error(FlMethodCall* method_call, const char* code,
                   const std::string& message);

gboolean send_event_on_main(gpointer user_data) {
  std::unique_ptr<EventPayload> payload(static_cast<EventPayload*>(user_data));
  if (g_event_channel == nullptr || payload->data.empty()) {
    return G_SOURCE_REMOVE;
  }
  g_autoptr(FlValue) value =
      fl_value_new_uint8_list(payload->data.data(), payload->data.size());
  g_autoptr(GError) error = nullptr;
  fl_event_channel_send(g_event_channel, value, nullptr, &error);
  return G_SOURCE_REMOVE;
}

FlValue* scan_device_to_value(const ScanDevice& device) {
  FlValue* value = fl_value_new_map();
  fl_value_set_string_take(value, "addr", fl_value_new_string(device.addr.c_str()));
  fl_value_set_string_take(
      value, "name",
      fl_value_new_string(device.name.empty() ? "Unknown device" : device.name.c_str()));
  return value;
}

gboolean send_scan_event_on_main(gpointer user_data) {
  std::unique_ptr<ScanEventPayload> payload(
      static_cast<ScanEventPayload*>(user_data));
  if (g_scan_event_channel == nullptr || payload->device.addr.empty()) {
    return G_SOURCE_REMOVE;
  }
  g_autoptr(FlValue) value = scan_device_to_value(payload->device);
  g_autoptr(GError) error = nullptr;
  fl_event_channel_send(g_scan_event_channel, value, nullptr, &error);
  return G_SOURCE_REMOVE;
}

bool remember_scan_device(const ScanDevice& device, bool emit) {
  if (device.addr.empty()) {
    return false;
  }
  bool inserted = false;
  {
    std::lock_guard<std::mutex> lock(g_scan_mutex);
    inserted = g_scan_results.find(device.addr) == g_scan_results.end();
    g_scan_results[device.addr] = device;
  }
  if (emit && inserted) {
    auto* payload = new ScanEventPayload();
    payload->device = device;
    g_main_context_invoke(nullptr, send_scan_event_on_main, payload);
  }
  return inserted;
}

GVariant* lookup_variant_child(GVariant* properties, const char* key) {
  if (properties == nullptr) {
    return nullptr;
  }
  g_autoptr(GVariant) boxed = g_variant_lookup_value(
      properties, key, G_VARIANT_TYPE_VARIANT);
  if (boxed == nullptr) {
    return nullptr;
  }
  return g_variant_get_variant(boxed);
}

std::string lookup_string_property(GVariant* properties, const char* key) {
  g_autoptr(GVariant) value = lookup_variant_child(properties, key);
  if (value == nullptr || !g_variant_is_of_type(value, G_VARIANT_TYPE_STRING)) {
    return "";
  }
  return g_variant_get_string(value, nullptr);
}

ScanDevice scan_device_from_properties(GVariant* properties) {
  ScanDevice device;
  device.addr = lookup_string_property(properties, "Address");
  device.name = lookup_string_property(properties, "Alias");
  if (device.name.empty()) {
    device.name = lookup_string_property(properties, "Name");
  }
  return device;
}

GDBusConnection* get_system_bus(GError** error) {
  return g_bus_get_sync(G_BUS_TYPE_SYSTEM, nullptr, error);
}

std::string find_bluez_adapter_path(GDBusConnection* connection) {
  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) result = g_dbus_connection_call_sync(
      connection, kBluezBusName, kBluezObjectPath, kBluezObjectManagerInterface,
      "GetManagedObjects", nullptr, G_VARIANT_TYPE("(a{oa{sa{sv}}})"),
      G_DBUS_CALL_FLAGS_NONE, 5000, nullptr, &error);
  if (result == nullptr) {
    return "";
  }

  GVariantIter* objects = nullptr;
  g_variant_get(result, "(a{oa{sa{sv}}})", &objects);
  const gchar* object_path = nullptr;
  GVariant* interfaces = nullptr;
  std::string adapter_path;
  while (g_variant_iter_loop(objects, "{o@a{sa{sv}}}", &object_path,
                             &interfaces)) {
    if (g_variant_lookup_value(interfaces, kBluezAdapterInterface,
                               G_VARIANT_TYPE("a{sv}")) != nullptr) {
      adapter_path = object_path;
      break;
    }
  }
  g_variant_iter_free(objects);
  return adapter_path;
}

bool call_bluez_adapter_method(const char* method, std::string* error_out) {
  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusConnection) connection = get_system_bus(&error);
  if (connection == nullptr) {
    if (error_out != nullptr) {
      *error_out = error == nullptr ? "failed to open system bus" : error->message;
    }
    return false;
  }

  std::string adapter_path = find_bluez_adapter_path(connection);
  if (adapter_path.empty()) {
    if (error_out != nullptr) {
      *error_out = "no BlueZ adapter found";
    }
    return false;
  }

  g_autoptr(GVariant) result = g_dbus_connection_call_sync(
      connection, kBluezBusName, adapter_path.c_str(), kBluezAdapterInterface,
      method, nullptr, nullptr, G_DBUS_CALL_FLAGS_NONE, 5000, nullptr, &error);
  if (result == nullptr) {
    if (error_out != nullptr) {
      *error_out = error == nullptr ? "BlueZ adapter call failed" : error->message;
    }
    return false;
  }
  return true;
}

void collect_bluez_devices(bool emit) {
  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusConnection) connection = get_system_bus(&error);
  if (connection == nullptr) {
    return;
  }
  g_autoptr(GVariant) result = g_dbus_connection_call_sync(
      connection, kBluezBusName, kBluezObjectPath, kBluezObjectManagerInterface,
      "GetManagedObjects", nullptr, G_VARIANT_TYPE("(a{oa{sa{sv}}})"),
      G_DBUS_CALL_FLAGS_NONE, 5000, nullptr, &error);
  if (result == nullptr) {
    return;
  }

  GVariantIter* objects = nullptr;
  g_variant_get(result, "(a{oa{sa{sv}}})", &objects);
  const gchar* object_path = nullptr;
  GVariant* interfaces = nullptr;
  while (g_variant_iter_loop(objects, "{o@a{sa{sv}}}", &object_path,
                             &interfaces)) {
    g_autoptr(GVariant) properties = g_variant_lookup_value(
        interfaces, kBluezDeviceInterface, G_VARIANT_TYPE("a{sv}"));
    if (properties == nullptr) {
      continue;
    }
    remember_scan_device(scan_device_from_properties(properties), emit);
  }
  g_variant_iter_free(objects);
}

void close_socket_locked() {
  if (g_fd >= 0) {
    shutdown(g_fd, SHUT_RDWR);
    close(g_fd);
    g_fd = -1;
  }
}

void stop_scan_worker();

void stop_reader_and_socket() {
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_running = false;
    close_socket_locked();
  }
  if (g_read_thread.joinable()) {
    g_read_thread.join();
  }
}

void stop_all() {
  stop_scan_worker();
  stop_reader_and_socket();
  stop_send_worker();
}

bool connect_rfcomm(const std::string& addr, uint8_t channel, int timeout_sec,
                    std::string* error_out, int* fd_out) {
  int fd = socket(AF_BLUETOOTH, SOCK_STREAM, BTPROTO_RFCOMM);
  if (fd < 0) {
    *error_out = std::string("socket failed: ") + strerror(errno);
    return false;
  }

  sockaddr_rc remote = {};
  remote.rc_family = AF_BLUETOOTH;
  remote.rc_channel = channel;
  if (str2ba(addr.c_str(), &remote.rc_bdaddr) != 0) {
    *error_out = "invalid bluetooth address";
    close(fd);
    return false;
  }

  int flags = fcntl(fd, F_GETFL, 0);
  fcntl(fd, F_SETFL, flags | O_NONBLOCK);

  int rc = connect(fd, reinterpret_cast<sockaddr*>(&remote), sizeof(remote));
  if (rc < 0 && errno != EINPROGRESS) {
    *error_out = std::string("connect failed on channel ") +
                 std::to_string(channel) + ": " + strerror(errno);
    close(fd);
    return false;
  }

  if (rc < 0) {
    fd_set write_fds;
    FD_ZERO(&write_fds);
    FD_SET(fd, &write_fds);
    timeval tv = {};
    tv.tv_sec = timeout_sec;
    rc = select(fd + 1, nullptr, &write_fds, nullptr, &tv);
    if (rc <= 0) {
      *error_out = rc == 0 ? "connect timed out" : strerror(errno);
      close(fd);
      return false;
    }

    int socket_error = 0;
    socklen_t len = sizeof(socket_error);
    if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &socket_error, &len) < 0 ||
        socket_error != 0) {
      *error_out = std::string("connect failed on channel ") +
                   std::to_string(channel) + ": " +
                   strerror(socket_error == 0 ? errno : socket_error);
      close(fd);
      return false;
    }
  }

  fcntl(fd, F_SETFL, flags);
  *fd_out = fd;
  return true;
}

void start_reader() {
  g_running = true;
  g_read_thread = std::thread([] {
    while (g_running) {
      int fd = -1;
      {
        std::lock_guard<std::mutex> lock(g_mutex);
        fd = g_fd;
      }
      if (fd < 0) {
        break;
      }

      uint8_t buffer[4096];
      ssize_t n = recv(fd, buffer, sizeof(buffer), 0);
      if (n > 0) {
        auto* payload = new EventPayload();
        payload->data.assign(buffer, buffer + n);
        g_main_context_invoke(
            nullptr, [](gpointer data) -> gboolean {
              send_event_on_main(data);
              return G_SOURCE_REMOVE;
            },
            payload);
      } else if (n == 0 || (errno != EINTR && errno != EAGAIN)) {
        break;
      }
    }
    g_running = false;
  });
}

void finish_connect_on_main(gpointer user_data) {
  std::unique_ptr<ConnectResult> result(
      static_cast<ConnectResult*>(user_data));

  if (!result->success || result->fd < 0) {
    respond_error(result->method_call, "connect_failed",
                  result->error.empty() ? "connect failed" : result->error);
    return;
  }

  {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_fd = result->fd;
  }
  start_reader();
  start_send_worker();

  g_autoptr(FlValue) response = fl_value_new_map();
  fl_value_set_string_take(response, "channel",
                           fl_value_new_int(result->channel));
  g_autoptr(GError) error = nullptr;
  fl_method_call_respond_success(result->method_call, response, &error);
}

FlValue* lookup_arg(FlMethodCall* method_call, const char* key) {
  FlValue* args = fl_method_call_get_args(method_call);
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  return fl_value_lookup_string(args, key);
}

void respond_error(FlMethodCall* method_call, const char* code,
                   const std::string& message) {
  g_autoptr(GError) error = nullptr;
  fl_method_call_respond_error(method_call, code, message.c_str(), nullptr,
                               &error);
}

void handle_connect_async(std::string addr, std::vector<uint8_t> channels,
                          FlMethodCall* method_call) {
  std::thread([addr, channels, method_call]() {
    std::string last_error;
    int connected_fd = -1;
    uint8_t connected_channel = 0;

    for (uint8_t channel : channels) {
      if (connect_rfcomm(addr, channel, 10, &last_error, &connected_fd)) {
        connected_channel = channel;
        break;
      }
    }

    if (connected_fd < 0) {
      std::this_thread::sleep_for(std::chrono::milliseconds(300));
      for (uint8_t channel : channels) {
        if (connect_rfcomm(addr, channel, 10, &last_error, &connected_fd)) {
          connected_channel = channel;
          break;
        }
      }
    }

    auto* result = new ConnectResult();
    result->method_call = method_call;
    if (connected_fd >= 0) {
      result->success = true;
      result->fd = connected_fd;
      result->channel = connected_channel;
    } else {
      result->success = false;
      result->error = last_error;
    }
    g_main_context_invoke(
        nullptr, [](gpointer data) -> gboolean {
          finish_connect_on_main(data);
          return G_SOURCE_REMOVE;
        },
        result);
  }).detach();
}

void handle_connect(FlMethodCall* method_call) {
  FlValue* addr_value = lookup_arg(method_call, "addr");
  if (addr_value == nullptr ||
      fl_value_get_type(addr_value) != FL_VALUE_TYPE_STRING) {
    respond_error(method_call, "bad_args", "addr is required");
    return;
  }

  std::string addr = fl_value_get_string(addr_value);
  std::vector<uint8_t> channels;
  FlValue* channels_value = lookup_arg(method_call, "fallbackChannels");
  if (channels_value != nullptr &&
      fl_value_get_type(channels_value) == FL_VALUE_TYPE_LIST) {
    const size_t length = fl_value_get_length(channels_value);
    for (size_t i = 0; i < length; i++) {
      FlValue* item = fl_value_get_list_value(channels_value, i);
      if (item == nullptr || fl_value_get_type(item) != FL_VALUE_TYPE_INT) {
        continue;
      }
      const int64_t raw = fl_value_get_int(item);
      if (raw >= 1 && raw <= 30) {
        channels.push_back(static_cast<uint8_t>(raw));
      }
    }
  }
  if (channels.empty()) {
    channels = {5, 1};
  }
  stop_all();

  // Keep the method_call alive while the background thread works.
  g_object_ref(method_call);
  handle_connect_async(addr, channels, method_call);
}

void handle_send(FlMethodCall* method_call) {
  FlValue* data_value = lookup_arg(method_call, "data");
  if (data_value == nullptr ||
      fl_value_get_type(data_value) != FL_VALUE_TYPE_UINT8_LIST) {
    respond_error(method_call, "bad_args", "data is required");
    return;
  }

  {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_fd < 0) {
      respond_error(method_call, "disconnected", "SPP socket is not connected");
      return;
    }
  }

  const uint8_t* data = fl_value_get_uint8_list(data_value);
  size_t length = fl_value_get_length(data_value);

  auto* request = new SendRequest();
  request->data.assign(data, data + length);
  request->method_call = method_call;
  g_object_ref(method_call);
  enqueue_send(std::unique_ptr<SendRequest>(request));
}

void handle_disconnect(FlMethodCall* method_call) {
  stop_all();
  g_autoptr(GError) error = nullptr;
  fl_method_call_respond_success(method_call, nullptr, &error);
}

int scan_timeout_from_method_call(FlMethodCall* method_call) {
  FlValue* timeout_value = lookup_arg(method_call, "timeoutMs");
  if (timeout_value == nullptr ||
      fl_value_get_type(timeout_value) != FL_VALUE_TYPE_INT) {
    return 15000;
  }
  const int64_t timeout = fl_value_get_int(timeout_value);
  if (timeout <= 0) {
    return 15000;
  }
  return static_cast<int>(std::min<int64_t>(timeout, 60000));
}

void stop_scan_worker() {
  g_scan_running = false;
  if (g_scan_thread.joinable()) {
    g_scan_thread.join();
  }
}

void handle_start_scan(FlMethodCall* method_call) {
  stop_scan_worker();
  {
    std::lock_guard<std::mutex> lock(g_scan_mutex);
    g_scan_results.clear();
  }

  std::string error_message;
  if (!call_bluez_adapter_method("StartDiscovery", &error_message)) {
    respond_error(method_call, "scan_failed",
                  error_message.empty() ? "failed to start BlueZ discovery"
                                        : error_message);
    return;
  }

  const int timeout_ms = scan_timeout_from_method_call(method_call);
  g_scan_running = true;
  g_scan_thread = std::thread([timeout_ms]() {
    const auto started = std::chrono::steady_clock::now();
    while (g_scan_running) {
      collect_bluez_devices(true);
      const auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
          std::chrono::steady_clock::now() - started);
      if (elapsed.count() >= timeout_ms) {
        break;
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(700));
    }
    g_scan_running = false;
    std::string ignored;
    call_bluez_adapter_method("StopDiscovery", &ignored);
    collect_bluez_devices(true);
  });

  g_autoptr(GError) error = nullptr;
  fl_method_call_respond_success(method_call, nullptr, &error);
}

void handle_stop_scan(FlMethodCall* method_call) {
  stop_scan_worker();
  std::string ignored;
  call_bluez_adapter_method("StopDiscovery", &ignored);
  collect_bluez_devices(false);

  g_autoptr(FlValue) response = fl_value_new_list();
  {
    std::lock_guard<std::mutex> lock(g_scan_mutex);
    for (const auto& item : g_scan_results) {
      fl_value_append_take(response, scan_device_to_value(item.second));
    }
  }
  g_autoptr(GError) error = nullptr;
  fl_method_call_respond_success(method_call, response, &error);
}

void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                    gpointer user_data) {
  (void)channel;
  (void)user_data;
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, "requestPermissions") == 0) {
    g_autoptr(GError) error = nullptr;
    fl_method_call_respond_success(method_call, nullptr, &error);
  } else if (strcmp(method, "startScan") == 0) {
    handle_start_scan(method_call);
  } else if (strcmp(method, "stopScan") == 0) {
    handle_stop_scan(method_call);
  } else if (strcmp(method, "connect") == 0) {
    handle_connect(method_call);
  } else if (strcmp(method, "send") == 0) {
    handle_send(method_call);
  } else if (strcmp(method, "disconnect") == 0) {
    handle_disconnect(method_call);
  } else {
    g_autoptr(GError) error = nullptr;
    fl_method_call_respond_not_implemented(method_call, &error);
  }
}

FlMethodErrorResponse* event_listen_cb(FlEventChannel* channel, FlValue* args,
                                       gpointer user_data) {
  (void)channel;
  (void)args;
  (void)user_data;
  return nullptr;
}

FlMethodErrorResponse* event_cancel_cb(FlEventChannel* channel, FlValue* args,
                                       gpointer user_data) {
  (void)channel;
  (void)args;
  (void)user_data;
  return nullptr;
}

}  // namespace

void classic_spp_channel_register(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) method_codec =
      fl_standard_method_codec_new();
  FlMethodChannel* method_channel = fl_method_channel_new(
      messenger, kMethodChannelName, FL_METHOD_CODEC(method_codec));
  fl_method_channel_set_method_call_handler(method_channel, method_call_cb,
                                            nullptr, nullptr);

  g_autoptr(FlStandardMethodCodec) event_codec = fl_standard_method_codec_new();
  g_event_channel = fl_event_channel_new(messenger, kEventChannelName,
                                         FL_METHOD_CODEC(event_codec));
  fl_event_channel_set_stream_handlers(g_event_channel, event_listen_cb,
                                       event_cancel_cb, nullptr, nullptr);

  g_autoptr(FlStandardMethodCodec) scan_event_codec =
      fl_standard_method_codec_new();
  g_scan_event_channel = fl_event_channel_new(
      messenger, kScanEventChannelName, FL_METHOD_CODEC(scan_event_codec));
  fl_event_channel_set_stream_handlers(g_scan_event_channel, event_listen_cb,
                                       event_cancel_cb, nullptr, nullptr);
}
