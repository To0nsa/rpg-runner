import 'dart:math' as math;

import 'package:rpg_runner/playtest.dart';

/// Nominal active rectangle, not the chassis or rounded-corner visible area.
/// The logical aspect is preserved; manufacturer's diagonal rounds its size.
class PlaytestDeviceScreen {
  const PlaytestDeviceScreen(this.diagonalMm, this.precisionMm, this.source);
  final double diagonalMm;
  final double precisionMm;
  final String source;
  double widthMm(RunnerPlaytestDisplay display) =>
      diagonalMm *
      display.width /
      math.sqrt(
        display.width * display.width + display.height * display.height,
      );

  static const presets = <String, PlaytestDeviceScreen>{
    'iPhone SE': PlaytestDeviceScreen(
      119.23801954359348, // 1334x750 physical pixels / 326 ppi.
      0.19, // Half a ppi of quoted density precision.
      'https://support.apple.com/en-us/111882',
    ),
    'iPhone 12 Pro': PlaytestDeviceScreen(
      6.06 * 25.4,
      0.005 * 25.4,
      'https://support.apple.com/en-us/111875',
    ),
    'iPhone 14 Pro Max': PlaytestDeviceScreen(
      6.69 * 25.4,
      0.005 * 25.4,
      'https://support.apple.com/en-us/111846',
    ),
    'Pixel 7': PlaytestDeviceScreen(
      160.5,
      0.05,
      'https://support.google.com/pixelphone/answer/7158570',
    ),
    'Samsung Galaxy S20 Ultra': PlaytestDeviceScreen(
      6.9 * 25.4,
      0.05 * 25.4,
      'https://image-us.samsung.com/SamsungUS/samsungbusiness/pdfs/datasheet/HHP-SPR-S20SERIESDSHT-MAR20T-Final-3-6-20.pdf',
    ),
    'Samsung Galaxy A55': PlaytestDeviceScreen(
      168.3,
      0.05,
      'https://www.samsung.com/uk/smartphones/galaxy-a/galaxy-a55-5g-awesome-iceblue-128gb-sm-a556blbaeub/',
    ),
    'iPad Mini': PlaytestDeviceScreen(
      7.9 * 25.4,
      0.05 * 25.4,
      'https://support.apple.com/en-us/111904',
    ),
  };
}

/// Accepted launch choices. Monitor calibration has a separate machine lifetime.
class EditorPlaytestSettings {
  const EditorPlaytestSettings({
    required this.presentation,
    required this.screen,
  });
  static const initial = EditorPlaytestSettings(
    presentation: RunnerPlaytestPresentation(
      showMobileHud: true,
      viewportMode: ViewportScaleMode.pixelPerfectCover,
      display: RunnerPlaytestDevicePresets.defaultPhone,
    ),
    screen: PlaytestDeviceScreen(
      6.06 * 25.4,
      0.005 * 25.4,
      'https://support.apple.com/en-us/111875',
    ),
  );
  final RunnerPlaytestPresentation presentation;
  final PlaytestDeviceScreen screen;

  // The calibrated outer frame owns MediaQuery/physical scaling. Its inner host
  // retains gameplay policy but must not add another device frame.
  RunnerPlaytestPresentation get innerPresentation =>
      RunnerPlaytestPresentation(
        showMobileHud: presentation.showMobileHud,
        movementControlMode: presentation.movementControlMode,
        viewportMode: presentation.viewportMode,
      );
}
