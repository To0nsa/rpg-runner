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
  static final mana = Color.lerp(
    UiWorldPalette.slate500,
    UiWorldPalette.fog300,
    .35,
  )!;
  static const stamina = UiWorldPalette.fog300;
}
