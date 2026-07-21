import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_cache.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/ecs/systems/player_movement_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/stats/character_stats_resolver.dart';
import 'package:runner_core/util/fixed_math.dart';
import 'package:test/test.dart';

void main() {
  group('player movement terrain composition', () {
    test('gear and status compose before the continuous slope target', () {
      final harness = _movementHarness(
        movement: const MovementTuning(
          maxSpeedX: 200,
          accelerationX: 60000,
          decelerationX: 400,
          minMoveSpeed: 5,
          maxVelX: 1500,
          maxVelY: 1500,
        ),
        statusMoveSpeedMultiplier: 0.8,
      );
      final inputIndex = harness.world.playerInput.indexOf(harness.player);
      final transformIndex = harness.world.transform.indexOf(harness.player);
      final resolvedIndex = harness.world.resolvedMotion.indexOf(
        harness.player,
      );
      final gearMultiplier = const CharacterStatsResolver()
          .resolveLoadout(_speedLoadout)
          .moveSpeedMultiplier;

      harness.world.playerInput.moveAxis[inputIndex] = 1;
      harness.system.step(harness.world, harness.movement, currentTick: 1);
      expect(
        harness.world.transform.velX[transformIndex],
        closeTo(200 * gearMultiplier * 0.8 * 0.75, 1e-9),
      );
      expect(
        harness
                .world
                .resolvedMotion
                .locomotionReferenceSpeedTicksPerSecond[resolvedIndex] /
            defaultPhysicsSubpixelScale,
        closeTo(200 * gearMultiplier * 0.8, 1e-9),
        reason: 'animation reference speed remains the flat composed speed',
      );

      harness.world.playerInput.moveAxis[inputIndex] = -1;
      harness.system.step(harness.world, harness.movement, currentTick: 2);
      expect(
        harness.world.transform.velX[transformIndex],
        closeTo(-200 * gearMultiplier * 0.8 * 1.15, 1e-9),
      );
    });

    test('zero input preserves deceleration and exact stop behavior', () {
      final harness = _movementHarness(statusMoveSpeedMultiplier: 0.8);
      final inputIndex = harness.world.playerInput.indexOf(harness.player);
      final transformIndex = harness.world.transform.indexOf(harness.player);
      final gearMultiplier = const CharacterStatsResolver()
          .resolveLoadout(_speedLoadout)
          .moveSpeedMultiplier;
      harness.world.playerInput.moveAxis[inputIndex] = 0;
      harness.world.transform.velX[transformIndex] = 100;

      harness.system.step(harness.world, harness.movement, currentTick: 1);
      expect(
        harness.world.transform.velX[transformIndex],
        closeTo(100 - 400 * gearMultiplier * 0.8 / 60, 1e-9),
        reason: 'the slope multiplier must not alter the zero target',
      );

      for (var tick = 2; tick <= 40; tick += 1) {
        harness.system.step(harness.world, harness.movement, currentTick: tick);
      }
      expect(harness.world.transform.velX[transformIndex], 0);
    });

    test('move lock and stun suppress held slope input from rest', () {
      for (final lock in <int>[LockFlag.move, LockFlag.stun]) {
        final harness = _movementHarness();
        final inputIndex = harness.world.playerInput.indexOf(harness.player);
        final transformIndex = harness.world.transform.indexOf(harness.player);
        final resolvedIndex = harness.world.resolvedMotion.indexOf(
          harness.player,
        );
        harness.world.playerInput.moveAxis[inputIndex] = 1;
        harness.world.controlLock.addLock(harness.player, lock, 10, 0);

        harness.system.step(harness.world, harness.movement, currentTick: 1);

        expect(
          harness.world.transform.velX[transformIndex],
          0,
          reason: 'lock=$lock',
        );
        expect(
          harness
              .world
              .resolvedMotion
              .locomotionReferenceSpeedTicksPerSecond[resolvedIndex],
          0,
          reason: 'lock=$lock',
        );
      }
    });
  });
}

const EquippedLoadoutDef _speedLoadout = EquippedLoadoutDef(
  mask: LoadoutSlotMask.all,
  accessoryId: AccessoryId.speedBoots,
);

({
  EcsWorld world,
  int player,
  MovementTuningDerived movement,
  PlayerMovementSystem system,
})
_movementHarness({
  MovementTuning movement = const MovementTuning(
    maxSpeedX: 200,
    accelerationX: 600,
    decelerationX: 400,
    minMoveSpeed: 5,
    maxVelX: 1500,
    maxVelY: 1500,
  ),
  double statusMoveSpeedMultiplier = 1,
}) {
  final derivedMovement = MovementTuningDerived.from(movement, tickHz: 60);
  final archetype = PlayerCatalogDerived.from(
    eloiseCharacter.catalog,
    movement: derivedMovement,
    resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
  ).archetype;
  final world = EcsWorld(seed: 1);
  final player = EntityFactory(world).createPlayer(
    posX: 20,
    posY: 0,
    velX: 0,
    velY: 0,
    facing: archetype.facing,
    grounded: false,
    body: archetype.body,
    collider: archetype.collider,
    health: archetype.health,
    mana: archetype.mana,
    stamina: archetype.stamina,
    equippedLoadout: _speedLoadout,
  );
  world.worldContactCapsule.add(player, archetype.worldContactCapsule);
  world.terrainTraversalProfile.add(player, archetype.terrainTraversalProfile);
  world.terrainContact.add(player);
  world.resolvedMotion.add(player);
  final geometry = _slope60Geometry();
  final support = geometry.edges.singleWhere(
    (edge) => edge.dxTicks == 56 * defaultPhysicsSubpixelScale,
  );
  final cache = TerrainTraversalCache.fromGeometry(geometry);
  world.terrainContact.setSupport(
    player,
    edge: support,
    pointXTicks: support.start.xTicks,
    pointYTicks: support.start.yTicks,
    geometryVersion: geometry.version,
    currentTick: 0,
    slopeAngleUnits: cache[support.id].absoluteSlopeAngleUnits,
  );
  final modifierIndex = world.statModifier.indexOf(player);
  world.statModifier.moveSpeedMul[modifierIndex] = statusMoveSpeedMultiplier;

  return (
    world: world,
    player: player,
    movement: derivedMovement,
    system: PlayerMovementSystem(),
  );
}

TerrainGeometry _slope60Geometry() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/slope-60',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'slope-60',
    ),
    vertices: [(0, 197), (56, 100), (120, 240), (0, 240)],
  ),
], geometryVersion: 1);
