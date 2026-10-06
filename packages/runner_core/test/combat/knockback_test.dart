import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/combat/knockback.dart';
import 'package:runner_core/combat/middleware/parry_middleware.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/combat/damage_resistance_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/damage_middleware_system.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/knockback_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

const _effect = KnockbackDef(distance: 112, durationSeconds: .28);

void main() {
  for (final hz in [30, 60, 90]) {
    test('generic shove travels 112 units and expires at $hz Hz', () {
      final world = EcsWorld();
      final target = _player(world);
      _hit(world, target, hz: hz);
      final ti = world.transform.indexOf(target);
      final duration = world.knockback.durationTicks.single;
      final system = KnockbackSystem(tickHz: hz);
      expect(world.transform.velX[ti], 0, reason: 'Damage runs after motion.');
      expect(world.controlLock.isLocked(target, LockFlag.jump, 1), isFalse);
      for (var tick = 1; tick <= duration; tick++) {
        world.transform.velX[ti] = -150;
        system.step(world, currentTick: tick);
        world.transform.posX[ti] += world.transform.velX[ti] / hz;
      }
      expect(world.transform.posX[ti], closeTo(112, 1e-8));
      system.step(world, currentTick: duration + 1);
      expect(world.knockback.has(target), isFalse);
      expect(
        world.controlLock.isLocked(target, LockFlag.move, duration + 1),
        isFalse,
      );
    });
  }

  test('invulnerability, full resistance and canceled hits do not shove', () {
    for (final mode in ['invulnerable', 'resistant', 'canceled', 'lethal']) {
      final world = EcsWorld();
      final target = _player(world);
      if (mode == 'invulnerable') {
        world.invulnerability.ticksLeft[world.invulnerability.indexOf(target)] =
            5;
      }
      if (mode == 'resistant') {
        world.damageResistance.add(
          target,
          const DamageResistanceDef(physicalBp: -10000),
        );
      }
      world.damageQueue.add(
        DamageRequest(
          target: target,
          amount100: mode == 'lethal' ? 1000000 : 100,
          knockback: const KnockbackHit(effect: _effect, directionX: 1),
        ),
      );
      if (mode == 'canceled') world.damageQueue.cancel(0);
      DamageSystem(
        invulnerabilityTicksOnHit: 0,
        rngSeed: 1,
      ).step(world, currentTick: 0);
      expect(world.knockback.has(target), isFalse, reason: mode);
      expect(
        world.controlLock.isLocked(target, LockFlag.move, 1),
        isFalse,
        reason: mode,
      );
    }
  });

  test('actual shield block cancels a melee shove while partial guard preserves it', () {
    for (final ability in ['eloise.shield_block', 'eloise.aegis_riposte']) {
      final world = EcsWorld();
      final target = _player(world);
      world.activeAbility.set(
        target,
        id: ability,
        slot: AbilitySlot.secondary,
        commitTick: 0,
        windupTicks: 0,
        activeTicks: 20,
        recoveryTicks: 0,
        facingDir: Facing.right,
      );
      ActiveAbilityPhaseSystem().step(world, currentTick: 1);
      world.damageQueue.add(
        DamageRequest(
          target: target,
          amount100: 1000,
          sourceKind: DeathSourceKind.meleeHitbox,
          knockback: const KnockbackHit(effect: _effect, directionX: -1),
        ),
      );
      DamageMiddlewareSystem(
        middlewares: [
          ParryMiddleware(
            abilityIds: {ability},
            riposteBonusBp: 0,
            riposteLifetimeTicks: 0,
          ),
        ],
      ).step(world, currentTick: 1);
      DamageSystem(
        invulnerabilityTicksOnHit: 0,
        rngSeed: 1,
      ).step(world, currentTick: 1);
      expect(world.knockback.has(target), ability == 'eloise.aegis_riposte');
    }
  });

  test(
    'source origin and facing resolve a centered effect without its owner',
    () {
      const source = KnockbackSource(
        effect: _effect,
        originX: 50,
        fallbackDirectionX: -1,
      );
      expect(source.resolve(40).directionX, -1);
      expect(source.resolve(60).directionX, 1);
      expect(source.resolve(50).directionX, -1);
    },
  );

  test(
    'last accepted hit replaces direction and entity recycling clears state',
    () {
      final world = EcsWorld();
      final target = _player(world);
      _hit(world, target);
      _hit(world, target, direction: -1);
      expect(world.knockback.signedDistance.single, -112);
      world.destroyEntity(target);
      final recycled = world.createEntity();
      expect(recycled, target);
      expect(world.knockback.has(recycled), isFalse);
      expect(world.controlLock.has(recycled), isFalse);
    },
  );

  test('body cap limits shove velocity and freeze discards pending motion', () {
    final world = EcsWorld();
    final target = _player(world);
    world.body.maxVelX[world.body.indexOf(target)] = 100;
    _hit(world, target);
    const KnockbackSystem(tickHz: 60).step(world, currentTick: 1);
    expect(world.transform.velX[world.transform.indexOf(target)], 100);
    world.arenaSuspension.addEntity(target);
    const KnockbackSystem(tickHz: 60).step(world, currentTick: 2);
    expect(world.knockback.has(target), isFalse);
  });

  test(
    'accepted shove cancels mobility and restores gravity without locking jump',
    () {
      final world = EcsWorld();
      final target = _player(world);
      world.movement.dashTicksLeft[world.movement.indexOf(target)] = 5;
      world.gravityControl.setSuppressForTicks(target, 5);
      world.activeAbility.set(
        target,
        id: 'eloise.dash',
        slot: AbilitySlot.mobility,
        commitTick: 0,
        windupTicks: 0,
        activeTicks: 5,
        recoveryTicks: 0,
        facingDir: Facing.right,
      );
      _hit(world, target);
      expect(world.movement.dashTicksLeft[world.movement.indexOf(target)], 0);
      expect(
        world.gravityControl.suppressGravityTicksLeft[world.gravityControl
            .indexOf(target)],
        0,
      );
      expect(
        world.activeAbility.abilityId[world.activeAbility.indexOf(target)],
        isNull,
      );
      expect(world.controlLock.isLocked(target, LockFlag.jump, 1), isFalse);
    },
  );
}

int _player(EcsWorld world) => EntityFactory(world).createPlayer(
  posX: 0,
  posY: 0,
  velX: 0,
  velY: 0,
  facing: Facing.right,
  grounded: true,
  body: const BodyDef(),
  collider: const ColliderAabbDef(halfX: 8, halfY: 8),
  health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
  mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
  stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
);

void _hit(EcsWorld world, int target, {int hz = 60, int direction = 1}) {
  world.damageQueue.add(
    DamageRequest(
      target: target,
      amount100: 100,
      knockback: KnockbackHit(effect: _effect, directionX: direction),
    ),
  );
  DamageSystem(
    invulnerabilityTicksOnHit: 0,
    rngSeed: 1,
    tickHz: hz,
  ).step(world, currentTick: 0);
}
