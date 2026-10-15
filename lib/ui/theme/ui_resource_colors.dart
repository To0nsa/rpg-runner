import 'package:flutter/painting.dart';

import 'ui_world_palette.dart';

/// Shared resource identity for vitals and the muted action-control palette.
abstract final class UiResourceColors {
  // A restrained mist lift keeps narrow tracks legible over dark backing.
  static final health = Color.lerp(
    UiWorldPalette.rust500,
    UiWorldPalette.mist200,
    .2,
  )!;
  // Preserve familiar blue/green resource cues even in the muted world palette.
  static const mana = Color(0xFF527FAB);
  static const stamina = Color(0xFF6C9364);
}
