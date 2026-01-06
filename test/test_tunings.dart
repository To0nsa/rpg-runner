import 'package:walkscape_runner/core/tuning/camera_tuning.dart';

/// Test-only tuning that disables the autoscroll camera so unit tests can focus
/// on specific mechanics without the run ending due to view bounds.
const CameraTuning noAutoscrollCameraTuning = CameraTuning(
  speedLagMulX: 0.0, // => targetSpeedX is 0, disabling autoscroll.
);
