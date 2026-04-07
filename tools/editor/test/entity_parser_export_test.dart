import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

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
        AuthoringCommand(
          kind: 'update_entry',
          payload: {
            'id': enemy.id,
            'halfX': enemy.halfX + 1.0,
            'halfY': enemy.halfY,
            'offsetX': enemy.offsetX,
            'offsetY': enemy.offsetY,
          },
        ),
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
          AuthoringCommand(
            kind: 'update_entry',
            payload: {
              'id': projectile.id,
              'halfX': projectile.halfX,
              'halfY': projectile.halfY,
              'offsetX': projectile.offsetX,
              'offsetY': projectile.offsetY,
              'anchorXPx': 30.0,
              'anchorYPx': 20.0,
              'renderScale': 1.25,
            },
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
        AuthoringCommand(
          kind: 'update_entry',
          payload: {
            'id': enemy.id,
            'halfX': -1.0,
            'halfY': enemy.halfY,
            'offsetX': enemy.offsetX,
            'offsetY': enemy.offsetY,
          },
        ),
      );

      final enemyPath = p.join(
        fixtureRoot.path,
        'packages/runner_core/lib/enemies/enemy_catalog.dart',
      );
      final export = await plugin.exportToRepo(workspace, document: edited);

      expect(export.applied, isFalse);
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
        AuthoringCommand(
          kind: 'update_entry',
          payload: {
            'id': enemy.id,
            'halfX': enemy.halfX + 1.0,
            'halfY': enemy.halfY,
            'offsetX': enemy.offsetX,
            'offsetY': enemy.offsetY,
          },
        ),
      );
      final edited = plugin.applyEdit(
        editedEnemy,
        AuthoringCommand(
          kind: 'update_entry',
          payload: {
            'id': projectile.id,
            'halfX': projectile.halfX,
            'halfY': projectile.halfY,
            'offsetX': projectile.offsetX,
            'offsetY': projectile.offsetY,
            'renderScale': 1.25,
          },
        ),
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

  test('export handles reordered player and projectile collider args', () async {
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
        AuthoringCommand(
          kind: 'update_entry',
          payload: {
            'id': player.id,
            'halfX': player.halfX + 1.0,
            'halfY': player.halfY,
            'offsetX': player.offsetX,
            'offsetY': player.offsetY,
          },
        ),
      );
      final edited = plugin.applyEdit(
        editedPlayer,
        AuthoringCommand(
          kind: 'update_entry',
          payload: {
            'id': projectile.id,
            'halfX': projectile.halfX,
            'halfY': projectile.halfY + 1.0,
            'offsetX': projectile.offsetX,
            'offsetY': projectile.offsetY,
          },
        ),
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
          'colliderWidth: 24.0,\n  colliderHeight: 46.0,\n  colliderOffsetX: 0.0,\n  colliderOffsetY: 0.0',
        ),
      );
      expect(
        projectileFile,
        contains('colliderSizeX: 18.0,\n          colliderSizeY: 10.0'),
      );
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

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
        AuthoringCommand(
          kind: 'update_entry',
          payload: {
            'id': projectile.id,
            'halfX': projectile.halfX,
            'halfY': projectile.halfY,
            'offsetX': projectile.offsetX,
            'offsetY': projectile.offsetY,
            'anchorXPx': 30.0,
            'anchorYPx': 20.0,
          },
        ),
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
      expect(projectileRenderFile, contains('_fireBoltFrameHeight * 0.4167'));
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
        AuthoringCommand(
          kind: 'update_entry',
          payload: {
            'id': enemy.id,
            'halfX': enemy.halfX + 1.0,
            'halfY': enemy.halfY,
            'offsetX': enemy.offsetX,
            'offsetY': enemy.offsetY,
          },
        ),
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
