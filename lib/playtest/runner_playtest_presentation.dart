import '../ui/controls/movement_control_mode.dart';
import '../ui/viewport/viewport_metrics.dart';
import 'runner_playtest_display.dart';
import 'runner_playtest_device_presets.dart';

/// Tooling-only choices captured before Play and retained by runtime Restart.
/// They never enter authored content, gameplay input or saved game preferences.
class RunnerPlaytestPresentation {
  const RunnerPlaytestPresentation({
    this.showMobileHud = false,
    this.movementControlMode = MovementControlMode.arrows,
    this.viewportMode = ViewportScaleMode.pixelPerfectContain,
    this.display,
  });

  static const mobile = RunnerPlaytestPresentation(
    showMobileHud: true,
    viewportMode: ViewportScaleMode.pixelPerfectCover,
    display: RunnerPlaytestDevicePresets.defaultPhone,
  );

  final bool showMobileHud;
  final MovementControlMode movementControlMode;
  final ViewportScaleMode viewportMode;

  /// Null uses the available editor area; Editor launch settings default to a phone preview.
  final RunnerPlaytestDisplay? display;
}
