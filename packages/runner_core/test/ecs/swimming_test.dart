import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/jump_system.dart';
import 'package:runner_core/ecs/systems/player_movement_system.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/water_immersion_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/terrain/swimming_tuning.dart';
import 'package:runner_core/terrain/water_region.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:test/test.dart';

void main() {
  test(
    'strokes respect lock, cost and interval without spending air jumps',
    () {
      final (world, player) = _world();
      world.collision.add(player);
      world.jumpState.add(player);
      world.mobilityIntent.add(player);
      world.stamina.add(
        player,
        const StaminaDef(
          stamina: 10000,
          staminaMax: 10000,
          regenPerSecond100: 0,
        ),
      );
      final ti = world.transform.indexOf(player);
      final si = world.swimState.indexOf(player);
      final ji = world.jumpState.indexOf(player);
      final ii = world.mobilityIntent.indexOf(player);
      final stamina = world.stamina.indexOf(player);
      final cost = AbilityCatalog.shared
          .resolve('eloise.jump')!
          .defaultCost
          .staminaCost100;
      world.jumpState.airJumpsUsed[ji] = 1;
      WaterImmersionSystem().step(world, [_pool('pool', 0, 200)]);
      final system = JumpSystem(abilities: AbilityCatalog.shared);
      final tuning = MovementTuningDerived.from(
        const MovementTuning(),
        tickHz: 60,
      );
      void stroke(int tick) {
        world.transform.velY[ti] = 0;
        world.mobilityIntent.abilityId[ii] = 'eloise.jump';
        world.mobilityIntent.slot[ii] = AbilitySlot.jump;
        world.mobilityIntent.commitTick[ii] = tick;
        world.mobilityIntent.tick[ii] = tick;
        system.step(world, tuning, currentTick: tick);
      }

      stroke(1);
      expect(world.transform.velY[ti], -SwimmingTuning.strokeSpeed);
      expect(world.stamina.stamina[stamina], 10000 - cost);
      expect(world.jumpState.airJumpsUsed[ji], 1);
      expect(world.swimState.nextStrokeTick[si], 13);
      stroke(2);
      expect(world.transform.velY[ti], 0);
      expect(world.stamina.stamina[stamina], 10000 - cost);
      world.controlLock.addLock(player, LockFlag.jump, 10, 13);
      stroke(13);
      expect(world.transform.velY[ti], 0);
      world.stamina.stamina[stamina] = 0;
      stroke(24);
      expect(world.transform.velY[ti], 0);
      world.stamina.stamina[stamina] = 10000;
      stroke(25);
      expect(world.transform.velY[ti], -SwimmingTuning.strokeSpeed);
      expect(world.jumpState.airJumpsUsed[ji], 1);
    },
  );

  test('surface hysteresis and adjoining pools use quantized centre depth', () {
    final (world, player) = _world();
    final ti = world.transform.indexOf(player);
    final si = world.swimState.indexOf(player);
    final system = WaterImmersionSystem();
    final pools = [_pool('left', 0, 100), _pool('right', 100, 100)];
    void depthAt(double y) {
      world.transform.posY[ti] = y;
      system.step(world, pools);
    }

    depthAt(97); // 7/20 immersed: remain dry.
    expect(world.swimState.isSwimming(player), isFalse);
    depthAt(100);
    expect(world.swimState.immersion1000[si], 500);
    expect(world.swimState.isSwimming(player), isTrue);
    depthAt(97);
    expect(world.swimState.isSwimming(player), isTrue);
    depthAt(94);
    expect(world.swimState.isSwimming(player), isFalse);
    depthAt(110);
    world.transform.posX[ti] = 100;
    system.step(world, pools.reversed);
    expect(world.swimState.immersion1000[si], 1000);
    world.transform.posX[ti] = 201;
    system.step(world, pools);
    expect(
      world.swimState.isSwimming(player),
      isFalse,
      reason: 'Capsule rim overlap outside the centre column is only grazing.',
    );
    world.transform.posX[ti] = 50;
    depthAt(160);
    expect(
      world.swimState.isSwimming(player),
      isFalse,
      reason: 'Leaving below a finite pool must also exit swimming.',
    );
  });

  test('immersion respects disabled bodies and cancels a dash on entry', () {
    final (world, player) = _world();
    final si = world.swimState.indexOf(player);
    final mi = world.movement.indexOf(player);
    world.swimState.nextStrokeTick[si] = 30;
    world.movement.dashTicksLeft[mi] = 10;
    world.gravityControl.setSuppressForTicks(player, 10);
    WaterImmersionSystem().step(world, [_pool('pool', 0, 200)]);
    expect(world.swimState.isSwimming(player), isTrue);
    expect(world.movement.dashTicksLeft[mi], 0);
    expect(world.gravityControl.has(player), isFalse);
    world.body.enabled[world.body.indexOf(player)] = false;
    WaterImmersionSystem().step(world, [_pool('pool', 0, 200)]);
    expect(world.swimState.isSwimming(player), isFalse);
    expect(world.swimState.nextStrokeTick[si], 30);
  });

  test('swimming caps horizontal cruising speed at 80 percent of running', () {
    final (world, player) = _world();
    final inputIndex = world.playerInput.indexOf(player);
    final transformIndex = world.transform.indexOf(player);
    final swimIndex = world.swimState.indexOf(player);
    const maxSpeedX = 200.0;
    final tuning = MovementTuningDerived.from(
      const MovementTuning(maxSpeedX: maxSpeedX, accelerationX: 60000),
      tickHz: 60,
    );
    final system = PlayerMovementSystem();
    world.playerInput.moveAxis[inputIndex] = 1;

    WaterImmersionSystem().step(world, [_pool('pool', 0, 200)]);
    system.step(world, tuning, currentTick: 1);
    expect(
      world.transform.velX[transformIndex],
      closeTo(maxSpeedX * SwimmingTuning.maxSpeedMultiplier, 1e-9),
    );

    world.swimState.setImmersion(swimIndex, 0);
    world.transform.velX[transformIndex] = 0;
    system.step(world, tuning, currentTick: 2);
    expect(world.transform.velX[transformIndex], closeTo(maxSpeedX, 1e-9));
  });

  test(
    'buoyancy caps falling but preserves upward strokes and stun sinking',
    () {
      for (final fixed in [false, true]) {
        final (world, player) = _world();
        final ti = world.transform.indexOf(player);
        world.controlLock.addLock(player, LockFlag.stun, 50, 0);
        WaterImmersionSystem().step(world, [_pool('pool', 0, 200)]);
        final tuning = MovementTuningDerived.from(
          const MovementTuning(),
          tickHz: 60,
        );
        final physics = PhysicsTuning(
          fixedPointPilot: FixedPointPilotTuning(enabled: fixed),
        );
        final gravity = GravitySystem();
        world.transform.velY[ti] = 400;
        gravity.step(world, tuning, physics: physics);
        expect(world.transform.velY[ti], SwimmingTuning.maxSinkSpeed);
        world.transform.velY[ti] = -SwimmingTuning.strokeSpeed;
        gravity.step(world, tuning, physics: physics);
        expect(world.transform.velY[ti], closeTo(-257.6, 0.002));
        world.swimState.setImmersion(world.swimState.indexOf(player), 0);
        world.transform.velY[ti] = 0;
        gravity.step(world, tuning, physics: physics);
        expect(world.transform.velY[ti], 20);
      }
    },
  );

  test('registered swim state follows swap-remove entity lifecycle', () {
    final (world, first) = _world();
    final second = world.createEntity();
    world.swimState.add(second);
    world.swimState.setImmersion(
      world.swimState.indexOf(second),
      1000,
      surfaceY: 102400,
    );
    world.swimState.nextStrokeTick[world.swimState.indexOf(second)] = 44;
    world.destroyEntity(first);
    expect(world.swimState.has(first), isFalse);
    expect(world.swimState.isSwimming(second), isTrue);
    expect(world.swimState.nextStrokeTick[world.swimState.indexOf(second)], 44);
    expect(
      world.swimState.surfaceYTicks[world.swimState.indexOf(second)],
      102400,
    );
  });
}

(EcsWorld, int) _world() {
  final world = EcsWorld(seed: 1);
  final player = world.createEntity();
  world.transform.add(player, posX: 50, posY: 110, velX: 0, velY: 0);
  world.body.add(player, const BodyDef());
  world.movement.add(player, facing: Facing.right);
  world.playerInput.add(player);
  world.swimState.add(player);
  world.worldContactCapsule.add(
    player,
    WorldContactCapsuleDef(radius: 5, verticalHalfSegment: 5),
  );
  return (world, player);
}

WaterRegion _pool(String id, int x, int width) => WaterRegion(
  sourceId: TerrainSourceIdentity(chunkIndex: 0, chunkKey: 'test', shapeId: id),
  worldOriginXTicks: 0,
  data: WaterRegionData(
    id: id,
    x: x,
    y: 100,
    width: width,
    height: 50,
    materialKey: 'water',
  ),
);
