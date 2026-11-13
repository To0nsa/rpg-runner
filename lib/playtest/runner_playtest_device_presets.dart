import 'runner_playtest_display.dart';

/// A curated subset of Chrome DevTools landscape sizes and pixel densities.
/// Source checked 2026-11-12:
/// https://github.com/ChromeDevTools/devtools-frontend/blob/main/front_end/models/emulation/EmulatedDevices.ts
/// These describe an immersive layout, without browser chrome or cutout emulation.
abstract final class RunnerPlaytestDevicePresets {
  static const defaultPhone = RunnerPlaytestDisplay(
    width: 844,
    height: 390,
    devicePixelRatio: 3,
  );

  static const devices = <String, RunnerPlaytestDisplay>{
    'iPhone SE': RunnerPlaytestDisplay(
      width: 667,
      height: 375,
      devicePixelRatio: 2,
    ),
    'iPhone 12 Pro': defaultPhone,
    'iPhone 14 Pro Max': RunnerPlaytestDisplay(
      width: 932,
      height: 430,
      devicePixelRatio: 3,
    ),
    'Pixel 7': RunnerPlaytestDisplay(
      width: 915,
      height: 412,
      devicePixelRatio: 2.625,
    ),
    'Samsung Galaxy S20 Ultra': RunnerPlaytestDisplay(
      width: 915,
      height: 412,
      devicePixelRatio: 3.5,
    ),
    'Samsung Galaxy A55': RunnerPlaytestDisplay(
      width: 800,
      height: 360,
      devicePixelRatio: 2.25,
    ),
    'iPad Mini': RunnerPlaytestDisplay(
      width: 1024,
      height: 768,
      devicePixelRatio: 2,
    ),
  };
}
