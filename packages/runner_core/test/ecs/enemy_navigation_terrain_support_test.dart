import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/enemies/surface_nav_state_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/enemy_navigation_system.dart';
import 'package:runner_core/ecs/systems/anim/anim_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/surface_navigator.dart';
import 'package:runner_core/navigation/surface_pathfinder.dart';
import 'package:runner_core/navigation/types/surface_graph.dart';
import 'package:runner_core/navigation/utils/surface_spatial_index.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

void main() {
  test(
    'AI consumes prepared support while animation consumes final support',
    () {
      final world = EcsWorld(seed: 3);
      final player = world.createEntity();
      world.transform.add(player, posX: 200, posY: 100, velX: 0, velY: 0);
      world.colliderAabb.add(
        player,
        const ColliderAabbDef(halfX: 10, halfY: 20),
      );
      world.collision.add(player);
      world.terrainContact.add(player);
      world.terrainContact.grounded[world.terrainContact.indexOf(player)] =
          true;

      final enemy = EntityFactory(world).createEnemy(
        enemyId: EnemyId.grojib,
        posX: 100,
        posY: 100,
        velX: 0,
        velY: 0,
        facing: Facing.right,
        body: const BodyDef(),
        collider: const ColliderAabbDef(halfX: 10, halfY: 20),
        health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond100: 0),
        mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
        stamina: const StaminaDef(
          stamina: 0,
          staminaMax: 0,
          regenPerSecond100: 0,
        ),
      );
      world.terrainContact.add(enemy);
      world.terrainContact.grounded[world.terrainContact.indexOf(enemy)] = true;

      final probe = _SurfaceNavigatorProbe();
      final graph = SurfaceGraph(
        surfaces: const [],
        edgeOffsets: const [0],
        edges: const [],
        indexById: const {},
      );
      final spatialIndex = SurfaceSpatialIndex(
        index: GridIndex2D(cellSize: 32),
      );
      spatialIndex.rebuild(graph.surfaces);
      final system = EnemyNavigationSystem(surfaceNavigator: probe);
      system.setSurfaceGraph(
        graph: graph,
        spatialIndex: spatialIndex,
        graphVersion: 1,
      );

      system.step(world, player: player, currentTick: 1);

      expect(probe.entityGrounded, isTrue);
      expect(probe.targetGrounded, isTrue);

      // This represents the exactly-once motion phase ending airborne. The AI
      // observation above must remain prior-tick support, while downstream
      // animation must read this final support state instead of a cached flag.
      world.terrainContact.clearSupport(enemy);
      world.transform.velY[world.transform.indexOf(enemy)] = 120;
      world.spawnState.removeEntity(enemy);
      final movement = MovementTuningDerived.from(
        eloiseCharacter.tuning.movement,
        tickHz: 60,
      );
      final animation = AnimSystem(
        tickHz: 60,
        enemyCatalog: const EnemyCatalog(),
        playerMovement: movement,
        playerAnimTuning: AnimTuningDerived.from(
          eloiseCharacter.tuning.anim,
          tickHz: 60,
        ),
      );
      animation.step(world, player: player, currentTick: 1);

      expect(probe.entityGrounded, isTrue);
      expect(
        world.animState.anim[world.animState.indexOf(enemy)],
        AnimKey.fall,
      );
    },
  );
}

final class _SurfaceNavigatorProbe extends SurfaceNavigator {
  _SurfaceNavigatorProbe()
    : super(pathfinder: SurfacePathfinder(maxExpandedNodes: 1, runSpeedX: 1));

  bool? entityGrounded;
  bool? targetGrounded;

  @override
  SurfaceNavIntent update({
    required SurfaceNavStateStore navStore,
    required int navIndex,
    required SurfaceGraph graph,
    required SurfaceSpatialIndex spatialIndex,
    required int graphVersion,
    required double entityX,
    required double entityBottomY,
    required double entityHalfWidth,
    required bool entityGrounded,
    double entitySupportFraction = 1,
    required double targetX,
    required double targetBottomY,
    required double targetHalfWidth,
    required bool targetGrounded,
    double targetSupportFraction = 1,
  }) {
    this.entityGrounded = entityGrounded;
    this.targetGrounded = targetGrounded;
    return SurfaceNavIntent(desiredX: targetX, jumpNow: false, hasPlan: false);
  }
}
