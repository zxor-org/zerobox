#include "log_window_channel.h"

#include <dwmapi.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <memory>
#include <string>
#include <variant>
#include <vector>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr char kChannelName[] = "zerobox/log_window";
constexpr wchar_t kWindowClassName[] = L"ZeroBoxLogWindow";
constexpr int kClearButtonId = 1001;

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

std::wstring Utf8ToWide(const std::string& text) {
  if (text.empty()) return L"";
  const int size = MultiByteToWideChar(CP_UTF8, 0, text.data(),
                                       static_cast<int>(text.size()), nullptr, 0);
  if (size <= 0) return L"";
  std::wstring result(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      result.data(), size);
  return result;
}

const EncodableValue* Find(const EncodableMap& map, const char* key) {
  const auto iterator = map.find(EncodableValue(key));
  return iterator == map.end() ? nullptr : &iterator->second;
}

uint32_t IntegerValue(const EncodableValue* value, uint32_t fallback) {
  if (value == nullptr) return fallback;
  if (const auto* number = std::get_if<int32_t>(value)) {
    return static_cast<uint32_t>(*number);
  }
  if (const auto* number = std::get_if<int64_t>(value)) {
    return static_cast<uint32_t>(*number);
  }
  return fallback;
}

COLORREF ColorFromArgb(uint32_t argb) {
  return RGB((argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff);
}

class LogWindowChannel {
 public:
  explicit LogWindowChannel(flutter::BinaryMessenger* messenger)
      : channel_(messenger, kChannelName,
                 &flutter::StandardMethodCodec::GetInstance()) {
    channel_.SetMethodCallHandler(
        [this](const auto& call, auto result) {
          if (call.method_name() == "open") {
            const auto* args = std::get_if<EncodableMap>(call.arguments());
            Open(args == nullptr ? EncodableMap{} : *args);
            result->Success();
          } else if (call.method_name() == "close") {
            Close(false);
            result->Success();
          } else if (call.method_name() == "append") {
            const auto* args = std::get_if<EncodableMap>(call.arguments());
            const auto* value = args == nullptr ? nullptr : Find(*args, "line");
            const auto* line = value == nullptr
                                   ? nullptr
                                   : std::get_if<std::string>(value);
            if (line == nullptr) {
              result->Error("INVALID_ARGUMENT", "line is required");
            } else {
              Append(Utf8ToWide(*line));
              result->Success();
            }
          } else if (call.method_name() == "appendMany") {
            const auto* args = std::get_if<EncodableMap>(call.arguments());
            const auto* value = args == nullptr ? nullptr : Find(*args, "lines");
            const auto* lines = value == nullptr
                                    ? nullptr
                                    : std::get_if<EncodableList>(value);
            if (lines == nullptr) {
              result->Error("INVALID_ARGUMENT", "lines are required");
            } else {
              std::wstring joined;
              for (const auto& item : *lines) {
                const auto* line = std::get_if<std::string>(&item);
                if (line == nullptr) continue;
                if (!joined.empty()) joined.append(L"\r\n");
                joined.append(Utf8ToWide(*line));
              }
              Append(joined);
              result->Success();
            }
          } else {
            result->NotImplemented();
          }
        });
  }

  ~LogWindowChannel() {
    Close(false);
    if (surface_brush_) DeleteObject(surface_brush_);
    if (container_brush_) DeleteObject(container_brush_);
    if (log_brush_) DeleteObject(log_brush_);
  }

 private:
  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) {
    auto* self = reinterpret_cast<LogWindowChannel*>(
        GetWindowLongPtr(window, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
      const auto* create = reinterpret_cast<CREATESTRUCT*>(lparam);
      self = static_cast<LogWindowChannel*>(create->lpCreateParams);
      SetWindowLongPtr(window, GWLP_USERDATA,
                       reinterpret_cast<LONG_PTR>(self));
    }
    return self == nullptr
               ? DefWindowProc(window, message, wparam, lparam)
               : self->HandleMessage(window, message, wparam, lparam);
  }

  static void EnsureWindowClass() {
    static bool registered = false;
    if (registered) return;
    WNDCLASSW window_class = {};
    window_class.lpfnWndProc = WindowProc;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.lpszClassName = kWindowClassName;
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    RegisterClassW(&window_class);
    registered = true;
  }

  void Open(const EncodableMap& theme) {
    if (window_ != nullptr) {
      ShowWindow(window_, SW_RESTORE);
      SetForegroundWindow(window_);
      return;
    }
    dark_ = Find(theme, "dark") != nullptr &&
            std::get_if<bool>(Find(theme, "dark")) != nullptr &&
            *std::get_if<bool>(Find(theme, "dark"));
    surface_ = ColorFromArgb(IntegerValue(Find(theme, "surface"), 0xff121017));
    container_ = ColorFromArgb(
        IntegerValue(Find(theme, "surfaceContainer"), 0xff1e1b23));
    log_background_ = ColorFromArgb(
        IntegerValue(Find(theme, "surfaceContainerLowest"), 0xff0e0c11));
    text_color_ =
        ColorFromArgb(IntegerValue(Find(theme, "onSurface"), 0xffe9e1eb));
    secondary_text_color_ = ColorFromArgb(
        IntegerValue(Find(theme, "onSurfaceVariant"), 0xffcbc2cc));
    primary_ = ColorFromArgb(IntegerValue(Find(theme, "primary"), 0xffd0bcff));
    ResetBrushes();

    EnsureWindowClass();
    window_ = CreateWindowExW(
        0, kWindowClassName, L"ZeroBox · 运行日志", WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 980, 640, nullptr, nullptr,
        GetModuleHandle(nullptr), this);
    if (window_ == nullptr) return;

    BOOL dark = dark_ ? TRUE : FALSE;
    DwmSetWindowAttribute(window_, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                          sizeof(dark));
    ShowWindow(window_, SW_SHOW);
    UpdateWindow(window_);
  }

  bool CreateControls(HWND window) {
    title_ = CreateWindowW(L"STATIC", L"运行日志", WS_CHILD | WS_VISIBLE,
                           18, 17, 160, 28, window, nullptr,
                           GetModuleHandle(nullptr), nullptr);
    count_ = CreateWindowW(L"STATIC", L"0 行",
                           WS_CHILD | WS_VISIBLE | SS_RIGHT, 720, 19, 100, 24,
                           window, nullptr, GetModuleHandle(nullptr), nullptr);
    clear_ = CreateWindowW(L"BUTTON", L"清空",
                           WS_CHILD | WS_VISIBLE | BS_FLAT, 838, 12, 104, 34,
                           window, reinterpret_cast<HMENU>(kClearButtonId),
                           GetModuleHandle(nullptr), nullptr);
    edit_ = CreateWindowExW(
        WS_EX_CLIENTEDGE, L"EDIT", L"",
        WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL | ES_LEFT |
            ES_MULTILINE | ES_AUTOVSCROLL | ES_AUTOHSCROLL | ES_READONLY |
            ES_NOHIDESEL,
        0, 58, 960, 540, window, nullptr, GetModuleHandle(nullptr), nullptr);
    if (!title_ || !count_ || !clear_ || !edit_) return false;

    title_font_ = CreateFontW(-18, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                              DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                              CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                              DEFAULT_PITCH, L"Segoe UI");
    log_font_ = CreateFontW(-14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                            DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                            CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                            FIXED_PITCH, L"Cascadia Mono");
    SendMessage(title_, WM_SETFONT, reinterpret_cast<WPARAM>(title_font_), TRUE);
    SendMessage(count_, WM_SETFONT, reinterpret_cast<WPARAM>(log_font_), TRUE);
    SendMessage(clear_, WM_SETFONT, reinterpret_cast<WPARAM>(log_font_), TRUE);
    SendMessage(edit_, WM_SETFONT, reinterpret_cast<WPARAM>(log_font_), TRUE);
    SendMessage(edit_, EM_SETLIMITTEXT, 0x7ffffffe, 0);
    return true;
  }

  void Append(const std::wstring& value) {
    if (edit_ == nullptr || value.empty()) return;
    const int existing_length = GetWindowTextLengthW(edit_);
    SendMessage(edit_, EM_SETSEL, existing_length, existing_length);
    if (existing_length > 0) {
      SendMessage(edit_, EM_REPLACESEL, FALSE,
                  reinterpret_cast<LPARAM>(L"\r\n"));
    }
    SendMessage(edit_, EM_REPLACESEL, FALSE,
                reinterpret_cast<LPARAM>(value.c_str()));
    line_count_ += 1 + static_cast<int>(
                           std::count(value.begin(), value.end(), L'\n'));
    const std::wstring label = std::to_wstring(line_count_) + L" 行";
    SetWindowTextW(count_, label.c_str());
    SendMessage(edit_, WM_VSCROLL, SB_BOTTOM, 0);
  }

  void Clear() {
    if (edit_ != nullptr) SetWindowTextW(edit_, L"");
    line_count_ = 0;
    if (count_ != nullptr) SetWindowTextW(count_, L"0 行");
  }

  void Close(bool notify) {
    if (window_ == nullptr) return;
    HWND window = window_;
    window_ = nullptr;
    SetWindowLongPtr(window, GWLP_USERDATA, 0);
    DestroyWindow(window);
    DestroyControls();
    if (notify) channel_.InvokeMethod("closed", nullptr);
  }

  void DestroyControls() {
    title_ = count_ = clear_ = edit_ = nullptr;
    if (title_font_) DeleteObject(title_font_);
    if (log_font_) DeleteObject(log_font_);
    title_font_ = log_font_ = nullptr;
    line_count_ = 0;
  }

  void ResetBrushes() {
    if (surface_brush_) DeleteObject(surface_brush_);
    if (container_brush_) DeleteObject(container_brush_);
    if (log_brush_) DeleteObject(log_brush_);
    surface_brush_ = CreateSolidBrush(surface_);
    container_brush_ = CreateSolidBrush(container_);
    log_brush_ = CreateSolidBrush(log_background_);
  }

  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam) {
    switch (message) {
      case WM_CREATE:
        return CreateControls(window) ? 0 : -1;
      case WM_SIZE: {
        const int width = LOWORD(lparam);
        const int height = HIWORD(lparam);
        MoveWindow(title_, 18, 17, 180, 28, TRUE);
        MoveWindow(clear_, std::max(18, width - 122), 12, 104, 34, TRUE);
        MoveWindow(count_, std::max(18, width - 240), 19, 100, 24, TRUE);
        MoveWindow(edit_, 0, 58, width, std::max(0, height - 58), TRUE);
        return 0;
      }
      case WM_COMMAND:
        if (LOWORD(wparam) == kClearButtonId) {
          Clear();
          return 0;
        }
        break;
      case WM_CTLCOLOREDIT: {
        HDC dc = reinterpret_cast<HDC>(wparam);
        SetTextColor(dc, text_color_);
        SetBkColor(dc, log_background_);
        return reinterpret_cast<LRESULT>(log_brush_);
      }
      case WM_CTLCOLORSTATIC: {
        HDC dc = reinterpret_cast<HDC>(wparam);
        if (reinterpret_cast<HWND>(lparam) == edit_) {
          SetTextColor(dc, text_color_);
          SetBkColor(dc, log_background_);
          return reinterpret_cast<LRESULT>(log_brush_);
        }
        SetBkMode(dc, TRANSPARENT);
        SetTextColor(dc, reinterpret_cast<HWND>(lparam) == count_
                             ? secondary_text_color_
                             : text_color_);
        return reinterpret_cast<LRESULT>(container_brush_);
      }
      case WM_CTLCOLORBTN: {
        HDC dc = reinterpret_cast<HDC>(wparam);
        SetTextColor(dc, primary_);
        SetBkColor(dc, container_);
        return reinterpret_cast<LRESULT>(container_brush_);
      }
      case WM_ERASEBKGND: {
        RECT rect{};
        GetClientRect(window, &rect);
        FillRect(reinterpret_cast<HDC>(wparam), &rect, surface_brush_);
        RECT header = rect;
        header.bottom = 58;
        FillRect(reinterpret_cast<HDC>(wparam), &header, container_brush_);
        return 1;
      }
      case WM_CLOSE:
        Close(true);
        return 0;
      case WM_DESTROY:
        if (window_ == window) window_ = nullptr;
        DestroyControls();
        return 0;
    }
    return DefWindowProc(window, message, wparam, lparam);
  }

  flutter::MethodChannel<EncodableValue> channel_;
  HWND window_ = nullptr;
  HWND title_ = nullptr;
  HWND count_ = nullptr;
  HWND clear_ = nullptr;
  HWND edit_ = nullptr;
  HFONT title_font_ = nullptr;
  HFONT log_font_ = nullptr;
  HBRUSH surface_brush_ = nullptr;
  HBRUSH container_brush_ = nullptr;
  HBRUSH log_brush_ = nullptr;
  COLORREF surface_ = RGB(18, 16, 23);
  COLORREF container_ = RGB(30, 27, 35);
  COLORREF log_background_ = RGB(14, 12, 17);
  COLORREF text_color_ = RGB(233, 225, 235);
  COLORREF secondary_text_color_ = RGB(203, 194, 204);
  COLORREF primary_ = RGB(208, 188, 255);
  bool dark_ = true;
  int line_count_ = 0;
};

std::unique_ptr<LogWindowChannel> g_log_window_channel;

}  // namespace

void RegisterLogWindowChannel(flutter::BinaryMessenger* messenger) {
  g_log_window_channel = std::make_unique<LogWindowChannel>(messenger);
}
