import '../l10n/app_localization.dart';

import 'package:runner_core/levels/level_id.dart';

import 'generated_level_ui_metadata.dart';

/// UI-layer extensions for [LevelId].
extension LevelIdUi on LevelId {
  /// Human-readable display name for the level.
  String localizedName(AppLocalizations l10n) => switch (this) {
    LevelId.forest => l10n.levelForestName,
    LevelId.field => l10n.levelFieldName,
    LevelId.new_level => l10n.levelDeprecatedName,
  };

  /// Whether this level should appear in normal selection UI.
  bool get isSelectableInStandardUi =>
      generatedLevelUiMetadataFor(this).isSelectableInStandardUi;

  /// Theme identifier used for asset lookup.
  ///
  /// Metadata remains readable even when this identity is excluded from Build.
  String get visualThemeId => generatedLevelUiMetadataFor(this).visualThemeId;
}

List<LevelId> selectableLevelIdsForUi() => generatedSelectableLevelIds;
