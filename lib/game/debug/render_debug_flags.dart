/// Render-layer debug flags.
///
/// Kept in `lib/game/**` so Core remains pure/deterministic and unaware of
/// any debug drawing concerns.
library;

import 'package:flutter/foundation.dart';

abstract class RenderDebugFlags {
  /// Draws vulnerable bodies, attack/projectile capsules, and trap hitboxes.
  ///
  /// Disabled by default; enable locally for debug/profile inspection.
  static bool drawActorHitboxes = false;

  /// Convenience for enabling all render debug overlays in debug/profile
  /// builds while keeping release builds clean.
  static bool get canUseRenderDebug => !kReleaseMode;
}
