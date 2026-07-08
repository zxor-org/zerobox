#include "mi_account_2fa_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <algorithm>
#include <cctype>
#include <memory>
#include <sstream>
#include <string>
#include <utility>
#include <variant>

#if defined(ZEROBOX_HAVE_WEBVIEW2)
#include <WebView2.h>
#include <wrl.h>
#endif

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodResult;

constexpr char kChannelName[] = "zerobox/mi_account_2fa";

#if defined(ZEROBOX_HAVE_WEBVIEW2)

constexpr wchar_t kWindowClassName[] = L"ZeroBoxMiAccount2FAWindow";
constexpr UINT_PTR kPollTimerId = 1;
constexpr UINT kPollIntervalMs = 750;

std::wstring Utf8ToWide(const std::string& text) {
  if (text.empty()) {
    return L"";
  }
  const int size = MultiByteToWideChar(CP_UTF8, 0, text.data(),
                                       static_cast<int>(text.size()), nullptr,
                                       0);
  if (size <= 0) {
    return L"";
  }
  std::wstring result(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      result.data(), size);
  return result;
}

std::string WideToUtf8(const wchar_t* text) {
  if (text == nullptr || text[0] == L'\0') {
    return "";
  }
  const int size =
      WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) {
    return "";
  }
  std::string result(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, -1, result.data(), size, nullptr,
                      nullptr);
  return result;
}

std::string TrimLower(std::string text) {
  auto is_space = [](unsigned char ch) { return std::isspace(ch) != 0; };
  while (!text.empty() && is_space(static_cast<unsigned char>(text.front()))) {
    text.erase(text.begin());
  }
  while (!text.empty() && is_space(static_cast<unsigned char>(text.back()))) {
    text.pop_back();
  }
  std::transform(text.begin(), text.end(), text.begin(), [](unsigned char ch) {
    return static_cast<char>(std::tolower(ch));
  });
  return text;
}

std::string DecodeJsonString(const std::wstring& json) {
  if (json.size() < 2 || json.front() != L'"' || json.back() != L'"') {
    return TrimLower(WideToUtf8(json.c_str()));
  }

  std::wstring decoded;
  decoded.reserve(json.size());
  for (size_t i = 1; i + 1 < json.size(); ++i) {
    wchar_t ch = json[i];
    if (ch != L'\\' || i + 1 >= json.size() - 1) {
      decoded.push_back(ch);
      continue;
    }
    wchar_t escaped = json[++i];
    switch (escaped) {
      case L'n':
        decoded.push_back(L'\n');
        break;
      case L'r':
        decoded.push_back(L'\r');
        break;
      case L't':
        decoded.push_back(L'\t');
        break;
      case L'"':
      case L'\\':
      case L'/':
        decoded.push_back(escaped);
        break;
      default:
        decoded.push_back(escaped);
        break;
    }
  }
  return TrimLower(WideToUtf8(decoded.c_str()));
}

bool HasSessionCookie(const std::string& header) {
  return header.find("passToken=") != std::string::npos ||
         header.find("cUserId=") != std::string::npos ||
         header.find("userId=") != std::string::npos;
}

std::string HResultMessage(HRESULT hr) {
  std::ostringstream out;
  out << "WebView2 failed with HRESULT 0x" << std::hex
      << static_cast<unsigned long>(hr);
  return out.str();
}

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

class WinMiAccountTwoFactorSession {
 public:
  WinMiAccountTwoFactorSession(
      HWND parent_window,
      std::unique_ptr<MethodResult<EncodableValue>> result)
      : parent_window_(parent_window), result_(std::move(result)) {}

  ~WinMiAccountTwoFactorSession() {
    if (window_ != nullptr) {
      SetWindowLongPtr(window_, GWLP_USERDATA, 0);
      DestroyWindow(window_);
      window_ = nullptr;
    }
  }

  void Start(const std::string& url);

 private:
  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) {
    auto* session = reinterpret_cast<WinMiAccountTwoFactorSession*>(
        GetWindowLongPtr(window, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
      const auto* create_struct =
          reinterpret_cast<CREATESTRUCT*>(lparam);
      session = static_cast<WinMiAccountTwoFactorSession*>(
          create_struct->lpCreateParams);
      SetWindowLongPtr(window, GWLP_USERDATA,
                       reinterpret_cast<LONG_PTR>(session));
    }
    if (session != nullptr) {
      return session->HandleMessage(window, message, wparam, lparam);
    }
    return DefWindowProc(window, message, wparam, lparam);
  }

  static void EnsureWindowClass() {
    static bool registered = false;
    if (registered) {
      return;
    }
    WNDCLASSW window_class = {};
    window_class.lpfnWndProc = WindowProc;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.lpszClassName = kWindowClassName;
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    RegisterClassW(&window_class);
    registered = true;
  }

  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam) {
    switch (message) {
      case WM_SIZE:
        ResizeWebView();
        return 0;
      case WM_TIMER:
        if (wparam == kPollTimerId) {
          CompleteIfReady();
          InspectBody();
          return 0;
        }
        break;
      case WM_CLOSE:
        Cancel();
        return 0;
      case WM_DESTROY:
        window_ = nullptr;
        return 0;
    }
    return DefWindowProc(window, message, wparam, lparam);
  }

  void CreateWebView();

  void ResizeWebView() {
    if (!controller_ || window_ == nullptr) {
      return;
    }
    RECT bounds{};
    GetClientRect(window_, &bounds);
    controller_->put_Bounds(bounds);
  }

  void CompleteIfReady();
  void InspectBody();
  void FinishSuccess(const std::string& cookie_header);
  void Fail(const std::string& code, const std::string& message);
  void Cancel() {
    Fail("CANCELLED", "Xiaomi 2FA WebView was closed");
  }

  HWND parent_window_ = nullptr;
  HWND window_ = nullptr;
  std::string url_;
  std::unique_ptr<MethodResult<EncodableValue>> result_;
  ComPtr<ICoreWebView2Controller> controller_;
  ComPtr<ICoreWebView2> webview_;
  EventRegistrationToken navigation_completed_token_{};
  bool completed_ = false;
  bool checking_cookies_ = false;
};

std::unique_ptr<WinMiAccountTwoFactorSession> g_session;

void WinMiAccountTwoFactorSession::Start(const std::string& url) {
  url_ = url;
  EnsureWindowClass();

  RECT parent_rect{0, 0, 980, 720};
  if (parent_window_ != nullptr) {
    GetWindowRect(parent_window_, &parent_rect);
  }
  const int width = 980;
  const int height = 720;
  const int x = parent_rect.left +
                ((parent_rect.right - parent_rect.left) - width) / 2;
  const int y = parent_rect.top +
                ((parent_rect.bottom - parent_rect.top) - height) / 2;

  window_ = CreateWindowExW(
      WS_EX_DLGMODALFRAME, kWindowClassName, L"Xiaomi account verification",
      WS_OVERLAPPEDWINDOW, x, y, width, height, parent_window_, nullptr,
      GetModuleHandle(nullptr), this);
  if (window_ == nullptr) {
    Fail("WEBVIEW_FAILED", "Failed to create Xiaomi 2FA window");
    return;
  }

  ShowWindow(window_, SW_SHOW);
  UpdateWindow(window_);
  CreateWebView();
}

void WinMiAccountTwoFactorSession::CreateWebView() {
  HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
      nullptr, nullptr, nullptr,
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [this](HRESULT result, ICoreWebView2Environment* environment)
              -> HRESULT {
            if (FAILED(result) || environment == nullptr) {
              Fail("UNAVAILABLE",
                   "Microsoft Edge WebView2 Runtime is not available");
              return S_OK;
            }
            environment->CreateCoreWebView2Controller(
                window_,
                Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                    [this](HRESULT controller_result,
                           ICoreWebView2Controller* controller) -> HRESULT {
                      if (FAILED(controller_result) || controller == nullptr) {
                        Fail("WEBVIEW_FAILED",
                             HResultMessage(controller_result));
                        return S_OK;
                      }
                      controller_ = controller;
                      controller_->get_CoreWebView2(&webview_);
                      if (!webview_) {
                        Fail("WEBVIEW_FAILED", "WebView2 core is not available");
                        return S_OK;
                      }

                      webview_->add_NavigationCompleted(
                          Callback<ICoreWebView2NavigationCompletedEventHandler>(
                              [this](ICoreWebView2*,
                                     ICoreWebView2NavigationCompletedEventArgs*)
                                  -> HRESULT {
                                CompleteIfReady();
                                InspectBody();
                                return S_OK;
                              })
                              .Get(),
                          &navigation_completed_token_);
                      ResizeWebView();
                      webview_->Navigate(Utf8ToWide(url_).c_str());
                      SetTimer(window_, kPollTimerId, kPollIntervalMs, nullptr);
                      return S_OK;
                    })
                    .Get());
            return S_OK;
          })
          .Get());

  if (FAILED(hr)) {
    Fail("UNAVAILABLE", "Microsoft Edge WebView2 Runtime is not available");
  }
}

void WinMiAccountTwoFactorSession::CompleteIfReady() {
  if (completed_ || checking_cookies_ || !webview_) {
    return;
  }

  ComPtr<ICoreWebView2_2> webview2;
  if (FAILED(webview_.As(&webview2)) || !webview2) {
    return;
  }

  ComPtr<ICoreWebView2CookieManager> cookie_manager;
  if (FAILED(webview2->get_CookieManager(&cookie_manager)) ||
      !cookie_manager) {
    return;
  }

  LPWSTR source = nullptr;
  if (FAILED(webview_->get_Source(&source)) || source == nullptr) {
    return;
  }
  std::wstring source_uri(source);
  CoTaskMemFree(source);

  checking_cookies_ = true;
  cookie_manager->GetCookies(
      source_uri.c_str(),
      Callback<ICoreWebView2GetCookiesCompletedHandler>(
          [this](HRESULT result, ICoreWebView2CookieList* cookies) -> HRESULT {
            checking_cookies_ = false;
            if (completed_ || FAILED(result) || cookies == nullptr) {
              return S_OK;
            }
            UINT count = 0;
            cookies->get_Count(&count);
            std::string header;
            for (UINT i = 0; i < count; ++i) {
              ComPtr<ICoreWebView2Cookie> cookie;
              if (FAILED(cookies->GetValueAtIndex(i, &cookie)) || !cookie) {
                continue;
              }
              LPWSTR name = nullptr;
              LPWSTR value = nullptr;
              cookie->get_Name(&name);
              cookie->get_Value(&value);
              const std::string name_utf8 = WideToUtf8(name);
              const std::string value_utf8 = WideToUtf8(value);
              if (name != nullptr) {
                CoTaskMemFree(name);
              }
              if (value != nullptr) {
                CoTaskMemFree(value);
              }
              if (name_utf8.empty() || value_utf8.empty()) {
                continue;
              }
              if (!header.empty()) {
                header += "; ";
              }
              header += name_utf8;
              header += "=";
              header += value_utf8;
            }
            if (HasSessionCookie(header)) {
              FinishSuccess(header);
            }
            return S_OK;
          })
          .Get());
}

void WinMiAccountTwoFactorSession::InspectBody() {
  if (completed_ || !webview_) {
    return;
  }
  webview_->ExecuteScript(
      L"(document.body && document.body.innerText || '').trim()",
      Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
          [this](HRESULT result, LPCWSTR body_json) -> HRESULT {
            if (completed_ || FAILED(result) || body_json == nullptr) {
              return S_OK;
            }
            const std::string text = DecodeJsonString(body_json);
            if (text == "ok" ||
                (text.size() > 3 && text.rfind("\nok") == text.size() - 3)) {
              CompleteIfReady();
            }
            return S_OK;
          })
          .Get());
}

void WinMiAccountTwoFactorSession::FinishSuccess(
    const std::string& cookie_header) {
  if (completed_) {
    return;
  }
  completed_ = true;
  if (window_ != nullptr) {
    KillTimer(window_, kPollTimerId);
  }
  auto result = std::move(result_);
  if (window_ != nullptr) {
    DestroyWindow(window_);
    window_ = nullptr;
  }
  if (result) {
    result->Success(EncodableValue(cookie_header));
  }
  g_session.reset();
}

void WinMiAccountTwoFactorSession::Fail(const std::string& code,
                                        const std::string& message) {
  if (completed_) {
    return;
  }
  completed_ = true;
  if (window_ != nullptr) {
    KillTimer(window_, kPollTimerId);
  }
  auto result = std::move(result_);
  if (window_ != nullptr) {
    DestroyWindow(window_);
    window_ = nullptr;
  }
  if (result) {
    result->Error(code, message);
  }
  g_session.reset();
}

#endif  // defined(ZEROBOX_HAVE_WEBVIEW2)

void HandleResolve(HWND parent_window,
                   const EncodableValue* arguments,
                   std::unique_ptr<MethodResult<EncodableValue>> result) {
  if (arguments == nullptr || !std::holds_alternative<EncodableMap>(*arguments)) {
    result->Error("INVALID_ARGUMENT", "url is required");
    return;
  }
  const auto& args = std::get<EncodableMap>(*arguments);
  auto it = args.find(EncodableValue("url"));
  if (it == args.end() || !std::holds_alternative<std::string>(it->second)) {
    result->Error("INVALID_ARGUMENT", "url is required");
    return;
  }

#if defined(ZEROBOX_HAVE_WEBVIEW2)
  if (g_session) {
    result->Error("BUSY", "Xiaomi 2FA WebView is already open");
    return;
  }
  g_session = std::make_unique<WinMiAccountTwoFactorSession>(
      parent_window, std::move(result));
  g_session->Start(std::get<std::string>(it->second));
#else
  (void)parent_window;
  result->Error(
      "UNAVAILABLE",
      "Windows Xiaomi 2FA requires the Microsoft Edge WebView2 SDK at build time");
#endif
}

}  // namespace

void RegisterMiAccountTwoFactorChannel(flutter::BinaryMessenger* messenger,
                                        HWND parent_window) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kChannelName,
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [parent_window](
          const flutter::MethodCall<EncodableValue>& call,
          std::unique_ptr<MethodResult<EncodableValue>> result) {
        if (call.method_name() == "resolve") {
          HandleResolve(parent_window, call.arguments(), std::move(result));
          return;
        }
        result->NotImplemented();
      });

  channel.release();
}
