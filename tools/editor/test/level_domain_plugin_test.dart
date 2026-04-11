import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/levels/level_validation.dart';

void main() {
  test(
    'create duplicate update and status edits keep revisions deterministic',
    () {
      final plugin = LevelDomainPlugin();
      const document = LevelDefsDocument(
        workspaceRootPath: '.',
        levels: <LevelDef>[
          LevelDef(
            levelId: 'field',
            revision: 1,
            displayName: 'Field',
            themeId: 'field',
            cameraCenterY: 135,
            groundTopY: 224,
            earlyPatternChunks: 3,
            easyPatternChunks: 0,
            normalPatternChunks: 0,
            noEnemyChunks: 3,
            enumOrdinal: 20,
            status: levelStatusActive,
          ),
        ],
        baseline: null,
        baselineLevels: <LevelDef>[
          LevelDef(
            levelId: 'field',
            revision: 1,
            displayName: 'Field',
            themeId: 'field',
            cameraCenterY: 135,
            groundTopY: 224,
            earlyPatternChunks: 3,
            easyPatternChunks: 0,
            normalPatternChunks: 0,
            noEnemyChunks: 3,
            enumOrdinal: 20,
            status: levelStatusActive,
          ),
        ],
        activeLevelId: 'field',
        availableParallaxThemeIds: <String>['field', 'forest'],
        parallaxThemeSourceAvailable: true,
        authoredChunkCountsByLevelId: <String, int>{'field': 1},
        chunkCountSourceAvailable: true,
      );

      final created =
          plugin.applyEdit(
                document,
                AuthoringCommand(
                  kind: 'create_level',
                  payload: const <String, Object?>{'levelId': 'cave'},
                ),
              )
              as LevelDefsDocument;
      final createdLevel = created.levels.firstWhere(
        (level) => level.levelId == 'cave',
      );
      expect(created.activeLevelId, 'cave');
      expect(createdLevel.revision, 1);
      expect(createdLevel.enumOrdinal, 30);
      expect(createdLevel.displayName, 'Cave');

      final duplicated =
          plugin.applyEdit(
                created,
                AuthoringCommand(
                  kind: 'duplicate_level',
                  payload: const <String, Object?>{'levelId': 'field'},
                ),
              )
              as LevelDefsDocument;
      final duplicate = duplicated.levels.firstWhere(
        (level) => level.levelId != 'field' && level.levelId != 'cave',
      );
      expect(duplicate.revision, 1);
      expect(duplicate.levelId, 'field_copy');
      expect(duplicate.enumOrdinal, 40);

      final updated =
          plugin.applyEdit(
                duplicated,
                AuthoringCommand(
                  kind: 'update_level',
                  payload: const <String, Object?>{
                    'levelId': 'field',
                    'displayName': 'Field Updated',
                    'themeId': 'forest',
                    'cameraCenterY': '140',
                    'enumOrdinal': 50,
                  },
                ),
              )
              as LevelDefsDocument;
      final updatedField = updated.levels.firstWhere(
        (level) => level.levelId == 'field',
      );
      expect(updatedField.revision, 2);
      expect(updatedField.displayName, 'Field Updated');
      expect(updatedField.themeId, 'forest');
      expect(updatedField.cameraCenterY, 140);
      expect(updatedField.enumOrdinal, 50);

      final deprecated =
          plugin.applyEdit(
                updated,
                AuthoringCommand(
                  kind: 'deprecate_level',
                  payload: const <String, Object?>{'levelId': 'field'},
                ),
              )
              as LevelDefsDocument;
      expect(
        deprecated.levels
            .firstWhere((level) => level.levelId == 'field')
            .status,
        levelStatusDeprecated,
      );
      expect(
        deprecated.levels
            .firstWhere((level) => level.levelId == 'field')
            .revision,
        3,
      );

      final reactivated =
          plugin.applyEdit(
                deprecated,
                AuthoringCommand(
                  kind: 'reactivate_level',
                  payload: const <String, Object?>{'levelId': 'field'},
                ),
              )
              as LevelDefsDocument;
      expect(
        reactivated.levels
            .firstWhere((level) => level.levelId == 'field')
            .status,
        levelStatusActive,
      );
      expect(
        reactivated.levels
            .firstWhere((level) => level.levelId == 'field')
            .revision,
        4,
      );
    },
  );

  test('valid no-op clears stale operation issues', () {
    final plugin = LevelDomainPlugin();
    const document = LevelDefsDocument(
      workspaceRootPath: '.',
      levels: <LevelDef>[
        LevelDef(
          levelId: 'field',
          revision: 1,
          displayName: 'Field',
          themeId: 'field',
          cameraCenterY: 135,
          groundTopY: 224,
          earlyPatternChunks: 3,
          easyPatternChunks: 0,
          normalPatternChunks: 0,
          noEnemyChunks: 3,
          enumOrdinal: 20,
          status: levelStatusActive,
        ),
      ],
      baseline: null,
      baselineLevels: <LevelDef>[],
      activeLevelId: 'field',
      availableParallaxThemeIds: <String>['field'],
      parallaxThemeSourceAvailable: true,
      authoredChunkCountsByLevelId: <String, int>{'field': 1},
      chunkCountSourceAvailable: true,
      operationIssues: <ValidationIssue>[
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'set_active_level_invalid',
          message: 'stale',
        ),
      ],
    );

    final cleared = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: 'set_active_level',
        payload: const <String, Object?>{'levelId': 'field'},
      ),
    );

    expect(identical(cleared, document), isFalse);
    expect((cleared as LevelDefsDocument).operationIssues, isEmpty);
  });

  test('validation reports structural errors and warnings', () {
    const document = LevelDefsDocument(
      workspaceRootPath: '.',
      levels: <LevelDef>[
        LevelDef(
          levelId: 'field',
          revision: 0,
          displayName: '',
          themeId: 'field',
          cameraCenterY: 9999,
          groundTopY: 224,
          earlyPatternChunks: -1,
          easyPatternChunks: 0,
          normalPatternChunks: 0,
          noEnemyChunks: 3,
          enumOrdinal: 10,
          status: levelStatusDeprecated,
        ),
        LevelDef(
          levelId: 'field',
          revision: 1,
          displayName: 'Forest',
          themeId: 'missing_theme',
          cameraCenterY: 135,
          groundTopY: -10,
          earlyPatternChunks: 3,
          easyPatternChunks: 0,
          normalPatternChunks: 0,
          noEnemyChunks: 3,
          enumOrdinal: 10,
          status: 'weird',
        ),
      ],
      baseline: null,
      baselineLevels: <LevelDef>[],
      activeLevelId: 'field',
      availableParallaxThemeIds: <String>['field'],
      parallaxThemeSourceAvailable: true,
      authoredChunkCountsByLevelId: <String, int>{'field': 0},
      chunkCountSourceAvailable: true,
    );

    final codes = validateLevelDocument(
      document,
    ).map((issue) => issue.code).toSet();

    expect(codes, contains('invalid_revision'));
    expect(codes, contains('missing_display_name'));
    expect(codes, contains('duplicate_level_id'));
    expect(codes, contains('duplicate_enum_ordinal'));
    expect(codes, contains('unusual_camera_center_y'));
    expect(codes, contains('invalid_earlyPatternChunks'));
    expect(codes, contains('deprecated_active_level'));
    expect(codes, contains('missing_parallax_theme'));
    expect(codes, contains('unusual_ground_top_y'));
    expect(codes, contains('invalid_status'));
    expect(codes, contains('level_has_no_chunks'));
  });
}
