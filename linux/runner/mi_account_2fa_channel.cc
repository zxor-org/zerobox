#include "mi_account_2fa_channel.h"

#include <cstring>
#include <string>

#include <webkit2/webkit2.h>

namespace {

constexpr char kMethodChannelName[] = "zerobox/mi_account_2fa";

struct TwoFactorSession {
  GtkOverlay* overlay = nullptr;
  GtkWidget* container = nullptr;
  GtkWidget* webview = nullptr;
  FlMethodCall* method_call = nullptr;
  guint poll_source = 0;
  bool completed = false;
};

TwoFactorSession g_session;

struct CookieData {
  GMainLoop* loop = nullptr;
  GList* cookies = nullptr;
  GError* error = nullptr;
};

FlValue* lookup_arg(FlMethodCall* method_call, const char* key) {
  FlValue* args = fl_method_call_get_args(method_call);
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  return fl_value_lookup_string(args, key);
}

void cleanup_session() {
  if (g_session.poll_source != 0) {
    g_source_remove(g_session.poll_source);
    g_session.poll_source = 0;
  }
  if (g_session.container != nullptr) {
    gtk_widget_destroy(g_session.container);
    g_session.container = nullptr;
  }
  g_session.webview = nullptr;
  if (g_session.method_call != nullptr) {
    g_object_unref(g_session.method_call);
    g_session.method_call = nullptr;
  }
  g_session.completed = false;
}

void respond_error(const char* code, const std::string& message) {
  if (g_session.completed || g_session.method_call == nullptr) return;
  g_session.completed = true;
  g_autoptr(GError) error = nullptr;
  fl_method_call_respond_error(g_session.method_call, code, message.c_str(),
                               nullptr, &error);
  cleanup_session();
}

void respond_success(const std::string& cookie_header) {
  if (g_session.completed || g_session.method_call == nullptr) return;
  g_session.completed = true;
  g_autoptr(FlValue) value = fl_value_new_string(cookie_header.c_str());
  g_autoptr(GError) error = nullptr;
  fl_method_call_respond_success(g_session.method_call, value, &error);
  cleanup_session();
}

void cancel_session() {
  respond_error("CANCELLED", "Xiaomi 2FA WebView was closed");
}

void cookies_callback(GObject* object, GAsyncResult* result,
                      gpointer user_data) {
  auto* data = static_cast<CookieData*>(user_data);
  data->cookies = webkit_cookie_manager_get_cookies_finish(
      WEBKIT_COOKIE_MANAGER(object), result, &data->error);
  g_main_loop_quit(data->loop);
}

std::string cookie_header_for_xiaomi(WebKitWebView* webview) {
  WebKitCookieManager* cookie_manager = webkit_web_context_get_cookie_manager(
      webkit_web_view_get_context(webview));
  CookieData data;
  data.loop = g_main_loop_new(nullptr, FALSE);
  webkit_cookie_manager_get_cookies(
      cookie_manager, "https://account.xiaomi.com/", nullptr, cookies_callback,
      &data);
  g_main_loop_run(data.loop);
  g_main_loop_unref(data.loop);
  if (data.error != nullptr) {
    g_error_free(data.error);
    return "";
  }

  std::string header;
  for (GList* item = data.cookies; item != nullptr; item = item->next) {
    SoupCookie* cookie = static_cast<SoupCookie*>(item->data);
    const char* name = soup_cookie_get_name(cookie);
    const char* value = soup_cookie_get_value(cookie);
    if (name != nullptr && value != nullptr && name[0] != '\0' &&
        value[0] != '\0') {
      if (!header.empty()) header += "; ";
      header += name;
      header += "=";
      header += value;
    }
    soup_cookie_free(cookie);
  }
  g_list_free(data.cookies);
  return header;
}

bool has_session_cookie(const std::string& header) {
  return header.find("passToken=") != std::string::npos;
}

std::string normalize_js_string(const char* raw) {
  if (raw == nullptr) return "";
  std::string text(raw);
  if (text.size() >= 2 && text.front() == '"' && text.back() == '"') {
    text = text.substr(1, text.size() - 2);
  }
  for (auto& ch : text) {
    ch = static_cast<char>(g_ascii_tolower(ch));
  }
  while (!text.empty() && g_ascii_isspace(text.front())) {
    text.erase(text.begin());
  }
  while (!text.empty() && g_ascii_isspace(text.back())) {
    text.pop_back();
  }
  return text;
}

void complete_if_ready(bool ok_signal) {
  (void)ok_signal;
  if (g_session.completed || g_session.webview == nullptr) return;
  auto* webview = WEBKIT_WEB_VIEW(g_session.webview);
  const std::string header = cookie_header_for_xiaomi(webview);
  if (!has_session_cookie(header)) return;
  respond_success(header);
}

void js_ok_callback(GObject* object, GAsyncResult* result, gpointer user_data) {
  if (g_session.completed) return;
  GError* error = nullptr;
#if WEBKIT_MAJOR_VERSION < 2 || \
    (WEBKIT_MAJOR_VERSION == 2 && WEBKIT_MINOR_VERSION < 40)
  WebKitJavascriptResult* js_result =
      webkit_web_view_run_javascript_finish(WEBKIT_WEB_VIEW(object), result,
                                            &error);
#else
  JSCValue* js_result =
      webkit_web_view_evaluate_javascript_finish(WEBKIT_WEB_VIEW(object),
                                                 result, &error);
#endif
  if (error != nullptr) {
    g_error_free(error);
    return;
  }
  if (js_result == nullptr) return;

#if WEBKIT_MAJOR_VERSION < 2 || \
    (WEBKIT_MAJOR_VERSION == 2 && WEBKIT_MINOR_VERSION < 40)
  JSCValue* value = webkit_javascript_result_get_js_value(js_result);
#else
  JSCValue* value = js_result;
#endif
  gchar* raw = jsc_value_to_string(value);
  const std::string text = normalize_js_string(raw);
  g_free(raw);
#if WEBKIT_MAJOR_VERSION < 2 || \
    (WEBKIT_MAJOR_VERSION == 2 && WEBKIT_MINOR_VERSION < 40)
  webkit_javascript_result_unref(js_result);
#else
  g_object_unref(js_result);
#endif

  if (text == "ok" ||
      (text.size() > 3 && text.rfind("\\nok") == text.size() - 4)) {
    complete_if_ready(true);
  }
}

void inspect_ok_body() {
  if (g_session.completed || g_session.webview == nullptr) return;
  const char* script = "(document.body && document.body.innerText || '').trim()";
#if WEBKIT_MAJOR_VERSION < 2 || \
    (WEBKIT_MAJOR_VERSION == 2 && WEBKIT_MINOR_VERSION < 40)
  webkit_web_view_run_javascript(WEBKIT_WEB_VIEW(g_session.webview), script,
                                 nullptr, js_ok_callback, nullptr);
#else
  webkit_web_view_evaluate_javascript(WEBKIT_WEB_VIEW(g_session.webview),
                                      script, -1, nullptr, nullptr, nullptr,
                                      js_ok_callback, nullptr);
#endif
}

gboolean poll_session(gpointer user_data) {
  if (g_session.completed || g_session.webview == nullptr) {
    return G_SOURCE_REMOVE;
  }
  complete_if_ready(false);
  inspect_ok_body();
  return G_SOURCE_CONTINUE;
}

void on_load_changed(WebKitWebView* webview, WebKitLoadEvent load_event,
                     gpointer user_data) {
  if (load_event == WEBKIT_LOAD_FINISHED) {
    complete_if_ready(false);
    inspect_ok_body();
  }
}

GtkWidget* build_container(const char* url) {
  GtkWidget* frame = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
  gtk_widget_set_size_request(frame, 480, 640);
  gtk_widget_set_halign(frame, GTK_ALIGN_CENTER);
  gtk_widget_set_valign(frame, GTK_ALIGN_CENTER);
  gtk_widget_set_hexpand(frame, FALSE);
  gtk_widget_set_vexpand(frame, FALSE);
  gtk_widget_set_margin_start(frame, 24);
  gtk_widget_set_margin_end(frame, 24);
  gtk_widget_set_margin_top(frame, 24);
  gtk_widget_set_margin_bottom(frame, 24);

  GtkWidget* header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
  gtk_widget_set_margin_start(header, 12);
  gtk_widget_set_margin_end(header, 12);
  gtk_widget_set_margin_top(header, 8);
  gtk_widget_set_margin_bottom(header, 8);

  GtkWidget* title = gtk_label_new("小米账号验证");
  gtk_widget_set_halign(title, GTK_ALIGN_START);
  gtk_widget_set_hexpand(title, TRUE);
  gtk_box_pack_start(GTK_BOX(header), title, TRUE, TRUE, 0);

  GtkWidget* close_button = gtk_button_new_with_label("关闭");
  g_signal_connect(close_button, "clicked", G_CALLBACK(+[](GtkButton*, gpointer) {
                     cancel_session();
                   }),
                   nullptr);
  gtk_box_pack_end(GTK_BOX(header), close_button, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(frame), header, FALSE, FALSE, 0);

  WebKitWebContext* context = webkit_web_context_new_ephemeral();
  GtkWidget* webview = webkit_web_view_new_with_context(context);
  g_object_unref(context);
  g_session.webview = webview;
  WebKitSettings* settings =
      webkit_web_view_get_settings(WEBKIT_WEB_VIEW(webview));
  webkit_settings_set_enable_javascript(settings, TRUE);
  webkit_settings_set_javascript_can_open_windows_automatically(settings, TRUE);
  g_signal_connect(webview, "load-changed", G_CALLBACK(on_load_changed),
                   nullptr);
  gtk_box_pack_end(GTK_BOX(frame), webview, TRUE, TRUE, 0);
  webkit_web_view_load_uri(WEBKIT_WEB_VIEW(webview), url);

  return frame;
}

void handle_resolve(FlMethodCall* method_call) {
  FlValue* url_value = lookup_arg(method_call, "url");
  if (url_value == nullptr ||
      fl_value_get_type(url_value) != FL_VALUE_TYPE_STRING) {
    g_autoptr(GError) error = nullptr;
    fl_method_call_respond_error(method_call, "INVALID_ARGUMENT",
                                 "url is required", nullptr, &error);
    return;
  }
  if (g_session.method_call != nullptr) {
    g_autoptr(GError) error = nullptr;
    fl_method_call_respond_error(method_call, "BUSY",
                                 "Xiaomi 2FA WebView is already open",
                                 nullptr, &error);
    return;
  }
  if (g_session.overlay == nullptr) {
    g_autoptr(GError) error = nullptr;
    fl_method_call_respond_error(method_call, "UNAVAILABLE",
                                 "2FA overlay is not registered", nullptr,
                                 &error);
    return;
  }

  const char* url = fl_value_get_string(url_value);
  g_session.method_call = method_call;
  g_object_ref(method_call);
  g_session.completed = false;
  g_session.container = build_container(url);
  gtk_overlay_add_overlay(g_session.overlay, g_session.container);
  gtk_widget_show_all(g_session.container);
  g_session.poll_source = g_timeout_add(750, poll_session, nullptr);
}

void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                    gpointer user_data) {
  (void)channel;
  (void)user_data;
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, "resolve") == 0) {
    handle_resolve(method_call);
  } else {
    g_autoptr(GError) error = nullptr;
    fl_method_call_respond_not_implemented(method_call, &error);
  }
}

}  // namespace

void mi_account_2fa_channel_register(FlBinaryMessenger* messenger,
                                     GtkOverlay* overlay) {
  g_session.overlay = overlay;
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      messenger, kMethodChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, nullptr,
                                            nullptr);
}
