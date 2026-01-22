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
  ///
  /// Resolves through [LevelRegistry] to get the authoritative themeId.
  /// Returns 'field' as fallback if the level has no theme set.
  String get themeId => LevelRegistry.byId(this).themeId ?? 'field';
}
