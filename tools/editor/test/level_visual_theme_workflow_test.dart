import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/levels/level_theme_save_coordinator.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_domain_plugin.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';
import 'package:runner_editor/src/workspace/workspace_write_transaction.dart';

void main() {
  test(
    'new level and theme form one canonical candidate and pending plan',
    () async {
      final fixture = await _createFixtureWorkspace();
      try {
        final workspace = EditorWorkspace(rootPath: fixture.path);
        final plugin = LevelDomainPlugin();
        final loaded =
            await plugin.loadFromRepo(workspace) as LevelDefsDocument;

        final candidate =
            plugin.applyEdit(
                  loaded,
                  AuthoringCommand(
                    kind: 'create_level',
                    payload: <String, Object?>{
                      'levelId': 'crystal_caves',
                      'themeMode': levelThemeModeCreate,
                      'visualThemeId': 'crystal_caves',
                    },
                  ),
                )
                as LevelDefsDocument;

        final level = findLevelDefById(candidate.levels, 'crystal_caves');
        final theme = findParallaxThemeById(
          candidate.parallaxDocument!.themes,
          'crystal_caves',
        );
        expect(level, isNotNull);
        expect(level!.revision, 1);
        expect(level.visualThemeId, 'crystal_caves');
        expect(theme, isNotNull);
        expect(theme!.revision, 1);
        expect(theme.layers, isEmpty);
        expect(candidate.sessionCreatedParallaxThemeIds, {'crystal_caves'});
        expect(
          candidate.parallaxDocument!.parallaxThemeIdByLevelId['crystal_caves'],
          'crystal_caves',
        );
        expect(
          plugin
              .validate(candidate)
              .where((issue) => issue.severity == ValidationSeverity.error),
          isEmpty,
        );

        final pending = plugin.describePendingChanges(
          workspace,
          document: candidate,
        );
        expect(pending.changedItemIds, <String>[
          'level:crystal_caves',
          'parallaxTheme:crystal_caves',
        ]);
        expect(pending.fileDiffs.map((diff) => diff.relativePath), <String>[
          levelDefsSourcePath,
          parallaxDefsSourcePath,
        ]);
      } finally {
        fixture.deleteSync(recursive: true);
      }
    },
  );

  test('reusing an existing theme plans only the Level source', () async {
    final fixture = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixture.path);
      final plugin = LevelDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace) as LevelDefsDocument;

      final candidate =
          plugin.applyEdit(
                loaded,
                AuthoringCommand(
                  kind: 'create_level',
                  payload: <String, Object?>{
                    'levelId': 'forest_path',
                    'themeMode': levelThemeModeExisting,
                    'visualThemeId': 'field',
                  },
                ),
              )
              as LevelDefsDocument;
      final pending = plugin.describePendingChanges(
        workspace,
        document: candidate,
      );

      expect(pending.changedItemIds, <String>['level:forest_path']);
      expect(pending.fileDiffs.single.relativePath, levelDefsSourcePath);
      expect(
        renderCanonicalParallaxDefsJson(candidate.parallaxDocument!.themes),
        renderCanonicalParallaxDefsJson(loaded.parallaxDocument!.themes),
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test(
    'create-and-assign bumps once and prunes only its abandoned staged theme',
    () async {
      final fixture = await _createFixtureWorkspace();
      try {
        final workspace = EditorWorkspace(rootPath: fixture.path);
        final plugin = LevelDomainPlugin();
        final loaded =
            await plugin.loadFromRepo(workspace) as LevelDefsDocument;

        final assigned =
            plugin.applyEdit(
                  loaded,
                  AuthoringCommand(
                    kind: 'create_and_assign_theme',
                    payload: <String, Object?>{
                      'levelId': 'field',
                      'visualThemeId': 'crystal',
                    },
                  ),
                )
                as LevelDefsDocument;
        expect(findLevelDefById(assigned.levels, 'field')!.revision, 2);
        expect(
          findParallaxThemeById(assigned.parallaxDocument!.themes, 'crystal'),
          isNotNull,
        );

        final reassigned =
            plugin.applyEdit(
                  assigned,
                  AuthoringCommand(
                    kind: 'update_level',
                    payload: <String, Object?>{
                      'levelId': 'field',
                      'visualThemeId': 'field',
                    },
                  ),
                )
                as LevelDefsDocument;
        expect(findLevelDefById(reassigned.levels, 'field')!.revision, 3);
        expect(
          findParallaxThemeById(reassigned.parallaxDocument!.themes, 'crystal'),
          isNull,
        );
        expect(reassigned.sessionCreatedParallaxThemeIds, isEmpty);
        expect(
          findParallaxThemeById(reassigned.parallaxDocument!.themes, 'field'),
          isNotNull,
        );
      } finally {
        fixture.deleteSync(recursive: true);
      }
    },
  );

  test('new-theme collisions never silently become reuse', () async {
    final fixture = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixture.path);
      final plugin = LevelDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace) as LevelDefsDocument;

      final rawCollision =
          plugin.applyEdit(
                loaded,
                AuthoringCommand(
                  kind: 'create_level',
                  payload: <String, Object?>{
                    'levelId': 'cave',
                    'themeMode': levelThemeModeCreate,
                    'visualThemeId': 'field',
                  },
                ),
              )
              as LevelDefsDocument;
      expect(rawCollision.levels, same(loaded.levels));
      expect(
        rawCollision.operationIssues.single.code,
        'create_theme_id_collision',
      );

      final symbolCollision =
          plugin.applyEdit(
                loaded,
                AuthoringCommand(
                  kind: 'create_level',
                  payload: <String, Object?>{
                    'levelId': 'cave',
                    'themeMode': levelThemeModeCreate,
                    'visualThemeId': 'field_',
                  },
                ),
              )
              as LevelDefsDocument;
      expect(symbolCollision.levels, same(loaded.levels));
      expect(
        symbolCollision.operationIssues.single.code,
        'create_theme_generated_symbol_collision',
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('two-file apply installs a cross-file-valid authored pair', () async {
    final fixture = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixture.path);
      final plugin = LevelDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace) as LevelDefsDocument;
      final candidate =
          plugin.applyEdit(
                loaded,
                AuthoringCommand(
                  kind: 'create_level',
                  payload: <String, Object?>{
                    'levelId': 'crystal_caves',
                    'themeMode': levelThemeModeCreate,
                    'visualThemeId': 'crystal_caves',
                  },
                ),
              )
              as LevelDefsDocument;

      final result = await plugin.exportToRepo(workspace, document: candidate);
      expect(result.applied, isTrue);

      final reloaded =
          await plugin.loadFromRepo(workspace) as LevelDefsDocument;
      expect(
        findLevelDefById(reloaded.levels, 'crystal_caves')!.visualThemeId,
        'crystal_caves',
      );
      expect(
        findParallaxThemeById(
          reloaded.parallaxDocument!.themes,
          'crystal_caves',
        ),
        isNotNull,
      );
      expect(
        plugin
            .validate(reloaded)
            .where((issue) => issue.severity == ValidationSeverity.error),
        isEmpty,
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('Parallax drift aborts before either source is replaced', () async {
    final fixture = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixture.path);
      final plugin = LevelDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace) as LevelDefsDocument;
      final candidate =
          plugin.applyEdit(
                loaded,
                AuthoringCommand(
                  kind: 'create_level',
                  payload: <String, Object?>{
                    'levelId': 'crystal_caves',
                    'themeMode': levelThemeModeCreate,
                    'visualThemeId': 'crystal_caves',
                  },
                ),
              )
              as LevelDefsDocument;
      final levelFile = File(p.join(fixture.path, levelDefsSourcePath));
      final parallaxFile = File(p.join(fixture.path, parallaxDefsSourcePath));
      final originalLevel = levelFile.readAsStringSync();
      final driftedParallax = parallaxFile.readAsStringSync().replaceFirst(
        '"revision": 1',
        '"revision": 2',
      );
      parallaxFile.writeAsStringSync(driftedParallax);

      await expectLater(
        plugin.exportToRepo(workspace, document: candidate),
        throwsA(
          isA<LevelThemeSaveException>().having(
            (error) => error.rollbackComplete,
            'rollbackComplete',
            isTrue,
          ),
        ),
      );
      expect(levelFile.readAsStringSync(), originalLevel);
      expect(parallaxFile.readAsStringSync(), driftedParallax);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test(
    'verified commit cleanup failure returns typed recovery state',
    () async {
      final fixture = await _createFixtureWorkspace();
      try {
        final workspace = EditorWorkspace(rootPath: fixture.path);
        late String recoveryPath;
        void committedWithCleanupFailure(
          Iterable<WorkspaceWriteArtifact> artifacts, {
          required void Function() beforeReplace,
          required void Function() verifyReplacements,
        }) {
          beforeReplace();
          for (final artifact in artifacts) {
            File(
              artifact.path,
            ).writeAsStringSync(artifact.contents, flush: true);
          }
          verifyReplacements();
          recoveryPath = '${artifacts.first.path}.authoring-test.bak';
          File(recoveryPath).writeAsStringSync('transaction recovery evidence');
          throw WorkspaceWriteTransactionException(
            cause: StateError('Injected cleanup failure.'),
            rollbackFailures: const <String>['injected cleanup failure'],
            outputsCommitted: true,
            recoveryPaths: <String>[recoveryPath],
          );
        }

        final coordinator = LevelThemeSaveCoordinator(
          transactionRunner: committedWithCleanupFailure,
        );
        final plugin = LevelDomainPlugin(saveCoordinator: coordinator);
        final loaded =
            await plugin.loadFromRepo(workspace) as LevelDefsDocument;
        final candidate =
            plugin.applyEdit(
                  loaded,
                  AuthoringCommand(
                    kind: 'create_level',
                    payload: <String, Object?>{
                      'levelId': 'crystal_caves',
                      'themeMode': levelThemeModeCreate,
                      'visualThemeId': 'crystal_caves',
                    },
                  ),
                )
                as LevelDefsDocument;

        final result = await plugin.exportToRepo(
          workspace,
          document: candidate,
        );
        expect(result, isA<LevelThemeExportResult>());
        final typedResult = result as LevelThemeExportResult;
        expect(typedResult.applied, isTrue);
        expect(typedResult.cleanupRequiredPaths, <String>[recoveryPath]);
        expect(File(recoveryPath).existsSync(), isTrue);
        expect(
          File(p.join(fixture.path, levelDefsSourcePath)).readAsStringSync(),
          contains('"levelId": "crystal_caves"'),
        );
        expect(
          File(p.join(fixture.path, parallaxDefsSourcePath)).readAsStringSync(),
          contains('"parallaxThemeId": "crystal_caves"'),
        );
      } finally {
        fixture.deleteSync(recursive: true);
      }
    },
  );

  test(
    'targeted Parallax load rejects stale intent and opens the exact pair',
    () async {
      final fixture = await _createFixtureWorkspace();
      try {
        final workspace = EditorWorkspace(rootPath: fixture.path);
        final plugin = ParallaxDomainPlugin();

        final loaded = await plugin.loadForLevel(
          workspace,
          target: const ParallaxLevelTarget(
            levelId: 'field',
            parallaxThemeId: 'field',
          ),
        );
        expect(loaded.activeLevelId, 'field');
        expect(resolveActiveParallaxThemeId(loaded), 'field');

        await expectLater(
          plugin.loadForLevel(
            workspace,
            target: const ParallaxLevelTarget(
              levelId: 'field',
              parallaxThemeId: 'stale_theme',
            ),
          ),
          throwsA(isA<StateError>()),
        );
      } finally {
        fixture.deleteSync(recursive: true);
      }
    },
  );

  test(
    'new empty theme accepts its first layer after targeted handoff',
    () async {
      final fixture = await _createFixtureWorkspace();
      try {
        final workspace = EditorWorkspace(rootPath: fixture.path);
        final levelPlugin = LevelDomainPlugin();
        final loaded =
            await levelPlugin.loadFromRepo(workspace) as LevelDefsDocument;
        final candidate =
            levelPlugin.applyEdit(
                  loaded,
                  AuthoringCommand(
                    kind: 'create_level',
                    payload: const <String, Object?>{
                      'levelId': 'crystal',
                      'themeMode': levelThemeModeCreate,
                      'visualThemeId': 'crystal',
                    },
                  ),
                )
                as LevelDefsDocument;
        await levelPlugin.exportToRepo(workspace, document: candidate);
        _writeFile(
          fixture.path,
          'assets/images/parallax/crystal/bg.png',
          'fixture',
        );

        final parallaxPlugin = ParallaxDomainPlugin();
        final parallax = await parallaxPlugin.loadForLevel(
          workspace,
          target: const ParallaxLevelTarget(
            levelId: 'crystal',
            parallaxThemeId: 'crystal',
          ),
        );
        final edited =
            parallaxPlugin.applyEdit(
                  parallax,
                  AuthoringCommand(
                    kind: 'create_layer',
                    payload: const <String, Object?>{
                      'layerKey': 'crystal_bg',
                      'assetPath': 'assets/images/parallax/crystal/bg.png',
                      'group': parallaxGroupBackground,
                    },
                  ),
                )
                as ParallaxDefsDocument;
        expect(
          findParallaxThemeById(
            edited.themes,
            'crystal',
          )!.layers.single.layerKey,
          'crystal_bg',
        );
        expect(
          parallaxPlugin
              .validate(edited)
              .where((issue) => issue.severity == ValidationSeverity.error),
          isEmpty,
        );
      } finally {
        fixture.deleteSync(recursive: true);
      }
    },
  );
}

Future<Directory> _createFixtureWorkspace() async {
  final root = await Directory.systemTemp.createTemp('level_theme_workflow_');
  _writeFile(root.path, levelDefsSourcePath, '''
{
  "schemaVersion": 1,
  "levels": [
    {
      "levelId": "field",
      "revision": 1,
      "displayName": "Field",
      "visualThemeId": "field",
      "chunkThemeGroups": ["default"],
      "cameraCenterY": 135,
      "groundTopY": 224,
      "earlyPatternChunks": 3,
      "easyPatternChunks": 0,
      "normalPatternChunks": 0,
      "noEnemyChunks": 3,
      "enumOrdinal": 10,
      "status": "active"
    }
  ]
}
''');
  _writeFile(root.path, parallaxDefsSourcePath, '''
{
  "schemaVersion": 2,
  "themes": [
    {
      "parallaxThemeId": "field",
      "revision": 1,
      "layers": [
      ]
    }
  ]
}
''');
  _writeFile(
    root.path,
    'assets/authoring/level/chunks/field/chunk_field_001.json',
    '{"levelId":"field","assemblyGroupId":"default"}\n',
  );
  return root;
}

void _writeFile(String rootPath, String relativePath, String content) {
  final file = File(p.join(rootPath, relativePath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content.trimLeft());
}
