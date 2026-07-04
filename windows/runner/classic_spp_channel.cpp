#include "classic_spp_channel.h"

#include <bluetoothapis.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <winsock2.h>
#include <ws2bth.h>

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <iomanip>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

SOCKET g_socket = INVALID_SOCKET;
std::mutex g_socket_mutex;
std::thread g_read_thread;
std::atomic_bool g_read_running(false);
std::unique_ptr<flutter::EventSink<EncodableValue>> g_event_sink;
std::unique_ptr<flutter::EventSink<EncodableValue>> g_scan_event_sink;

std::string WideToUtf8(const wchar_t* text) {
  if (text == nullptr || text[0] == L'\0') {
    return "";
  }
  const int size = WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) {
    return "";
  }
  std::string result(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, -1, result.data(), size, nullptr, nullptr);
  return result;
}

std::string AddressToString(BTH_ADDR addr) {
  std::ostringstream out;
  out << std::uppercase << std::hex << std::setfill('0');
  for (int i = 5; i >= 0; --i) {
    if (i != 5) {
      out << ':';
    }
    out << std::setw(2) << ((addr >> (i * 8)) & 0xff);
  }
  return out.str();
}

bool ParseAddress(const std::string& text, BTH_ADDR* out) {
  std::string digits;
  for (char c : text) {
    if (c == ':' || c == '-' || c == ' ') {
      continue;
    }
    digits.push_back(c);
  }
  if (digits.size() != 12) {
    return false;
  }
  unsigned long long value = 0;
  std::istringstream in(digits);
  in >> std::hex >> value;
  if (in.fail()) {
    return false;
  }
  *out = static_cast<BTH_ADDR>(value);
  return true;
}

EncodableMap DeviceToMap(const BLUETOOTH_DEVICE_INFO& info) {
  return EncodableMap{
      {EncodableValue("addr"), EncodableValue(AddressToString(info.Address.ullLong))},
      {EncodableValue("name"), EncodableValue(WideToUtf8(info.szName))},
      {EncodableValue("connectType"), EncodableValue("spp")},
  };
}

EncodableList PairedDevices() {
  EncodableList devices;
  BLUETOOTH_DEVICE_SEARCH_PARAMS params = {};
  params.dwSize = sizeof(params);
  params.fReturnAuthenticated = TRUE;
  params.fReturnRemembered = TRUE;
  params.fReturnUnknown = FALSE;
  params.fReturnConnected = TRUE;
  params.fIssueInquiry = FALSE;
  params.cTimeoutMultiplier = 2;

  BLUETOOTH_DEVICE_INFO info = {};
  info.dwSize = sizeof(info);
  HBLUETOOTH_DEVICE_FIND handle = BluetoothFindFirstDevice(&params, &info);
  if (handle == nullptr) {
    return devices;
  }
  do {
    auto item = DeviceToMap(info);
    devices.emplace_back(item);
    if (g_scan_event_sink) {
      g_scan_event_sink->Success(EncodableValue(item));
    }
    info = {};
    info.dwSize = sizeof(info);
  } while (BluetoothFindNextDevice(handle, &info));
  BluetoothFindDeviceClose(handle);
  return devices;
}

void CloseSocket() {
  SOCKET socket = INVALID_SOCKET;
  {
    std::lock_guard<std::mutex> lock(g_socket_mutex);
    socket = g_socket;
    g_socket = INVALID_SOCKET;
  }
  if (socket != INVALID_SOCKET) {
    shutdown(socket, SD_BOTH);
    closesocket(socket);
  }
}

void StopReadThread() {
  g_read_running = false;
  CloseSocket();
  if (g_read_thread.joinable()) {
    g_read_thread.join();
  }
}

void StartReadThread() {
  g_read_running = true;
  g_read_thread = std::thread([] {
    std::vector<uint8_t> buffer(4096);
    while (g_read_running) {
      SOCKET socket = INVALID_SOCKET;
      {
        std::lock_guard<std::mutex> lock(g_socket_mutex);
        socket = g_socket;
      }
      if (socket == INVALID_SOCKET) {
        break;
      }
      const int read = recv(socket, reinterpret_cast<char*>(buffer.data()),
                            static_cast<int>(buffer.size()), 0);
      if (read <= 0) {
        break;
      }
      if (g_event_sink) {
        std::vector<uint8_t> packet(buffer.begin(), buffer.begin() + read);
        g_event_sink->Success(EncodableValue(packet));
      }
    }
    g_read_running = false;
  });
}

SOCKET ConnectRfcomm(BTH_ADDR address, int channel) {
  SOCKET socket = ::socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
  if (socket == INVALID_SOCKET) {
    return INVALID_SOCKET;
  }
  SOCKADDR_BTH remote = {};
  remote.addressFamily = AF_BTH;
  remote.btAddr = address;
  remote.port = static_cast<ULONG>(channel);
  if (connect(socket, reinterpret_cast<sockaddr*>(&remote), sizeof(remote)) == SOCKET_ERROR) {
    closesocket(socket);
    return INVALID_SOCKET;
  }
  return socket;
}

std::vector<int> FallbackChannels(const EncodableMap& args) {
  auto it = args.find(EncodableValue("fallbackChannels"));
  if (it == args.end() || !std::holds_alternative<EncodableList>(it->second)) {
    return {5, 1};
  }
  std::vector<int> channels;
  for (const auto& item : std::get<EncodableList>(it->second)) {
    if (!std::holds_alternative<int>(item)) {
      continue;
    }
    int channel = std::get<int>(item);
    if (channel >= 1 && channel <= 30 &&
        std::find(channels.begin(), channels.end(), channel) == channels.end()) {
      channels.push_back(channel);
    }
  }
  if (channels.empty()) {
    channels = {5, 1};
  }
  return channels;
}

void HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  if (call.method_name() == "requestPermissions") {
    result->Success();
    return;
  }
  if (call.method_name() == "startScan") {
    result->Success();
    PairedDevices();
    return;
  }
  if (call.method_name() == "stopScan") {
    result->Success(EncodableValue(PairedDevices()));
    return;
  }
  if (call.method_name() == "disconnect") {
    StopReadThread();
    result->Success();
    return;
  }
  if (!call.arguments() || !std::holds_alternative<EncodableMap>(*call.arguments())) {
    result->Error("INVALID_ARGUMENT", "arguments are required");
    return;
  }
  const auto& args = std::get<EncodableMap>(*call.arguments());

  if (call.method_name() == "connect") {
    auto addr_it = args.find(EncodableValue("addr"));
    if (addr_it == args.end() || !std::holds_alternative<std::string>(addr_it->second)) {
      result->Error("INVALID_ARGUMENT", "addr is required");
      return;
    }
    BTH_ADDR address = 0;
    if (!ParseAddress(std::get<std::string>(addr_it->second), &address)) {
      result->Error("INVALID_ARGUMENT", "addr is invalid");
      return;
    }
    StopReadThread();
    SOCKET connected = INVALID_SOCKET;
    int connected_channel = 0;
    for (int channel : FallbackChannels(args)) {
      connected = ConnectRfcomm(address, channel);
      if (connected != INVALID_SOCKET) {
        connected_channel = channel;
        break;
      }
    }
    if (connected == INVALID_SOCKET) {
      result->Error("CONNECT_FAILED", "No RFCOMM channel available");
      return;
    }
    {
      std::lock_guard<std::mutex> lock(g_socket_mutex);
      g_socket = connected;
    }
    StartReadThread();
    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("channel"), EncodableValue(connected_channel)},
    }));
    return;
  }

  if (call.method_name() == "send") {
    auto data_it = args.find(EncodableValue("data"));
    if (data_it == args.end() || !std::holds_alternative<std::vector<uint8_t>>(data_it->second)) {
      result->Error("INVALID_ARGUMENT", "data is required");
      return;
    }
    SOCKET socket = INVALID_SOCKET;
    {
      std::lock_guard<std::mutex> lock(g_socket_mutex);
      socket = g_socket;
    }
    if (socket == INVALID_SOCKET) {
      result->Error("NOT_CONNECTED", "SPP socket is not connected");
      return;
    }
    const auto& data = std::get<std::vector<uint8_t>>(data_it->second);
    int offset = 0;
    while (offset < static_cast<int>(data.size())) {
      const int sent = send(socket, reinterpret_cast<const char*>(data.data()) + offset,
                            static_cast<int>(data.size()) - offset, 0);
      if (sent <= 0) {
        result->Error("SEND_FAILED", "RFCOMM send failed");
        return;
      }
      offset += sent;
    }
    result->Success();
    return;
  }

  result->NotImplemented();
}

}  // namespace

void RegisterRfcommChannel(flutter::BinaryMessenger* messenger) {
  WSADATA data;
  WSAStartup(MAKEWORD(2, 2), &data);

  auto method_channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "zerobox/classic_spp",
      &flutter::StandardMethodCodec::GetInstance());
  method_channel->SetMethodCallHandler(HandleMethodCall);
  method_channel.release();

  auto event_channel = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger, "zerobox/classic_spp/events",
      &flutter::StandardMethodCodec::GetInstance());
  event_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [](const EncodableValue*,
             std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            g_event_sink = std::move(events);
            return nullptr;
          },
          [](const EncodableValue*)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            g_event_sink.reset();
            return nullptr;
          }));
  event_channel.release();

  auto scan_channel = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger, "zerobox/classic_spp/scan_events",
      &flutter::StandardMethodCodec::GetInstance());
  scan_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [](const EncodableValue*,
             std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            g_scan_event_sink = std::move(events);
            return nullptr;
          },
          [](const EncodableValue*)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            g_scan_event_sink.reset();
            return nullptr;
          }));
  scan_channel.release();
}
