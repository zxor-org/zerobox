#pragma once

#include <flutter/binary_messenger.h>
#include <windows.h>

void RegisterMiAccountTwoFactorChannel(flutter::BinaryMessenger* messenger,
                                        HWND parent_window);
