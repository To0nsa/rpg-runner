import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';

import 'generated_level_ui_metadata.dart';

/// UI-layer extensions for [LevelId].
extension LevelIdUi on LevelId {
  /// Human-readable display name for the level.
  String get displayName => generatedLevelUiMetadataFor(this).displayName;

  /// Whether this level should appear in normal selection UI.
  bool get isSelectableInStandardUi =>
      generatedLevelUiMetadataFor(this).isSelectableInStandardUi;

  /// Theme identifier used for asset lookup.
  ///
  /// Resolves through [LevelRegistry] to get the authoritative themeId.
  /// Returns 'field' as fallback if the level has no theme set.
  String get themeId => LevelRegistry.byId(this).themeId ?? 'field';
}

List<LevelId> selectableLevelIdsForUi() {
  if (generatedSelectableLevelIds.isNotEmpty) {
    return generatedSelectableLevelIds;
  }
  return LevelId.values;
}
