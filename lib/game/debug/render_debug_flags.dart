/// Render-layer debug flags.
///
/// Kept in `lib/game/**` so Core remains pure/deterministic and unaware of
/// any debug drawing concerns.
library;

import 'package:flutter/foundation.dart';

abstract class RenderDebugFlags {
  /// Draws collision AABB overlays for "actor" entities (player + enemies).
  ///
  /// Default is `false` even in debug builds; toggle locally when needed.
  static bool drawActorHitboxes = true;

  /// Convenience for enabling all render debug overlays in debug/profile
  /// builds while keeping release builds clean.
  static bool get canUseRenderDebug => !kReleaseMode;
}

