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
    int chaseTargetDelayTicks = 0,
  }) : _chaseTargetDelayTicks = chaseTargetDelayTicks < 0
           ? 0
           : chaseTargetDelayTicks {
    final len = _chaseTargetDelayTicks <= 0 ? 1 : _chaseTargetDelayTicks + 1;
    _targetHistoryX = List<double>.filled(len, 0.0);
    _targetHistoryBottomY = List<double>.filled(len, 0.0);
    _targetHistoryGrounded = List<bool>.filled(len, true);
  }

  final SurfaceNavigator surfaceNavigator;
  final TrajectoryPredictor? trajectoryPredictor;

  final int _chaseTargetDelayTicks;

  SurfaceGraph? _surfaceGraph;
  SurfaceSpatialIndex? _surfaceIndex;
  int _surfaceGraphVersion = 0;

  late final List<double> _targetHistoryX;
  late final List<double> _targetHistoryBottomY;
  late final List<bool> _targetHistoryGrounded;
  int _targetHistoryCursor = 0;
  bool _targetHistoryPrimed = false;

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
    required int currentTick,
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

    var rawTargetX = playerX;
    var rawTargetBottomY = playerBottomY;
    var rawTargetGrounded = playerGrounded;

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
        rawTargetX = prediction.x;
        rawTargetBottomY = prediction.bottomY;
        rawTargetGrounded = true;
      }
    }

    double navTargetX;
    double navTargetBottomY;
    bool navTargetGrounded;

    if (_chaseTargetDelayTicks <= 0) {
      navTargetX = rawTargetX;
      navTargetBottomY = rawTargetBottomY;
      navTargetGrounded = rawTargetGrounded;
    } else {
      final len = _targetHistoryX.length;
      if (!_targetHistoryPrimed) {
        for (var i = 0; i < len; i += 1) {
          _targetHistoryX[i] = rawTargetX;
          _targetHistoryBottomY[i] = rawTargetBottomY;
          _targetHistoryGrounded[i] = rawTargetGrounded;
        }
        _targetHistoryCursor = 0;
        _targetHistoryPrimed = true;
      } else {
        _targetHistoryCursor += 1;
        if (_targetHistoryCursor >= len) _targetHistoryCursor = 0;
        _targetHistoryX[_targetHistoryCursor] = rawTargetX;
        _targetHistoryBottomY[_targetHistoryCursor] = rawTargetBottomY;
        _targetHistoryGrounded[_targetHistoryCursor] = rawTargetGrounded;
      }

      var delayedIndex = _targetHistoryCursor - _chaseTargetDelayTicks;
      if (delayedIndex < 0) delayedIndex += len;
      navTargetX = _targetHistoryX[delayedIndex];
      navTargetBottomY = _targetHistoryBottomY[delayedIndex];
      navTargetGrounded = _targetHistoryGrounded[delayedIndex];
    }

    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      if (enemies.enemyId[ei] != EnemyId.grojib) continue;

      final enemy = enemies.denseEntities[ei];
      if (world.deathState.has(enemy)) continue;
      final ti = world.transform.tryIndexOf(enemy);
      if (ti == null) continue;

      if (world.controlLock.isStunned(enemy, currentTick)) continue;

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

      world.navIntent.navTargetX[intentIndex] = navTargetX;

      SurfaceNavIntent intent;
      var hasSafeSurface = false;
      var safeSurfaceMinX = 0.0;
      var safeSurfaceMaxX = 0.0;
      final ex = world.transform.posX[ti];
      final enemyGrounded =
          world.collision.has(enemy) &&
          world.collision.grounded[world.collision.indexOf(enemy)];

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
        final enemyBottomY = world.transform.posY[ti] + offsetY + enemyHalfY;

        intent = surfaceNavigator.update(
          navStore: world.surfaceNav,
          navIndex: navIndex,
          graph: graph,
          spatialIndex: spatialIndex,
          graphVersion: _surfaceGraphVersion,
          entityX: ex,
          entityBottomY: enemyBottomY,
          entityHalfWidth: enemyHalfX,
          entityGrounded: enemyGrounded,
          targetX: navTargetX,
          targetBottomY: navTargetBottomY,
          targetHalfWidth: playerHalfX,
          targetGrounded: navTargetGrounded,
        );

        if (!intent.hasPlan) {
          final currentSurfaceId = world.surfaceNav.currentSurfaceId[navIndex];
          final lastGroundSurfaceId =
              world.surfaceNav.lastGroundSurfaceId[navIndex];
          final safeSurfaceId = currentSurfaceId != surfaceIdUnknown
              ? currentSurfaceId
              : lastGroundSurfaceId;
          if (safeSurfaceId != surfaceIdUnknown) {
            final currentIndex = graph.indexOfSurfaceId(safeSurfaceId);
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
