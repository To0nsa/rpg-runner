
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_domain_plugin.dart';

import 'test_support/level_parallax_fixture.dart';

void main() {
  test(
    'Level Save Undo Save uses the latest baseline and keeps selection',
    () async {
      final controller = await createLevelParallaxTestSession(
        LevelDomainPlugin(),
      );
      controller.applyCommand(_renameField('Edited Field'));
      controller.applyPresentationCommand(
        AuthoringCommand(
          kind: 'set_active_level',
          payload: const <String, Object?>{'levelId': 'forest'},
        ),
      );
      await controller.exportDirectWrite();
      expect(controller.exportError, isNull);
      final saved = controller.document! as LevelDefsDocument;
      expect(_field(saved).revision, 2);
      expect(controller.canUndo, isTrue);

      controller.undo();

      final undone = controller.document! as LevelDefsDocument;
      expect(_field(undone).displayName, 'Field');
      expect(_field(undone).revision, 3);
      expect(undone.baseline, same(saved.baseline));
      expect(undone.baselineLevels, same(saved.baselineLevels));
      expect(undone.activeLevelId, 'forest');
      expect(undone.parallaxDocument!.activeLevelId, 'forest');
      expect(controller.pendingChanges.hasChanges, isTrue);
      await controller.exportDirectWrite();
      expect(controller.exportError, isNull);
      expect(_field(controller.document! as LevelDefsDocument).revision, 3);
      expect(controller.pendingChanges.hasChanges, isFalse);

      controller.redo();
      expect(
        _field(controller.document! as LevelDefsDocument).displayName,
        'Edited Field',
      );
      expect(_field(controller.document! as LevelDefsDocument).revision, 4);
    },
  );

  test(
    'Undo of unsaved Level values returns to the current clean baseline',
    () async {
      final controller = await createLevelParallaxTestSession(
        LevelDomainPlugin(),
      );
      final baseline = controller.document! as LevelDefsDocument;
      controller.applyCommand(_renameField('First'));
      controller.applyCommand(_renameField('Second'));

      controller.undo();
      expect(
        _field(controller.document! as LevelDefsDocument).displayName,
        'First',
      );
      controller.undo();

      final restored = controller.document! as LevelDefsDocument;
      expect(restored.baseline, same(baseline.baseline));
      expect(_field(restored).revision, 1);
      expect(controller.pendingChanges.hasChanges, isFalse);
    },
  );

  test(
    'first Save seals created Level and theme without losing older value undo',
    () async {
      final controller = await createLevelParallaxTestSession(
        LevelDomainPlugin(),
      );
      controller.applyCommand(_renameField('Edited Field'));
      controller.applyCommand(_createCave());
      final created = controller.document! as LevelDefsDocument;
      final ordinal = findLevelDefById(created.levels, 'cave')!.enumOrdinal;
      await controller.exportDirectWrite();
      expect(controller.exportError, isNull);
      expect(controller.canUndo, isTrue);

      controller.undo();

      final restored = controller.document! as LevelDefsDocument;
      expect(_field(restored).displayName, 'Field');
      expect(findLevelDefById(restored.levels, 'cave')!.enumOrdinal, ordinal);
      expect(
        findParallaxThemeById(restored.parallaxDocument!.themes, 'cave'),
        isNotNull,
      );
      expect(restored.activeLevelId, 'cave');
      expect(controller.canUndo, isFalse);
      await controller.exportDirectWrite();
      expect(controller.exportError, isNull);
      expect(
        findLevelDefById(
          (controller.document! as LevelDefsDocument).levels,
          'cave',
        ),
        isNotNull,
      );
    },
  );

  test(
    'unsaved compound creation can undo and redo before its first Save',
    () async {
      final controller = await createLevelParallaxTestSession(
        LevelDomainPlugin(),
      );
      controller.applyCommand(_createCave());
      controller.undo();
      final undone = controller.document! as LevelDefsDocument;
      expect(findLevelDefById(undone.levels, 'cave'), isNull);
      expect(
        findParallaxThemeById(undone.parallaxDocument!.themes, 'cave'),
        isNull,
      );
      expect(controller.pendingChanges.hasChanges, isFalse);
      controller.redo();
      final redone = controller.document! as LevelDefsDocument;
      expect(findLevelDefById(redone.levels, 'cave')!.revision, 1);
      expect(
        findParallaxThemeById(
          redone.parallaxDocument!.themes,
          'cave',
        )!.revision,
        1,
      );
    },
  );

  test(
    'Parallax Save Undo Save restores layers using current persisted revisions',
    () async {
      final controller = await createLevelParallaxTestSession(
        ParallaxDomainPlugin(),
      );
      controller.applyCommand(
        AuthoringCommand(
          kind: 'update_layer',
          payload: const <String, Object?>{
            'layerKey': 'field_bg',
            'opacity': 0.5,
          },
        ),
      );
      await controller.exportDirectWrite();
      expect(controller.exportError, isNull);
      final saved = controller.document! as ParallaxDefsDocument;
      expect(_fieldTheme(saved).revision, 2);
      expect(controller.canUndo, isTrue);

      controller.undo();

      final undone = controller.document! as ParallaxDefsDocument;
      expect(_fieldTheme(undone).layers.single.opacity, 1);
      expect(_fieldTheme(undone).revision, 3);
      expect(undone.baseline, same(saved.baseline));
      expect(undone.baselineThemes, same(saved.baselineThemes));
      expect(
        undone.parallaxThemeIdByLevelId,
        same(saved.parallaxThemeIdByLevelId),
      );
      await controller.exportDirectWrite();
      expect(controller.exportError, isNull);
      expect(
        _fieldTheme(controller.document! as ParallaxDefsDocument).revision,
        3,
      );
      expect(controller.pendingChanges.hasChanges, isFalse);
    },
  );

  test(
    'Save keeps repeated values as distinct sequential undo targets',
    () async {
      final controller = await createLevelParallaxTestSession(
        LevelDomainPlugin(),
      );
      controller.applyCommand(_renameField('Intermediate'));
      controller.applyCommand(_renameField('Field'));
      await controller.exportDirectWrite();
      expect(controller.exportError, isNull);

      controller.undo();
      expect(
        _field(controller.document! as LevelDefsDocument).displayName,
        'Intermediate',
      );
      expect(controller.canUndo, isTrue);
      controller.undo();
      expect(
        _field(controller.document! as LevelDefsDocument).displayName,
        'Field',
      );
      expect(controller.pendingChanges.hasChanges, isFalse);
    },
  );

  test(
    'first Save seals creation while later value edits remain undoable',
    () async {
      final controller = await createLevelParallaxTestSession(
        LevelDomainPlugin(),
      );
      controller.applyCommand(_createCave());
      controller.applyCommand(
        AuthoringCommand(
          kind: 'update_level',
          payload: const <String, Object?>{
            'levelId': 'cave',
            'displayName': 'Deep Cave',
          },
        ),
      );
      await controller.exportDirectWrite();
      expect(controller.exportError, isNull);

      controller.undo();

      final undone = controller.document! as LevelDefsDocument;
      expect(findLevelDefById(undone.levels, 'cave')!.displayName, 'Cave');
      expect(findLevelDefById(undone.levels, 'cave')!.revision, 3);
      expect(controller.canUndo, isFalse);
      expect(
        findParallaxThemeById(undone.parallaxDocument!.themes, 'cave'),
        isNotNull,
      );
    },
  );

  test(
    'Level history preserves freshly loaded layers and chunk dependencies',
    () async {
      final plugin = LevelDomainPlugin();
      final controller = await createLevelParallaxTestSession(plugin);
      final historical = controller.document! as LevelDefsDocument;
      controller.applyCommand(_renameField('Edited'));
      final edited = controller.document! as LevelDefsDocument;
      final freshThemes = <ParallaxThemeDef>[
        for (final theme in edited.parallaxDocument!.themes)
          if (theme.parallaxThemeId == 'field')
            theme.copyWith(
              revision: 8,
              layers: <ParallaxLayerDef>[
                theme.layers.single.copyWith(opacity: 0.25),
              ],
            )
          else
            theme,
      ];
      final current = edited.copyWith(
        authoredChunkCountsByLevelId: const <String, int>{'field': 7},
        authoredChunkAssemblyGroupCountsByLevelId:
            const <String, Map<String, int>>{
              'field': <String, int>{'woods': 7},
            },
        chunkCountSourceAvailable: true,
        parallaxDocument: edited.parallaxDocument!.copyWith(
          themes: freshThemes,
          baselineThemes: freshThemes,
          baseline: const ParallaxSourceBaseline(
            sourcePath: parallaxDefsSourcePath,
            fingerprint: 'fresh-theme-source',
            sourceContent: 'fresh-theme-source',
          ),
        ),
      );

      final restored =
          plugin.restoreContent(current: current, historical: historical)!
              as LevelDefsDocument;

      expect(_field(restored).displayName, 'Field');
      expect(
        restored.authoredChunkCountsByLevelId,
        same(current.authoredChunkCountsByLevelId),
      );
      expect(
        restored.authoredChunkAssemblyGroupCountsByLevelId,
        same(current.authoredChunkAssemblyGroupCountsByLevelId),
      );
      expect(
        restored.parallaxDocument!.baseline,
        same(current.parallaxDocument!.baseline),
      );
      expect(restored.parallaxDocument!.baselineThemes, same(freshThemes));
      expect(_fieldTheme(restored.parallaxDocument!).revision, 8);
      expect(
        _fieldTheme(restored.parallaxDocument!).layers.single.opacity,
        0.25,
      );
    },
  );

  test(
    'Parallax history preserves fresh mappings and seals saved themes',
    () async {
      final plugin = ParallaxDomainPlugin();
      final controller = await createLevelParallaxTestSession(plugin);
      final historical = controller.document! as ParallaxDefsDocument;
      controller.applyCommand(
        AuthoringCommand(
          kind: 'update_layer',
          payload: const <String, Object?>{
            'layerKey': 'field_bg',
            'opacity': 0.5,
          },
        ),
      );
      final edited = controller.document! as ParallaxDefsDocument;
      final current = edited.copyWith(
        themes: <ParallaxThemeDef>[
          ...edited.themes,
          const ParallaxThemeDef(
            parallaxThemeId: 'cave',
            revision: 4,
            layers: <ParallaxLayerDef>[],
          ),
        ],
        baselineThemes: <ParallaxThemeDef>[
          ...edited.baselineThemes,
          const ParallaxThemeDef(
            parallaxThemeId: 'cave',
            revision: 4,
            layers: <ParallaxLayerDef>[],
          ),
        ],
        availableLevelIds: const <String>['field', 'forest', 'cave'],
        activeLevelId: 'cave',
        levelOptionSource: 'fresh-source',
        parallaxThemeIdByLevelId: const <String, String>{
          'field': 'field',
          'forest': 'forest',
          'cave': 'cave',
        },
      );

      final restored =
          plugin.restoreContent(current: current, historical: historical)!
              as ParallaxDefsDocument;

      expect(_fieldTheme(restored).revision, 1);
      expect(_fieldTheme(restored).layers.single.opacity, 1);
      expect(restored.baseline, same(current.baseline));
      expect(restored.baselineThemes, same(current.baselineThemes));
      expect(restored.availableLevelIds, same(current.availableLevelIds));
      expect(
        restored.parallaxThemeIdByLevelId,
        same(current.parallaxThemeIdByLevelId),
      );
      expect(restored.levelOptionSource, 'fresh-source');
      expect(restored.activeLevelId, 'cave');
      expect(findParallaxThemeById(restored.themes, 'cave')!.revision, 4);
      expect(
        plugin.restoreContent(current: restored, historical: historical),
        same(restored),
      );
    },
  );

  test(
    'Parallax selection and unsaved layer undo preserve a clean baseline',
    () async {
      final controller = await createLevelParallaxTestSession(
        ParallaxDomainPlugin(),
      );
      controller.applyCommand(
        AuthoringCommand(
          kind: 'update_layer',
          payload: const <String, Object?>{
            'layerKey': 'field_bg',
            'opacity': 0.5,
          },
        ),
      );
      controller.applyPresentationCommand(
        AuthoringCommand(
          kind: 'set_active_level',
          payload: const <String, Object?>{'levelId': 'forest'},
        ),
      );

      controller.undo();

      final undone = controller.document! as ParallaxDefsDocument;
      expect(_fieldTheme(undone).revision, 1);
      expect(_fieldTheme(undone).layers.single.opacity, 1);
      expect(undone.activeLevelId, 'forest');
      expect(controller.canUndo, isFalse);
      expect(controller.pendingChanges.hasChanges, isFalse);
    },
  );

  test('history never rebinds source paths across workspaces', () async {
    final levelPlugin = LevelDomainPlugin();
    final levelSession = await createLevelParallaxTestSession(levelPlugin);
    final levelDocument = levelSession.document! as LevelDefsDocument;
    expect(
      levelPlugin.restoreContent(
        current: levelDocument,
        historical: levelDocument.copyWith(
          workspaceRootPath: 'different-workspace',
        ),
      ),
      isNull,
    );
    final parallaxPlugin = ParallaxDomainPlugin();
    final parallaxSession = await createLevelParallaxTestSession(
      parallaxPlugin,
    );
    final parallaxDocument = parallaxSession.document! as ParallaxDefsDocument;
    expect(
      parallaxPlugin.restoreContent(
        current: parallaxDocument,
        historical: parallaxDocument.copyWith(
          workspaceRootPath: 'different-workspace',
        ),
      ),
      isNull,
    );
  });
}

AuthoringCommand _renameField(String name) => AuthoringCommand(
  kind: 'update_level',
  payload: <String, Object?>{'levelId': 'field', 'displayName': name},
);

AuthoringCommand _createCave() => AuthoringCommand(
  kind: 'create_level',
  payload: const <String, Object?>{
    'levelId': 'cave',
    'visualThemeId': 'cave',
    'themeMode': levelThemeModeCreate,
  },
);

LevelDef _field(LevelDefsDocument document) =>
    findLevelDefById(document.levels, 'field')!;

ParallaxThemeDef _fieldTheme(ParallaxDefsDocument document) =>
    findParallaxThemeById(document.themes, 'field')!;
