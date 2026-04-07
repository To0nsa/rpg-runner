import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';

String resolveEntitiesWorkspacePath() {
  final cwd = p.normalize(Directory.current.path);
  final base = p.basename(cwd).toLowerCase();
  final parent = p.basename(p.dirname(cwd)).toLowerCase();
  if (base == 'editor' && parent == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}

EditorSessionController buildEntitiesController() {
  return EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(plugins: [EntityDomainPlugin()]),
    initialPluginId: EntityDomainPlugin.pluginId,
    initialWorkspacePath: resolveEntitiesWorkspacePath(),
  );
}

void writeEntityColliderFixture(
  String rootPath, {
  double? broadphaseCellSize,
  bool includeReferenceBindings = false,
  bool useExpressionBackedAnchor = false,
  bool reorderPlayerColliderArgs = false,
  bool reorderProjectileColliderArgs = false,
  bool includeSecondPlayerCatalog = false,
}) {
  final enemyPath = p.join(
    rootPath,
    'packages/runner_core/lib/enemies/enemy_catalog.dart',
  );
  final playerPath = p.join(
    rootPath,
    'packages/runner_core/lib/players/characters/eloise.dart',
  );
  final secondPlayerPath = p.join(
    rootPath,
    'packages/runner_core/lib/players/characters/aria.dart',
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

  String buildPlayerCatalogSource(
    String variableName, {
    required double colliderWidth,
    required double colliderHeight,
    required double colliderOffsetX,
    required double colliderOffsetY,
  }) {
    final colliderArgs = reorderPlayerColliderArgs
        ? '''
  colliderOffsetY: ${colliderOffsetY.toStringAsFixed(1)},
  colliderWidth: ${colliderWidth.toStringAsFixed(1)},
  colliderOffsetX: ${colliderOffsetX.toStringAsFixed(1)},
  colliderHeight: ${colliderHeight.toStringAsFixed(1)},
'''
        : '''
  colliderWidth: ${colliderWidth.toStringAsFixed(1)},
  colliderHeight: ${colliderHeight.toStringAsFixed(1)},
  colliderOffsetX: ${colliderOffsetX.toStringAsFixed(1)},
  colliderOffsetY: ${colliderOffsetY.toStringAsFixed(1)},
''';
    return '''
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

const PlayerCatalog $variableName = PlayerCatalog(
$colliderArgs);
''';
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

  File(playerPath).writeAsStringSync(
    buildPlayerCatalogSource(
      'eloiseCatalog',
      colliderWidth: 22.0,
      colliderHeight: 46.0,
      colliderOffsetX: 0.0,
      colliderOffsetY: 0.0,
    ),
  );
  if (includeSecondPlayerCatalog) {
    File(secondPlayerPath).writeAsStringSync(
      buildPlayerCatalogSource(
        'ariaCatalog',
        colliderWidth: 20.0,
        colliderHeight: 40.0,
        colliderOffsetX: 1.0,
        colliderOffsetY: -2.0,
      ),
    );
  }

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
          ${reorderProjectileColliderArgs ? 'colliderSizeY: 8.0,\n          colliderSizeX: 18.0,' : 'colliderSizeX: 18.0,\n          colliderSizeY: 8.0,'}
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

const int _fireBoltFrameWidth = 48;
const int _fireBoltFrameHeight = 48;

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
  frameWidth: _fireBoltFrameWidth,
  frameHeight: _fireBoltFrameHeight,
  anchorPoint: ${useExpressionBackedAnchor ? 'Vec2(_fireBoltFrameWidth * 0.5, _fireBoltFrameHeight * 0.5),' : (includeReferenceBindings ? 'Vec2(12.0, 24.0),' : 'Vec2(24.0, 24.0),')}
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
