import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/app/pages/home/editor_home_page.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  String resolveWorkspacePath() {
    final cwd = p.normalize(Directory.current.path);
    final base = p.basename(cwd).toLowerCase();
    final parent = p.basename(p.dirname(cwd)).toLowerCase();
    if (base == 'editor' && parent == 'tools') {
      return p.normalize(p.join(cwd, '..', '..'));
    }
    return cwd;
  }

  EditorSessionController buildController() {
    return EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(plugins: [EntityDomainPlugin()]),
      initialPluginId: EntityDomainPlugin.pluginId,
      initialWorkspacePath: resolveWorkspacePath(),
    );
  }

  test(
    'session controller loads parsed collider scene from workspace',
    () async {
      final controller = buildController();

      await controller.loadWorkspace();

      expect(controller.loadError, isNull);
      expect(controller.entityScene, isNotNull);

      final entries = controller.entityScene!.entries;
      final ids = entries.map((entry) => entry.id).join(', ');
      final enemyCount = entries
          .where((entry) => entry.entityType == EntityType.enemy)
          .length;
      final playerCount = entries
          .where((entry) => entry.entityType == EntityType.player)
          .length;
      final projectileCount = entries
          .where((entry) => entry.entityType == EntityType.projectile)
          .length;
      final issueSummary = controller.issues
          .map((issue) => '${issue.code}:${issue.sourcePath}')
          .join(' | ');
      expect(entries, isNotEmpty);
      expect(
        entries.any((entry) => entry.entityType == EntityType.enemy),
        isTrue,
        reason:
            'ids=[$ids], counts(enemy=$enemyCount, player=$playerCount, '
            'projectile=$projectileCount), issues=[$issueSummary]',
      );
      expect(
        entries.any((entry) => entry.entityType == EntityType.player),
        isTrue,
        reason:
            'ids=[$ids], counts(enemy=$enemyCount, player=$playerCount, '
            'projectile=$projectileCount), issues=[$issueSummary]',
      );
      expect(
        entries.any((entry) => entry.entityType == EntityType.projectile),
        isTrue,
      );
      final entriesWithAnimKeys = entries
          .where(
            (entry) => (entry.referenceVisual?.animViewsByKey.length ?? 0) > 1,
          )
          .length;
      expect(
        entriesWithAnimKeys,
        greaterThan(0),
        reason: 'Expected parsed render metadata to include anim-key variants.',
      );
      final playerEloise = entries.firstWhere(
        (entry) => entry.id == 'player.eloise',
      );
      expect(playerEloise.referenceVisual, isNotNull);
      expect(playerEloise.referenceVisual!.renderScale, closeTo(0.75, 0.0001));
      expect(playerEloise.artFacingDirection, EntityArtFacingDirection.right);
      expect(playerEloise.isCaster, isTrue);
      expect(playerEloise.castOriginOffset, closeTo(30.0, 0.0001));
      expect(playerEloise.castOriginOffsetBinding, isNotNull);

      final enemyUnoco = entries.firstWhere(
        (entry) => entry.id == 'enemy.unocoDemon',
      );
      expect(enemyUnoco.artFacingDirection, EntityArtFacingDirection.left);
      expect(enemyUnoco.isCaster, isTrue);
      expect(enemyUnoco.castOriginOffset, closeTo(20.0, 0.0001));
      expect(enemyUnoco.castOriginOffsetBinding, isNotNull);
    },
  );

  test('pending changes contain edited castOriginOffset snippet', () async {
    final controller = buildController();
    await controller.loadWorkspace();

    final player = controller.entityScene!.entries.firstWhere(
      (entry) =>
          entry.id == 'player.eloise' && entry.castOriginOffsetBinding != null,
    );
    final baselineCastOriginOffset = player.castOriginOffset;
    expect(baselineCastOriginOffset, isNotNull);

    controller.applyCommand(
      AuthoringCommand(
        kind: 'update_entry',
        payload: {
          'id': player.id,
          'halfX': player.halfX,
          'halfY': player.halfY,
          'offsetX': player.offsetX,
          'offsetY': player.offsetY,
          'castOriginOffset': baselineCastOriginOffset! + 5.0,
        },
      ),
    );

    final pendingFileDiffs = controller.pendingChanges.fileDiffs;
    expect(pendingFileDiffs, isNotEmpty);
    final combinedDiff = pendingFileDiffs
        .map((fileDiff) => fileDiff.unifiedDiff)
        .join('\n');
    expect(combinedDiff, contains('castOriginOffset'));
    expect(combinedDiff, contains('35.0'));
  });

  test('pending changes contain edited collider snippet', () async {
    final controller = buildController();
    await controller.loadWorkspace();

    final entry = controller.entityScene!.entries.first;
    controller.applyCommand(
      AuthoringCommand(
        kind: 'update_entry',
        payload: {
          'id': entry.id,
          'halfX': entry.halfX + 1.0,
          'halfY': entry.halfY,
          'offsetX': entry.offsetX,
          'offsetY': entry.offsetY,
        },
      ),
    );

    final pending = controller.pendingChanges;
    expect(pending.changedItemIds, contains(entry.id));
    expect(pending.changedItemIds.length, 1);
    expect(pending.fileDiffs, isNotEmpty);
    final combinedDiff = pending.fileDiffs
        .map((fileDiff) => fileDiff.unifiedDiff)
        .join('\n');
    expect(combinedDiff, contains('diff --git a/'));
    expect(combinedDiff, contains('@@ -'));
  });

  test(
    'session controller supports undo and redo for collider edits',
    () async {
      final controller = buildController();
      await controller.loadWorkspace();

      final enemy = controller.entityScene!.entries.firstWhere(
        (entry) => entry.id.startsWith('enemy.'),
      );
      final originalHalfX = enemy.halfX;

      controller.applyCommand(
        AuthoringCommand(
          kind: 'update_entry',
          payload: {
            'id': enemy.id,
            'halfX': originalHalfX + 2.0,
            'halfY': enemy.halfY,
            'offsetX': enemy.offsetX,
            'offsetY': enemy.offsetY,
          },
        ),
      );

      final edited = controller.entityScene!.entries.firstWhere(
        (entry) => entry.id == enemy.id,
      );
      expect(edited.halfX, originalHalfX + 2.0);
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);
      expect(controller.dirtyItemIds, contains(enemy.id));
      expect(controller.pendingChanges.fileDiffs, isNotEmpty);

      controller.undo();

      final undone = controller.entityScene!.entries.firstWhere(
        (entry) => entry.id == enemy.id,
      );
      expect(undone.halfX, originalHalfX);
      expect(controller.canRedo, isTrue);
      expect(controller.dirtyItemIds, isNot(contains(enemy.id)));

      controller.redo();

      final redone = controller.entityScene!.entries.firstWhere(
        (entry) => entry.id == enemy.id,
      );
      expect(redone.halfX, originalHalfX + 2.0);
      expect(controller.dirtyItemIds, contains(enemy.id));
    },
  );

  test('direct write export updates source file content', () async {
    final fixtureRoot = Directory.systemTemp.createTempSync(
      'runner_editor_fixture_',
    );
    try {
      _writeColliderFixture(fixtureRoot.path);
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
      _writeColliderFixture(fixtureRoot.path);
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
        _writeColliderFixture(fixtureRoot.path, broadphaseCellSize: 48.0);
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
        _writeColliderFixture(fixtureRoot.path, includeReferenceBindings: true);
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

  test('source drift returns actionable export error artifact', () async {
    final fixtureRoot = Directory.systemTemp.createTempSync(
      'runner_editor_fixture_',
    );
    try {
      _writeColliderFixture(fixtureRoot.path);
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

  testWidgets('editor page renders collider table after load', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = buildController();

    await tester.pumpWidget(
      MaterialApp(home: EditorHomePage(controller: controller)),
    );

    await tester.pumpAndSettle();

    expect(find.text('No scene loaded.'), findsNothing);
    expect(find.text('Search Entries'), findsOneWidget);
    expect(find.byType(FilterChip), findsWidgets);
    expect(find.text('halfX'), findsWidgets);
  });
}

void _writeColliderFixture(
  String rootPath, {
  double? broadphaseCellSize,
  bool includeReferenceBindings = false,
}) {
  final enemyPath = p.join(
    rootPath,
    'packages/runner_core/lib/enemies/enemy_catalog.dart',
  );
  final playerPath = p.join(
    rootPath,
    'packages/runner_core/lib/players/characters/eloise.dart',
  );
  final projectilePath = p.join(
    rootPath,
    'packages/runner_core/lib/projectiles/projectile_catalog.dart',
  );
  final projectileRenderPath = p.join(
    rootPath,
    'packages/runner_core/lib/projectiles/projectile_render_catalog.dart',
  );
  final projectileRegistryPath = p.join(
    rootPath,
    'lib/game/components/projectiles/projectile_render_registry.dart',
  );
  final spatialGridTuningPath = p.join(
    rootPath,
    'packages/runner_core/lib/tuning/spatial_grid_tuning.dart',
  );

  Directory(p.dirname(enemyPath)).createSync(recursive: true);
  Directory(p.dirname(playerPath)).createSync(recursive: true);
  Directory(p.dirname(projectilePath)).createSync(recursive: true);
  Directory(p.dirname(projectileRenderPath)).createSync(recursive: true);
  if (includeReferenceBindings) {
    Directory(p.dirname(projectileRegistryPath)).createSync(recursive: true);
  }
  if (broadphaseCellSize != null) {
    Directory(p.dirname(spatialGridTuningPath)).createSync(recursive: true);
  }

  File(enemyPath).writeAsStringSync('''
enum EnemyId { unocoDemon }

class ColliderAabbDef {
  const ColliderAabbDef({
    required this.halfX,
    required this.halfY,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });
  final double halfX;
  final double halfY;
  final double offsetX;
  final double offsetY;
}

class EnemyArchetype {
  const EnemyArchetype({required this.collider});
  final ColliderAabbDef collider;
}

class EnemyCatalog {
  const EnemyCatalog();
  EnemyArchetype get(EnemyId id) {
    switch (id) {
      case EnemyId.unocoDemon:
        return const EnemyArchetype(
          collider: ColliderAabbDef(
            halfX: 12.0,
            halfY: 14.0,
            offsetX: 0.0,
            offsetY: 0.0,
          ),
        );
    }
  }
}
''');

  File(playerPath).writeAsStringSync('''
class PlayerCatalog {
  const PlayerCatalog({
    required this.colliderWidth,
    required this.colliderHeight,
    required this.colliderOffsetX,
    required this.colliderOffsetY,
  });

  final double colliderWidth;
  final double colliderHeight;
  final double colliderOffsetX;
  final double colliderOffsetY;
}

const PlayerCatalog eloiseCatalog = PlayerCatalog(
  colliderWidth: 22.0,
  colliderHeight: 46.0,
  colliderOffsetX: 0.0,
  colliderOffsetY: 0.0,
);
''');

  File(projectilePath).writeAsStringSync('''
enum ProjectileId { fireBolt }

class ProjectileItemDef {
  const ProjectileItemDef({
    required this.colliderSizeX,
    required this.colliderSizeY,
  });

  final double colliderSizeX;
  final double colliderSizeY;
}

class ProjectileCatalog {
  const ProjectileCatalog();
  ProjectileItemDef get(ProjectileId id) {
    switch (id) {
      case ProjectileId.fireBolt:
        return const ProjectileItemDef(
          colliderSizeX: 18.0,
          colliderSizeY: 8.0,
        );
    }
  }
}
''');

  File(projectileRenderPath).writeAsStringSync('''
enum AnimKey { spawn, idle, hit }

class RenderAnimSetDefinition {
  const RenderAnimSetDefinition({
    required this.frameWidth,
    required this.frameHeight,
    required this.anchorPoint,
    required this.sourcesByKey,
    this.rowByKey = const <AnimKey, int>{},
    this.frameStartByKey = const <AnimKey, int>{},
    this.gridColumnsByKey = const <AnimKey, int>{},
    required this.frameCountsByKey,
    required this.stepTimeSecondsByKey,
  });

  final int frameWidth;
  final int frameHeight;
  final Vec2 anchorPoint;
  final Map<AnimKey, String> sourcesByKey;
  final Map<AnimKey, int> rowByKey;
  final Map<AnimKey, int> frameStartByKey;
  final Map<AnimKey, int> gridColumnsByKey;
  final Map<AnimKey, int> frameCountsByKey;
  final Map<AnimKey, double> stepTimeSecondsByKey;
}

class Vec2 {
  const Vec2(this.x, this.y);
  final double x;
  final double y;
}

const Map<AnimKey, String> _fireBoltSourcesByKey = <AnimKey, String>{
  AnimKey.spawn: 'entities/spells/fire/bolt/spriteSheet.png',
  AnimKey.idle: 'entities/spells/fire/bolt/spriteSheet.png',
  AnimKey.hit: 'entities/spells/fire/bolt/hit.png',
};

const Map<AnimKey, int> _fireBoltRowByKey = <AnimKey, int>{
  AnimKey.spawn: 0,
  AnimKey.idle: 1,
  AnimKey.hit: 0,
};

const Map<AnimKey, int> _fireBoltFrameStartByKey = <AnimKey, int>{
  AnimKey.spawn: 0,
  AnimKey.idle: 2,
  AnimKey.hit: 0,
};

const Map<AnimKey, int> _fireBoltGridColumnsByKey = <AnimKey, int>{
  AnimKey.spawn: 5,
  AnimKey.idle: 5,
  AnimKey.hit: 4,
};

const Map<AnimKey, int> _fireBoltFrameCountsByKey = <AnimKey, int>{
  AnimKey.spawn: 5,
  AnimKey.idle: 8,
  AnimKey.hit: 6,
};

const RenderAnimSetDefinition _fireBoltRenderAnim = RenderAnimSetDefinition(
  frameWidth: 48,
  frameHeight: 48,
  anchorPoint: ${includeReferenceBindings ? 'Vec2(12.0, 24.0),' : 'Vec2(24.0, 24.0),'}
  sourcesByKey: _fireBoltSourcesByKey,
  rowByKey: _fireBoltRowByKey,
  frameStartByKey: _fireBoltFrameStartByKey,
  gridColumnsByKey: _fireBoltGridColumnsByKey,
  frameCountsByKey: _fireBoltFrameCountsByKey,
  stepTimeSecondsByKey: <AnimKey, double>{
    AnimKey.spawn: 0.06,
    AnimKey.idle: 0.06,
    AnimKey.hit: 0.06,
  },
);

class ProjectileRenderCatalog {
  const ProjectileRenderCatalog();

  RenderAnimSetDefinition get(ProjectileId id) {
    switch (id) {
      case ProjectileId.fireBolt:
        return _fireBoltRenderAnim;
    }
  }
}
''');

  if (includeReferenceBindings) {
    File(projectileRegistryPath).writeAsStringSync('''
enum ProjectileId { fireBolt }

class Vector2 {
  const Vector2.all(this.value);
  final double value;
}

class ProjectileRenderEntry {
  const ProjectileRenderEntry({required this.renderScale});
  final Vector2 renderScale;
}

const Map<ProjectileId, ProjectileRenderEntry> projectileRenderEntries = {
  ProjectileId.fireBolt: ProjectileRenderEntry(
    renderScale: Vector2.all(1.0),
  ),
};
''');
  }

  if (broadphaseCellSize != null) {
    File(spatialGridTuningPath).writeAsStringSync('''
class SpatialGridTuning {
  const SpatialGridTuning({
    this.broadphaseCellSize = ${broadphaseCellSize.toStringAsFixed(1)},
  });

  final double broadphaseCellSize;
}
''');
  }
}
