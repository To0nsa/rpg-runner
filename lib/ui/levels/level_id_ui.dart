import '../../core/levels/level_id.dart';
import '../../core/levels/level_registry.dart';

/// UI-layer extensions for [LevelId].
extension LevelIdUi on LevelId {
  /// Human-readable display name for the level.
  String get displayName {
    switch (this) {
      case LevelId.defaultLevel:
        return 'Default';
      case LevelId.forest:
        return 'Forest';
      case LevelId.field:
        return 'Field';
    }
  }

  /// Theme identifier used for asset lookup.
  String get themeId => LevelRegistry.byId(this).themeId ?? 'field';

  /// Asset path for the preview image (middle parallax layer).
  ///
  /// Uses a middle layer from the parallax set for visual depth.
  String get previewAssetPath {
    switch (themeId) {
      case 'forest':
        return 'assets/images/parallax/forest/Forest Layer 03.png';
      case 'field':
        return 'assets/images/parallax/field/Field Layer 05.png';
      default:
        return 'assets/images/parallax/field/Field Layer 05.png';
    }
  }
}
