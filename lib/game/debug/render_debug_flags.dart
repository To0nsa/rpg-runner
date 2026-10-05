/// Render-layer debug flags.
///
/// Kept in `lib/game/**` so Core remains pure/deterministic and unaware of
/// any debug drawing concerns.
library;

import 'package:flutter/foundation.dart';

abstract class RenderDebugFlags {
  /// Draws vulnerable bodies, attack/projectile capsules, and trap hitboxes.
  ///
  /// Enabled for local debug/profile inspection; toggle locally when needed.
  static bool drawActorHitboxes = true;

  /// Convenience for enabling all render debug overlays in debug/profile
  /// builds while keeping release builds clean.
  static bool get canUseRenderDebug => !kReleaseMode;
}
