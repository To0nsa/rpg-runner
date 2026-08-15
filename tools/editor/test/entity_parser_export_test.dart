import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/entities/entity_export_pipeline.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';
import 'package:runner_editor/src/workspace/workspace_write_transaction.dart';

import 'test_support/entity_test_support.dart';

void main() {
  test('direct write export updates source file content', () async {
    final fixtureRoot = Directory.systemTemp.createTempSync(
      'runner_editor_fixture_',
    );
    try {
      writeEntityColliderFixture(fixtureRoot.path);
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      final plugin = EntityDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace);
      final document = loaded as EntityDocument;

      final enemy = document.entries.firstWhere(
        (entry) => entry.id.startsWith('enemy.'),
      );
      final edited = plugin.applyEdit(
        document,
        buildEntityUpdateCommand(enemy, halfX: enemy.halfX + 1.0),
      );

      final export = await plugin.exportToRepo(workspace, document: edited);

      expect(export.applied, isTrue);
      expect(
        export.artifacts.any(
          (artifact) => artifact.title == 'entity_backups.md',
        ),
        isTrue,
      );

      final enemyFile = File(
        p.join(
          fixtureRoot.path,
          'packages/runner_core/lib/enemies/enemy_catalog.dart',
        ),
      ).readAsStringSync();
      expect(enemyFile, contains('halfX: 13.0'));

      final enemyBackupFile = File(
        p.join(
          fixtureRoot.path,
          'packages/runner_core/lib/enemies/enemy_catalog.dart.bak',
        ),
      );
      expect(enemyBackupFile.existsSync(), isTrue);
      expect(enemyBackupFile.readAsStringSync(), contains('halfX: 12.0'));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test(
    'enemy collider references bind and write the top-level initializer',
    () async {
      final fixtureRoot = Directory.systemTemp.createTempSync(
        'runner_editor_fixture_',
      );
      try {
        writeEntityColliderFixture(
          fixtureRoot.path,
          useTopLevelEnemyCollider: true,
        );
        final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
        final plugin = EntityDomainPlugin();
        final loaded = await plugin.loadFromRepo(workspace);
        final document = loaded as EntityDocument;
        final enemy = document.entries.singleWhere(
          (entry) => entry.id == 'enemy.unocoDemon',
        );

        expect(
          enemy.colliderBindings.halfX.sourceBinding.sourceSnippet,
          '12.0',
        );
        expect(
          document.loadIssues.map((issue) => issue.code),
          isNot(contains('enemy_collider_missing')),
        );

        final edited = plugin.applyEdit(
          document,
          buildEntityUpdateCommand(enemy, halfX: 13.0),
        );
        await plugin.exportToRepo(workspace, document: edited);

        final enemySource = File(
          p.join(
            fixtureRoot.path,
            'packages/runner_core/lib/enemies/enemy_catalog.dart',
          ),
        ).readAsStringSync();
        expect(enemySource, contains('halfX: 13.0'));
        expect(enemySource, contains('collider: _unocoCollider'));
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test('fixture parser keeps per-anim row/frame/grid metadata', () async {
    final fixtureRoot = Directory.systemTemp.createTempSync(
      'runner_editor_fixture_',
    );
    try {
      writeEntityColliderFixture(fixtureRoot.path);
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      final plugin = EntityDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace);
      final document = loaded as EntityDocument;

      final projectile = document.entries.firstWhere(
        (entry) => entry.id == 'projectile.fireBolt',
      );
      final reference = projectile.referenceVisual;
      expect(reference, isNotNull);
      expect(reference!.defaultAnimKey, 'idle');
      expect(
        reference.animViewsByKey.keys,
        containsAll(['spawn', 'idle', 'hit']),
      );

      final idleView = reference.animViewsByKey['idle'];
      final hitView = reference.animViewsByKey['hit'];
      expect(idleView, isNotNull);
      expect(hitView, isNotNull);
      expect(idleView!.row, 1);
      expect(idleView.frameStart, 2);
      expect(idleView.gridColumns, 5);
      expect(idleView.frameCount, 8);
      expect(hitView!.assetPath, 'entities/spells/fire/bolt/hit.png');
      expect(hitView.gridColumns, 4);
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test(
    'asset availability is cached in the loaded document and scene',
    () async {
      final fixtureRoot = Directory.systemTemp.createTempSync(
        'runner_editor_fixture_',
      );
      try {
        writeEntityColliderFixture(fixtureRoot.path);
        final asset = File(
          p.join(
            fixtureRoot.path,
            'assets/images/entities/spells/fire/bolt/spriteSheet.png',
          ),
        );
        asset.parent.createSync(recursive: true);
        asset.writeAsBytesSync(const <int>[0]);
        final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
        final plugin = EntityDomainPlugin();

        final document = await plugin.loadFromRepo(workspace) as EntityDocument;
        asset.deleteSync();
        final scene = plugin.buildEditableScene(document) as EntityScene;

        const canonicalPath =
            'assets/images/entities/spells/fire/bolt/spriteSheet.png';
        expect(document.availableAssetPaths, contains(canonicalPath));
        expect(scene.availableAssetPaths, contains(canonicalPath));
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test(
    'fixture parser reads runtime grid cell size from spatial tuning',
    () async {
      final fixtureRoot = Directory.systemTemp.createTempSync(
        'runner_editor_fixture_',
      );
      try {
        writeEntityColliderFixture(fixtureRoot.path, broadphaseCellSize: 48.0);
        final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
        final plugin = EntityDomainPlugin();
        final loaded = await plugin.loadFromRepo(workspace);
        final document = loaded as EntityDocument;

        expect(document.runtimeGridCellSize, closeTo(48.0, 0.0001));

        final scene = plugin.buildEditableScene(document) as EntityScene;
        expect(scene.runtimeGridCellSize, closeTo(48.0, 0.0001));
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test(
    'direct write export writes anchorPoint and renderScale reference edits',
    () async {
      final fixtureRoot = Directory.systemTemp.createTempSync(
        'runner_editor_fixture_',
      );
      try {
        writeEntityColliderFixture(
          fixtureRoot.path,
          includeReferenceBindings: true,
        );
        final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
        final plugin = EntityDomainPlugin();
        final loaded = await plugin.loadFromRepo(workspace);
        final document = loaded as EntityDocument;

        final projectile = document.entries.firstWhere(
          (entry) => entry.id == 'projectile.fireBolt',
        );
        final reference = projectile.referenceVisual;
        expect(reference, isNotNull);
        expect(reference!.anchorBinding, isNotNull);
        expect(reference.hasWritableAnchorPoint, isTrue);
        expect(reference.renderScaleBinding, isNotNull);

        final edited = plugin.applyEdit(
          document,
          buildEntityUpdateCommand(
            projectile,
            anchorXPx: 30.0,
            anchorYPx: 20.0,
            renderScale: 1.25,
          ),
        );

        final export = await plugin.exportToRepo(workspace, document: edited);
        final patchArtifact = export.artifacts.firstWhere(
          (artifact) => artifact.title == 'entity_changes.patch',
        );
        expect(
          patchArtifact.content,
          contains(
            'packages/runner_core/lib/projectiles/projectile_render_catalog.dart',
          ),
        );
        expect(
          patchArtifact.content,
          contains(
            'lib/game/components/projectiles/projectile_render_registry.dart',
          ),
        );
        expect(patchArtifact.content, contains('Vec2(30.0, 20.0)'));
        expect(patchArtifact.content, contains('Vector2.all(1.25)'));
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test('export blocks writes while validation has blocking errors', () async {
    final fixtureRoot = Directory.systemTemp.createTempSync(
      'runner_editor_fixture_',
    );
    try {
      writeEntityColliderFixture(fixtureRoot.path);
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      final plugin = EntityDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace);
      final document = loaded as EntityDocument;

      final enemy = document.entries.firstWhere(
        (entry) => entry.id.startsWith('enemy.'),
      );
      final edited = plugin.applyEdit(
        document,
        buildEntityUpdateCommand(enemy, halfX: -1.0),
      );

      final enemyPath = p.join(
        fixtureRoot.path,
        'packages/runner_core/lib/enemies/enemy_catalog.dart',
      );
      final export = await plugin.exportToRepo(workspace, document: edited);

      expect(export.applied, isFalse);
      expect(export.outcome, ExportOutcome.validationFailed);
      final errorArtifact = export.artifacts.firstWhere(
        (artifact) => artifact.title == 'entity_export_error.md',
      );
      expect(
        errorArtifact.content,
        contains('Cannot export entities while validation has 1 blocking'),
      );
      expect(File(enemyPath).readAsStringSync(), contains('halfX: 12.0'));
      expect(File('$enemyPath.bak').existsSync(), isFalse);
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('failed backup creation leaves source files unchanged', () async {
    final fixtureRoot = Directory.systemTemp.createTempSync(
      'runner_editor_fixture_',
    );
    try {
      writeEntityColliderFixture(
        fixtureRoot.path,
        includeReferenceBindings: true,
      );
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      final plugin = EntityDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace);
      final document = loaded as EntityDocument;

      final enemy = document.entries.firstWhere(
        (entry) => entry.id.startsWith('enemy.'),
      );
      final projectile = document.entries.firstWhere(
        (entry) => entry.id == 'projectile.fireBolt',
      );
      final editedEnemy = plugin.applyEdit(
        document,
        buildEntityUpdateCommand(enemy, halfX: enemy.halfX + 1.0),
      );
      final edited = plugin.applyEdit(
        editedEnemy,
        buildEntityUpdateCommand(projectile, renderScale: 1.25),
      );

      final enemyPath = p.join(
        fixtureRoot.path,
        'packages/runner_core/lib/enemies/enemy_catalog.dart',
      );
      final projectileRegistryPath = p.join(
        fixtureRoot.path,
        'lib/game/components/projectiles/projectile_render_registry.dart',
      );
      final enemyBefore = File(enemyPath).readAsStringSync();
      final projectileRegistryBefore = File(
        projectileRegistryPath,
      ).readAsStringSync();

      Directory('$enemyPath.bak').createSync(recursive: true);

      final export = await plugin.exportToRepo(workspace, document: edited);

      expect(export.applied, isFalse);
      expect(File(enemyPath).readAsStringSync(), enemyBefore);
      expect(
        File(projectileRegistryPath).readAsStringSync(),
        projectileRegistryBefore,
      );
      expect(File('$projectileRegistryPath.bak').existsSync(), isFalse);
      expect(Directory('$enemyPath.bak').existsSync(), isTrue);
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test(
    'export handles reordered player and projectile collider args',
    () async {
      final fixtureRoot = Directory.systemTemp.createTempSync(
        'runner_editor_fixture_',
      );
      try {
        writeEntityColliderFixture(
          fixtureRoot.path,
          reorderPlayerColliderArgs: true,
          reorderProjectileColliderArgs: true,
        );
        final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
        final plugin = EntityDomainPlugin();
        final loaded = await plugin.loadFromRepo(workspace);
        final document = loaded as EntityDocument;

        final player = document.entries.firstWhere(
          (entry) => entry.id == 'player.eloise',
        );
        final projectile = document.entries.firstWhere(
          (entry) => entry.id == 'projectile.fireBolt',
        );
        final editedPlayer = plugin.applyEdit(
          document,
          buildEntityUpdateCommand(player, halfX: player.halfX + 1.0),
        );
        final edited = plugin.applyEdit(
          editedPlayer,
          buildEntityUpdateCommand(projectile, halfY: projectile.halfY + 1.0),
        );

        final export = await plugin.exportToRepo(workspace, document: edited);

        expect(export.applied, isTrue);
        final playerFile = File(
          p.join(
            fixtureRoot.path,
            'packages/runner_core/lib/players/characters/eloise.dart',
          ),
        ).readAsStringSync();
        final projectileFile = File(
          p.join(
            fixtureRoot.path,
            'packages/runner_core/lib/projectiles/projectile_catalog.dart',
          ),
        ).readAsStringSync();
        expect(
          playerFile,
          contains(
            'colliderOffsetY: 0.0,\n'
            '  colliderWidth: 24.0,\n'
            '  colliderOffsetX: 0.0,\n'
            '  colliderHeight: 46.0',
          ),
        );
        expect(
          projectileFile,
          contains('colliderSizeY: 10.0,\n          colliderSizeX: 18.0'),
        );
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test(
    'scalar collider edits preserve interleaved arguments and comments',
    () async {
      final fixtureRoot = Directory.systemTemp.createTempSync(
        'runner_editor_fixture_',
      );
      try {
        writeEntityColliderFixture(
          fixtureRoot.path,
          reorderPlayerColliderArgs: true,
          reorderProjectileColliderArgs: true,
          interleaveColliderContent: true,
        );
        final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
        final plugin = EntityDomainPlugin();
        final document = await plugin.loadFromRepo(workspace) as EntityDocument;
        final player = document.entries.singleWhere(
          (entry) => entry.id == 'player.eloise',
        );
        final projectile = document.entries.singleWhere(
          (entry) => entry.id == 'projectile.fireBolt',
        );
        final editedPlayer = plugin.applyEdit(
          document,
          buildEntityUpdateCommand(player, halfX: player.halfX + 1.0),
        );
        final edited = plugin.applyEdit(
          editedPlayer,
          buildEntityUpdateCommand(projectile, halfY: projectile.halfY + 1.0),
        );

        final result = await plugin.exportToRepo(workspace, document: edited);

        expect(result.outcome, ExportOutcome.applied);
        final playerSource = File(
          p.join(
            fixtureRoot.path,
            'packages/runner_core/lib/players/characters/eloise.dart',
          ),
        ).readAsStringSync();
        final projectileSource = File(
          p.join(
            fixtureRoot.path,
            'packages/runner_core/lib/projectiles/projectile_catalog.dart',
          ),
        ).readAsStringSync();
        expect(
          playerSource,
          contains(
            '// This unrelated argument must survive collider edits.\n'
            '  movementSpeed: 99.0,',
          ),
        );
        expect(playerSource, contains('colliderWidth: 24.0'));
        expect(
          projectileSource,
          contains(
            '// Preserve projectile behavior metadata.\n'
            '          ballistic: true,',
          ),
        );
        expect(projectileSource, contains('colliderSizeY: 10.0'));
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test(
    'final pre-replace drift aborts without overwriting external edits',
    () async {
      final fixtureRoot = Directory.systemTemp.createTempSync(
        'runner_editor_fixture_',
      );
      try {
        writeEntityColliderFixture(fixtureRoot.path);
        final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
        final enemyPath = p.join(
          fixtureRoot.path,
          'packages/runner_core/lib/enemies/enemy_catalog.dart',
        );
        final plugin = EntityDomainPlugin(
          exportPipeline: EntityExportPipeline(
            hooks: EntityExportHooks(
              beforeReplace: (_) {
                final source = File(enemyPath).readAsStringSync();
                File(enemyPath).writeAsStringSync(
                  source.replaceFirst('halfX: 12.0', 'halfX: 99.0'),
                );
              },
            ),
          ),
        );
        final document = await plugin.loadFromRepo(workspace) as EntityDocument;
        final enemy = document.entries.singleWhere(
          (entry) => entry.id == 'enemy.unocoDemon',
        );
        final edited = plugin.applyEdit(
          document,
          buildEntityUpdateCommand(enemy, halfX: 13.0),
        );

        final result = await plugin.exportToRepo(workspace, document: edited);

        expect(result.outcome, ExportOutcome.sourceDrift);
        expect(result.message, contains('Final source drift detected'));
        expect(File(enemyPath).readAsStringSync(), contains('halfX: 99.0'));
        expect(File('$enemyPath.bak').existsSync(), isFalse);
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  for (final failurePoint in <String>['first', 'middle', 'last']) {
    test(
      '$failurePoint replacement failure rolls back the whole artifact set',
      () async {
        final fixtureRoot = Directory.systemTemp.createTempSync(
          'runner_editor_fixture_',
        );
        try {
          writeEntityColliderFixture(
            fixtureRoot.path,
            includeReferenceBindings: true,
          );
          final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
          final pipeline = EntityExportPipeline(
            transactionApply: (transaction, beforeReplace, verifyReplacements) {
              transaction.apply(
                beforeReplace: () {
                  beforeReplace();
                  final staged =
                      fixtureRoot
                          .listSync(recursive: true)
                          .whereType<File>()
                          .where((file) => file.path.endsWith('.tmp'))
                          .toList()
                        ..sort(
                          (left, right) => left.path.compareTo(right.path),
                        );
                  final index = switch (failurePoint) {
                    'first' => 0,
                    'middle' => staged.length ~/ 2,
                    'last' => staged.length - 1,
                    _ => throw StateError('Unknown failure point.'),
                  };
                  staged[index].deleteSync();
                },
                verifyReplacements: verifyReplacements,
              );
            },
          );
          final plugin = EntityDomainPlugin(exportPipeline: pipeline);
          final document =
              await plugin.loadFromRepo(workspace) as EntityDocument;
          final enemy = document.entries.singleWhere(
            (entry) => entry.id == 'enemy.unocoDemon',
          );
          final projectile = document.entries.singleWhere(
            (entry) => entry.id == 'projectile.fireBolt',
          );
          final enemyPath = workspace.resolve(enemy.sourcePath);
          final registryPath = workspace.resolve(
            projectile.referenceVisual!.renderScaleBinding!.sourcePath,
          );
          final enemyBefore = File(enemyPath).readAsStringSync();
          final registryBefore = File(registryPath).readAsStringSync();
          final editedEnemy = plugin.applyEdit(
            document,
            buildEntityUpdateCommand(enemy, halfX: 13.0),
          );
          final edited = plugin.applyEdit(
            editedEnemy,
            buildEntityUpdateCommand(projectile, renderScale: 1.25),
          );

          final result = await plugin.exportToRepo(workspace, document: edited);

          expect(result.outcome, ExportOutcome.failed);
          expect(File(enemyPath).readAsStringSync(), enemyBefore);
          expect(File(registryPath).readAsStringSync(), registryBefore);
          expect(File('$enemyPath.bak').existsSync(), isFalse);
          expect(File('$registryPath.bak').existsSync(), isFalse);
        } finally {
          fixtureRoot.deleteSync(recursive: true);
        }
      },
    );
  }

  test(
    'verification failure restores source and an existing persistent backup',
    () async {
      final fixtureRoot = Directory.systemTemp.createTempSync(
        'runner_editor_fixture_',
      );
      try {
        writeEntityColliderFixture(fixtureRoot.path);
        final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
        final plugin = EntityDomainPlugin(
          exportPipeline: EntityExportPipeline(
            hooks: EntityExportHooks(
              verifyReplacements: (_) =>
                  throw StateError('forced verify failure'),
            ),
          ),
        );
        final document = await plugin.loadFromRepo(workspace) as EntityDocument;
        final enemy = document.entries.singleWhere(
          (entry) => entry.id == 'enemy.unocoDemon',
        );
        final sourcePath = workspace.resolve(enemy.sourcePath);
        final sourceBefore = File(sourcePath).readAsStringSync();
        final persistentBackup = File('$sourcePath.bak')
          ..writeAsStringSync('pre-existing backup evidence');
        final edited = plugin.applyEdit(
          document,
          buildEntityUpdateCommand(enemy, halfX: 13.0),
        );

        final result = await plugin.exportToRepo(workspace, document: edited);

        expect(result.outcome, ExportOutcome.failed);
        expect(result.message, contains('forced verify failure'));
        expect(File(sourcePath).readAsStringSync(), sourceBefore);
        expect(
          persistentBackup.readAsStringSync(),
          'pre-existing backup evidence',
        );
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test('incomplete rollback reports recovery state distinctly', () async {
    final fixtureRoot = Directory.systemTemp.createTempSync(
      'runner_editor_fixture_',
    );
    try {
      writeEntityColliderFixture(fixtureRoot.path);
      final recoveryPath = p.join(fixtureRoot.path, 'retained-recovery.bak');
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      final plugin = EntityDomainPlugin(
        exportPipeline: EntityExportPipeline(
          transactionApply: (_, _, _) {
            File(recoveryPath).writeAsStringSync('recovery evidence');
            throw WorkspaceWriteTransactionException(
              cause: StateError('forced install failure'),
              rollbackFailures: const <String>['forced restore failure'],
              outputsCommitted: false,
              recoveryPaths: <String>[recoveryPath],
            );
          },
        ),
      );
      final document = await plugin.loadFromRepo(workspace) as EntityDocument;
      final enemy = document.entries.singleWhere(
        (entry) => entry.id == 'enemy.unocoDemon',
      );
      final sourcePath = workspace.resolve(enemy.sourcePath);
      final sourceBefore = File(sourcePath).readAsStringSync();
      final edited = plugin.applyEdit(
        document,
        buildEntityUpdateCommand(enemy, halfX: 13.0),
      );

      final result = await plugin.exportToRepo(workspace, document: edited);

      expect(result.applied, isFalse);
      expect(result.outcome, ExportOutcome.rollbackIncomplete);
      expect(File(sourcePath).readAsStringSync(), sourceBefore);
      expect(
        result.artifacts
            .singleWhere(
              (artifact) => artifact.title == 'entity_transaction_recovery.md',
            )
            .content,
        contains(recoveryPath),
      );
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test(
    'committed output with cleanup failure is reported as applied',
    () async {
      final fixtureRoot = Directory.systemTemp.createTempSync(
        'runner_editor_fixture_',
      );
      try {
        writeEntityColliderFixture(fixtureRoot.path);
        final recoveryPath = p.join(
          fixtureRoot.path,
          'packages/runner_core/lib/enemies/simulated-recovery.bak',
        );
        final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
        final plugin = EntityDomainPlugin(
          exportPipeline: EntityExportPipeline(
            transactionApply: (transaction, beforeReplace, verifyReplacements) {
              transaction.apply(
                beforeReplace: beforeReplace,
                verifyReplacements: verifyReplacements,
              );
              File(
                recoveryPath,
              ).writeAsStringSync('simulated cleanup evidence');
              throw WorkspaceWriteTransactionException(
                cause: StateError('forced cleanup failure'),
                rollbackFailures: const <String>['forced cleanup failure'],
                outputsCommitted: true,
                recoveryPaths: <String>[recoveryPath],
              );
            },
          ),
        );
        final document = await plugin.loadFromRepo(workspace) as EntityDocument;
        final enemy = document.entries.singleWhere(
          (entry) => entry.id == 'enemy.unocoDemon',
        );
        final edited = plugin.applyEdit(
          document,
          buildEntityUpdateCommand(enemy, halfX: 13.0),
        );

        final result = await plugin.exportToRepo(workspace, document: edited);

        expect(result.applied, isTrue);
        expect(result.outcome, ExportOutcome.appliedWithCleanupRequired);
        expect(
          File(workspace.resolve(enemy.sourcePath)).readAsStringSync(),
          contains('halfX: 13.0'),
        );
        expect(
          result.artifacts
              .singleWhere(
                (artifact) =>
                    artifact.title == 'entity_transaction_recovery.md',
              )
              .content,
          contains(recoveryPath),
        );
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test('player discovery order is stable across multiple files', () async {
    final fixtureRoot = Directory.systemTemp.createTempSync(
      'runner_editor_fixture_',
    );
    try {
      writeEntityColliderFixture(
        fixtureRoot.path,
        includeSecondPlayerCatalog: true,
      );
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      final plugin = EntityDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace);
      final document = loaded as EntityDocument;

      final playerIds = document.entries
          .where((entry) => entry.entityType == EntityType.player)
          .map((entry) => entry.id)
          .toList(growable: false);
      expect(playerIds, <String>['player.aria', 'player.eloise']);
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('anchor export preserves expression-backed source shape', () async {
    final fixtureRoot = Directory.systemTemp.createTempSync(
      'runner_editor_fixture_',
    );
    try {
      writeEntityColliderFixture(
        fixtureRoot.path,
        includeReferenceBindings: true,
        useExpressionBackedAnchor: true,
      );
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      final plugin = EntityDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace);
      final document = loaded as EntityDocument;

      final projectile = document.entries.firstWhere(
        (entry) => entry.id == 'projectile.fireBolt',
      );
      final reference = projectile.referenceVisual;
      expect(reference, isNotNull);
      expect(reference!.hasWritableAnchorPoint, isTrue);

      final edited = plugin.applyEdit(
        document,
        buildEntityUpdateCommand(projectile, anchorXPx: 30.0, anchorYPx: 20.0),
      );

      final export = await plugin.exportToRepo(workspace, document: edited);

      expect(export.applied, isTrue);
      final projectileRenderFile = File(
        p.join(
          fixtureRoot.path,
          'packages/runner_core/lib/projectiles/projectile_render_catalog.dart',
        ),
      ).readAsStringSync();
      expect(projectileRenderFile, contains('_fireBoltFrameWidth * 0.625'));
      expect(
        projectileRenderFile,
        contains('_fireBoltFrameHeight * 0.41666667'),
      );
      expect(projectileRenderFile, isNot(contains('Vec2(30.0, 20.0)')));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('source drift returns actionable export error artifact', () async {
    final fixtureRoot = Directory.systemTemp.createTempSync(
      'runner_editor_fixture_',
    );
    try {
      writeEntityColliderFixture(fixtureRoot.path);
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      final plugin = EntityDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace);
      final document = loaded as EntityDocument;

      final enemy = document.entries.firstWhere(
        (entry) => entry.id.startsWith('enemy.'),
      );
      final edited = plugin.applyEdit(
        document,
        buildEntityUpdateCommand(enemy, halfX: enemy.halfX + 1.0),
      );

      final enemyPath = p.join(
        fixtureRoot.path,
        'packages/runner_core/lib/enemies/enemy_catalog.dart',
      );
      final drifted = File(
        enemyPath,
      ).readAsStringSync().replaceFirst('halfX: 12.0', 'halfX: 99.0');
      File(enemyPath).writeAsStringSync(drifted);

      final export = await plugin.exportToRepo(workspace, document: edited);

      expect(export.applied, isFalse);
      expect(export.outcome, ExportOutcome.sourceDrift);
      final errorArtifact = export.artifacts.firstWhere(
        (artifact) => artifact.title == 'entity_export_error.md',
      );
      expect(errorArtifact.content, contains('Source drift detected'));
      expect(
        errorArtifact.content,
        contains('Expected snippet no longer matches current file content'),
      );
      expect(errorArtifact.content, contains('Reload workspace'));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });
}
