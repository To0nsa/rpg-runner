import 'package:runner_core/levels/level_id.dart';

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
  /// Metadata remains readable even when this identity is excluded from Build.
  String get visualThemeId => generatedLevelUiMetadataFor(this).visualThemeId;
}

List<LevelId> selectableLevelIdsForUi() => generatedSelectableLevelIds;
