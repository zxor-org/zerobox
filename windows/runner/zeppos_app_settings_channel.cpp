#include "zeppos_app_settings_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <cwchar>
#include <memory>
#include <string>
#include <variant>

#if defined(ZEROBOX_HAVE_WEBVIEW2)
#include <WebView2.h>
#include <wrl.h>
#endif

namespace {
using flutter::EncodableMap;
using flutter::EncodableValue;
constexpr char kChannel[] = "zerobox/zeppos_app_settings";

const EncodableValue* Get(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

bool GetInteger(const EncodableValue* value, int64_t* result) {
  if (!value) return false;
  if (std::holds_alternative<int32_t>(*value)) {
    *result = std::get<int32_t>(*value);
    return true;
  }
  if (std::holds_alternative<int64_t>(*value)) {
    *result = std::get<int64_t>(*value);
    return true;
  }
  return false;
}

#if defined(ZEROBOX_HAVE_WEBVIEW2)
using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

std::wstring Wide(const std::string& value) {
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                       static_cast<int>(value.size()), nullptr, 0);
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), result.data(), size);
  return result;
}

std::string Utf8(const wchar_t* value) {
  if (!value) return {};
  const int length = static_cast<int>(wcslen(value));
  const int size = WideCharToMultiByte(CP_UTF8, 0, value, length, nullptr, 0,
                                       nullptr, nullptr);
  std::string result(size, '\0');
  if (size > 0) {
    WideCharToMultiByte(CP_UTF8, 0, value, length, result.data(), size, nullptr,
                        nullptr);
  }
  return result;
}

class Session : public std::enable_shared_from_this<Session> {
 public:
  Session(HWND parent, flutter::BinaryMessenger* messenger)
      : parent_(parent), messenger_(messenger) {}
  ~Session() { Close(false); }

  void Open(int64_t app_id, const std::string& title, const std::string& html,
            std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    app_id_ = app_id;
    result_ = std::move(result);
    html_ = Wide(html);

    WNDCLASSW wc{};
    wc.lpfnWndProc = Proc;
    wc.hInstance = GetModuleHandle(nullptr);
    wc.lpszClassName = L"ZeroBoxZeppSettings";
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    static const bool registered = RegisterClassW(&wc) != 0 ||
                                   GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
    if (!registered) {
      Fail("WEBVIEW_FAILED", "Failed to register settings window");
      return;
    }
    window_ = CreateWindowExW(
        WS_EX_DLGMODALFRAME, wc.lpszClassName, Wide(title).c_str(),
        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 760, 800, parent_,
        nullptr, wc.hInstance, this);
    if (!window_) {
      Fail("WEBVIEW_FAILED", "Failed to create settings window");
      return;
    }
    ShowWindow(window_, SW_SHOW);

    const auto self = shared_from_this();
    CreateCoreWebView2EnvironmentWithOptions(
        nullptr, nullptr, nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [self](HRESULT hr, ICoreWebView2Environment* environment) -> HRESULT {
              if (FAILED(hr) || !environment) {
                return self->Fail(
                    "UNAVAILABLE",
                    "Microsoft Edge WebView2 Runtime is unavailable");
              }
              environment->CreateCoreWebView2Controller(
                  self->window_,
                  Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                      [self](HRESULT hr,
                             ICoreWebView2Controller* controller) -> HRESULT {
                        if (FAILED(hr) || !controller || !self->window_) {
                          return self->Fail("WEBVIEW_FAILED",
                                            "Failed to create WebView2");
                        }
                        self->controller_ = controller;
                        self->controller_->get_CoreWebView2(&self->webview_);
                        self->Resize();
                        self->webview_->add_WebMessageReceived(
                            Callback<ICoreWebView2WebMessageReceivedEventHandler>(
                                [self](ICoreWebView2*,
                                       ICoreWebView2WebMessageReceivedEventArgs*
                                           args) -> HRESULT {
                                  LPWSTR raw = nullptr;
                                  if (SUCCEEDED(
                                          args->TryGetWebMessageAsString(&raw)) &&
                                      raw && self->app_id_) {
                                    self->Send(
                                        "bridge",
                                        EncodableMap{
                                            {EncodableValue("appId"),
                                             EncodableValue(self->app_id_)},
                                            {EncodableValue("message"),
                                             EncodableValue(Utf8(raw))}});
                                    CoTaskMemFree(raw);
                                  }
                                  return S_OK;
                                })
                                .Get(),
                            &self->message_token_);
                        self->webview_->NavigateToString(self->html_.c_str());
                        if (self->result_) {
                          self->result_->Success();
                          self->result_.reset();
                        }
                        return S_OK;
                      })
                      .Get());
              return S_OK;
            })
            .Get());
  }

  bool Matches(int64_t app_id) const { return app_id_ == app_id; }

  void Shutdown() { Close(false); }

  void SettingsChanged(const std::string& settings_json) {
    if (!webview_) return;
    const std::wstring script =
        L"globalThis.__zeroboxSettingsChanged(" + Wide(settings_json) + L")";
    webview_->ExecuteScript(script.c_str(), nullptr);
  }

 private:
  static LRESULT CALLBACK Proc(HWND hwnd, UINT message, WPARAM wparam,
                               LPARAM lparam) {
    auto* self = reinterpret_cast<Session*>(
        GetWindowLongPtr(hwnd, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
      self = static_cast<Session*>(
          reinterpret_cast<CREATESTRUCT*>(lparam)->lpCreateParams);
      SetWindowLongPtr(hwnd, GWLP_USERDATA,
                       reinterpret_cast<LONG_PTR>(self));
    }
    if (!self) return DefWindowProc(hwnd, message, wparam, lparam);
    if (message == WM_SIZE) {
      self->Resize();
      return 0;
    }
    if (message == WM_CLOSE) {
      self->Close(true);
      return 0;
    }
    if (message == WM_DESTROY) {
      self->window_ = nullptr;
      return 0;
    }
    return DefWindowProc(hwnd, message, wparam, lparam);
  }

  void Resize() {
    if (!controller_ || !window_) return;
    RECT bounds{};
    GetClientRect(window_, &bounds);
    controller_->put_Bounds(bounds);
  }

  HRESULT Fail(const char* code, const char* message) {
    if (result_) {
      result_->Error(code, message);
      result_.reset();
    }
    Close(false);
    return S_OK;
  }

  void Send(const std::string& method, EncodableMap arguments) {
    flutter::MethodChannel<EncodableValue> channel(
        messenger_, kChannel, &flutter::StandardMethodCodec::GetInstance());
    channel.InvokeMethod(
        method, std::make_unique<EncodableValue>(std::move(arguments)));
  }

  void Close(bool notify) {
    const int64_t app_id = app_id_;
    app_id_ = 0;
    if (notify && app_id) {
      Send("closed", EncodableMap{{EncodableValue("appId"),
                                   EncodableValue(app_id)}});
    }
    if (webview_) webview_->remove_WebMessageReceived(message_token_);
    webview_.Reset();
    if (controller_) controller_->Close();
    controller_.Reset();
    if (window_) {
      const HWND window = window_;
      window_ = nullptr;
      SetWindowLongPtr(window, GWLP_USERDATA, 0);
      DestroyWindow(window);
    }
    html_.clear();
  }

  HWND parent_ = nullptr;
  HWND window_ = nullptr;
  flutter::BinaryMessenger* messenger_;
  int64_t app_id_ = 0;
  std::wstring html_;
  std::unique_ptr<flutter::MethodResult<EncodableValue>> result_;
  ComPtr<ICoreWebView2Controller> controller_;
  ComPtr<ICoreWebView2> webview_;
  EventRegistrationToken message_token_{};
};

std::shared_ptr<Session> session;
#endif
}  // namespace

void RegisterZeppOsAppSettingsChannel(flutter::BinaryMessenger* messenger,
                                      HWND parent_window) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, kChannel, &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [messenger, parent_window](const auto& call, auto result) {
#if defined(ZEROBOX_HAVE_WEBVIEW2)
        if (call.method_name() == "open" && call.arguments() &&
            std::holds_alternative<flutter::EncodableMap>(*call.arguments())) {
          const auto& args =
              std::get<flutter::EncodableMap>(*call.arguments());
          const auto* id = Get(args, "appId");
          const auto* html = Get(args, "html");
          const auto* title = Get(args, "title");
          int64_t app_id = 0;
          if (!GetInteger(id, &app_id) || app_id <= 0 ||
              app_id > UINT32_MAX || !html ||
              !std::holds_alternative<std::string>(*html)) {
            result->Error("INVALID_ARGUMENT");
            return;
          }
          if (session) session->Shutdown();
          session.reset();
          session = std::make_shared<Session>(parent_window, messenger);
          session->Open(
              app_id,
              title && std::holds_alternative<std::string>(*title)
                  ? std::get<std::string>(*title)
                  : "App settings",
              std::get<std::string>(*html), std::move(result));
          return;
        }
        if (call.method_name() == "settingsChanged" && call.arguments() &&
            std::holds_alternative<flutter::EncodableMap>(*call.arguments())) {
          const auto& args =
              std::get<flutter::EncodableMap>(*call.arguments());
          const auto* id = Get(args, "appId");
          const auto* json = Get(args, "settingsJson");
          int64_t app_id = 0;
          if (session && GetInteger(id, &app_id) && session->Matches(app_id) &&
              json && std::holds_alternative<std::string>(*json)) {
            session->SettingsChanged(std::get<std::string>(*json));
          }
          result->Success();
          return;
        }
        result->NotImplemented();
#else
        (void)messenger;
        (void)parent_window;
        (void)call;
        result->Error(
            "UNAVAILABLE",
            "Windows Zepp OS settings require the WebView2 SDK at build time");
#endif
      });
  channel.release();
}

void CloseZeppOsAppSettings() {
#if defined(ZEROBOX_HAVE_WEBVIEW2)
  if (session) session->Shutdown();
  session.reset();
#endif
}
