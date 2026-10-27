import 'package:flutter/foundation.dart';

/// Selects one input surface per run; this never changes replay/gameplay rules.
enum RunnerControlScheme {
  /// Keyboard/mouse on Windows, Linux and macOS (including their browsers),
  /// touch on Android, iOS and Fuchsia. Hosts can override for hybrid devices.
  automatic,
  touch,
  desktop;

  RunnerControlScheme resolve(TargetPlatform platform) => switch (this) {
    automatic => switch (platform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => desktop,
      _ => touch,
    },
    _ => this,
  };
}
