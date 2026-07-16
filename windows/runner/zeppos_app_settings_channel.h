#ifndef RUNNER_ZEPPOS_APP_SETTINGS_CHANNEL_H_
#define RUNNER_ZEPPOS_APP_SETTINGS_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

void RegisterZeppOsAppSettingsChannel(flutter::BinaryMessenger* messenger,
                                      HWND parent_window);
void CloseZeppOsAppSettings();

#endif
