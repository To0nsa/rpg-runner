#ifndef RUNNER_DISPLAY_ENVIRONMENT_H_
#define RUNNER_DISPLAY_ENVIRONMENT_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// Read-only monitor identity, mode and Flutter client origin for calibrated Play.
void RegisterDisplayEnvironment(flutter::BinaryMessenger* messenger, HWND view);

#endif
