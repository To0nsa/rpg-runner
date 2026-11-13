#include "display_environment.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <string>

namespace {
using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

std::string Utf8(const wchar_t* text) {
  const int count = WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (count <= 1) return {};
  std::string value(count, '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, -1, value.data(), count, nullptr, nullptr);
  value.resize(count - 1);
  return value;
}

BOOL CALLBACK ReadMonitor(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  MONITORINFOEXW info{};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfoW(monitor, reinterpret_cast<MONITORINFO*>(&info))) return TRUE;
  DISPLAY_DEVICEW device{};
  device.cb = sizeof(device);
  const bool identified = EnumDisplayDevicesW(info.szDevice, 0, &device,
      EDD_GET_DEVICE_INTERFACE_NAME) && device.DeviceID[0] != L'\0';
  DEVMODEW mode{};
  mode.dmSize = sizeof(mode);
  if (!EnumDisplaySettingsExW(info.szDevice, ENUM_CURRENT_SETTINGS, &mode, 0)) return TRUE;
  auto& list = *reinterpret_cast<EncodableList*>(data);
  list.emplace_back(EncodableMap{
    {EncodableValue("id"), EncodableValue(Utf8(identified ? device.DeviceID : info.szDevice))},
    {EncodableValue("name"), EncodableValue(Utf8(info.szDevice))},
    {EncodableValue("identified"), EncodableValue(identified)},
    {EncodableValue("left"), EncodableValue(static_cast<int>(info.rcMonitor.left))},
    {EncodableValue("top"), EncodableValue(static_cast<int>(info.rcMonitor.top))},
    {EncodableValue("width"), EncodableValue(static_cast<int>(info.rcMonitor.right - info.rcMonitor.left))},
    {EncodableValue("height"), EncodableValue(static_cast<int>(info.rcMonitor.bottom - info.rcMonitor.top))},
    {EncodableValue("orientation"), EncodableValue(static_cast<int>(mode.dmDisplayOrientation))},
  });
  return TRUE;
}
}  // namespace

void RegisterDisplayEnvironment(flutter::BinaryMessenger* messenger, HWND view) {
  flutter::MethodChannel<> channel(messenger, "lothringen.editor/display",
      &flutter::StandardMethodCodec::GetInstance());
  channel.SetMethodCallHandler([view](const flutter::MethodCall<>& call,
      std::unique_ptr<flutter::MethodResult<>> result) {
    if (call.method_name() != "read") { result->NotImplemented(); return; }
    POINT origin{};
    EncodableList monitors;
    if (!ClientToScreen(view, &origin) ||
        !EnumDisplayMonitors(nullptr, nullptr, ReadMonitor, reinterpret_cast<LPARAM>(&monitors))) {
      result->Error("display_unavailable", "Could not resolve the editor display.");
      return;
    }
    result->Success(EncodableMap{
      {EncodableValue("originX"), EncodableValue(static_cast<int>(origin.x))},
      {EncodableValue("originY"), EncodableValue(static_cast<int>(origin.y))},
      {EncodableValue("remote"), EncodableValue(GetSystemMetrics(SM_REMOTESESSION) != 0)},
      {EncodableValue("monitors"), EncodableValue(monitors)},
    });
  });
}
