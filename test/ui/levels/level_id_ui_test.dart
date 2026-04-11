import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:rpg_runner/ui/levels/generated_level_ui_metadata.dart';
import 'package:rpg_runner/ui/levels/level_id_ui.dart';

void main() {
  test(
    'LevelIdUi display metadata resolves through generated level metadata',
    () {
      for (final levelId in LevelId.values) {
        final metadata = generatedLevelUiMetadataFor(levelId);
        expect(levelId.displayName, metadata.displayName);
        expect(
          levelId.isSelectableInStandardUi,
          metadata.isSelectableInStandardUi,
        );
      }
    },
  );

  test(
    'selectableLevelIdsForUi matches generated selectable metadata order',
    () {
      expect(selectableLevelIdsForUi(), generatedSelectableLevelIds);
      for (final levelId in selectableLevelIdsForUi()) {
        expect(levelId.isSelectableInStandardUi, isTrue);
      }
    },
  );

  test(
    'LevelIdUi themeId stays aligned with runtime registry theme lookup',
    () {
      for (final levelId in LevelId.values) {
        expect(levelId.themeId, LevelRegistry.byId(levelId).themeId ?? 'field');
      }
    },
  );
}
