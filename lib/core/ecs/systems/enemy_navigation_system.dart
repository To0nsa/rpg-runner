import 'package:rpg_runner/core/ecs/entity_id.dart';

import '../../enemies/enemy_id.dart';
import '../../navigation/surface_navigator.dart';
import '../../navigation/types/surface_graph.dart';
import '../../navigation/types/surface_id.dart';
import '../../navigation/utils/surface_spatial_index.dart';
import '../../navigation/utils/trajectory_predictor.dart';
import '../world.dart';

/// Builds navigation intents for ground enemies using the surface graph.
class EnemyNavigationSystem {
  EnemyNavigationSystem({
    required this.surfaceNavigator,
    this.trajectoryPredictor,
  });

  final SurfaceNavigator surfaceNavigator;
  final TrajectoryPredictor? trajectoryPredictor;

  SurfaceGraph? _surfaceGraph;
  SurfaceSpatialIndex? _surfaceIndex;
  int _surfaceGraphVersion = 0;

  /// Updates the navigation graph used by ground enemies.
  void setSurfaceGraph({
    required SurfaceGraph graph,
    required SurfaceSpatialIndex spatialIndex,
    required int graphVersion,
  }) {
    _surfaceGraph = graph;
    _surfaceIndex = spatialIndex;
    _surfaceGraphVersion = graphVersion;
  }

  /// Computes navigation intents for all ground enemies.
  void step(
    EcsWorld world, {
    required EntityId player,
  }) {
    if (!world.transform.has(player)) return;

    final playerTi = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTi];
    final playerY = world.transform.posY[playerTi];
    final playerVelX = world.transform.velX[playerTi];
    final playerVelY = world.transform.velY[playerTi];

    final playerGrounded = world.collision.has(player)
        ? world.collision.grounded[world.collision.indexOf(player)]
        : false;

    var playerHalfX = 0.0;
    var playerBottomY = playerY;
    if (world.colliderAabb.has(player)) {
      final ai = world.colliderAabb.indexOf(player);
      playerHalfX = world.colliderAabb.halfX[ai];
      final offsetY = world.colliderAabb.offsetY[ai];
      playerBottomY = playerY + offsetY + world.colliderAabb.halfY[ai];
    }

    final graph = _surfaceGraph;
    final spatialIndex = _surfaceIndex;

    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      if (enemies.enemyId[ei] != EnemyId.groundEnemy) continue;

      final enemy = enemies.denseEntities[ei];
      final ti = world.transform.tryIndexOf(enemy);
      if (ti == null) continue;

      final navIndex = world.surfaceNav.tryIndexOf(enemy);
      if (navIndex == null) continue;

      final intentIndex = world.navIntent.tryIndexOf(enemy);
      if (intentIndex == null) {
        assert(
          false,
          'EnemyNavigationSystem requires NavIntentStore on ground enemies; add it at spawn time.',
        );
        continue;
      }

      var navTargetX = playerX;
      var navTargetBottomY = playerBottomY;
      var navTargetGrounded = playerGrounded;

      if (!playerGrounded &&
          trajectoryPredictor != null &&
          graph != null &&
          spatialIndex != null) {
        final prediction = trajectoryPredictor!.predictLanding(
          startX: playerX,
          startBottomY: playerBottomY,
          velX: playerVelX,
          velY: playerVelY,
          graph: graph,
          spatialIndex: spatialIndex,
          entityHalfWidth: playerHalfX,
        );

        if (prediction != null) {
          navTargetX = prediction.x;
          navTargetBottomY = prediction.bottomY;
          navTargetGrounded = true;
        }
      }

      world.navIntent.navTargetX[intentIndex] = navTargetX;

      SurfaceNavIntent intent;
      var hasSafeSurface = false;
      var safeSurfaceMinX = 0.0;
      var safeSurfaceMaxX = 0.0;

      if (graph == null ||
          spatialIndex == null ||
          !world.colliderAabb.has(enemy)) {
        intent = SurfaceNavIntent(
          desiredX: navTargetX,
          jumpNow: false,
          hasPlan: false,
        );
      } else {
        final ai = world.colliderAabb.indexOf(enemy);
        final enemyHalfX = world.colliderAabb.halfX[ai];
        final enemyHalfY = world.colliderAabb.halfY[ai];
        final offsetY = world.colliderAabb.offsetY[ai];
        final ex = world.transform.posX[ti];
        final enemyBottomY = world.transform.posY[ti] + offsetY + enemyHalfY;
        final grounded =
            world.collision.has(enemy) &&
            world.collision.grounded[world.collision.indexOf(enemy)];

        intent = surfaceNavigator.update(
          navStore: world.surfaceNav,
          navIndex: navIndex,
          graph: graph,
          spatialIndex: spatialIndex,
          graphVersion: _surfaceGraphVersion,
          entityX: ex,
          entityBottomY: enemyBottomY,
          entityHalfWidth: enemyHalfX,
          entityGrounded: grounded,
          targetX: navTargetX,
          targetBottomY: navTargetBottomY,
          targetHalfWidth: playerHalfX,
          targetGrounded: navTargetGrounded,
        );

        if (!intent.hasPlan) {
          final currentSurfaceId = world.surfaceNav.currentSurfaceId[navIndex];
          if (currentSurfaceId != surfaceIdUnknown) {
            final currentIndex = graph.indexOfSurfaceId(currentSurfaceId);
            if (currentIndex != null) {
              final surface = graph.surfaces[currentIndex];
              final minX = surface.xMin + enemyHalfX;
              final maxX = surface.xMax - enemyHalfX;
              if (minX <= maxX) {
                hasSafeSurface = true;
                safeSurfaceMinX = minX;
                safeSurfaceMaxX = maxX;
              }
            }
          }
        }
      }

      final navIntent = world.navIntent;
      navIntent.desiredX[intentIndex] = intent.desiredX;
      navIntent.jumpNow[intentIndex] = intent.jumpNow;
      navIntent.hasPlan[intentIndex] = intent.hasPlan;
      navIntent.commitMoveDirX[intentIndex] = intent.commitMoveDirX;
      navIntent.hasSafeSurface[intentIndex] = hasSafeSurface;
      navIntent.safeSurfaceMinX[intentIndex] = safeSurfaceMinX;
      navIntent.safeSurfaceMaxX[intentIndex] = safeSurfaceMaxX;
    }
  }
}
