import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_def.dart' show WeaponType;
import 'package:rpg_runner/core/combat/damage.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/systems/damage_system.dart';
import 'package:rpg_runner/core/ecs/systems/reactive_proc_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/weapons/reactive_proc.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_category.dart';
import 'package:rpg_runner/core/weapons/weapon_def.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

void main() {
  group('ReactiveProcSystem', () {
    test('queues onDamaged proc on self after applied damage', () {
      final world = EcsWorld();
      final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 11);
      final reactive = ReactiveProcSystem(
        weapons: const _ReactiveShieldCatalog(
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onDamaged,
              statusProfileId: StatusProfileId.speedBoost,
              target: ReactiveProcTarget.self,
              chanceBp: 10000,
            ),
          ],
        ),
        rngSeed: 11,
      );

      final source = _spawnEntity(world, hp: 5000, hpMax: 5000);
      final target = _spawnEntity(world, hp: 10000, hpMax: 10000);
      _equipReactiveOffhand(world, target);

      world.damageQueue.add(
        DamageRequest(target: target, amount100: 1000, source: source),
      );

      final queued = <StatusRequest>[];
      damage.step(world, currentTick: 1);
      reactive.step(world, currentTick: 1, queueStatus: queued.add);

      expect(queued, hasLength(1));
      expect(queued.single.target, equals(target));
      expect(queued.single.profileId, equals(StatusProfileId.speedBoost));
    });

    test('queues onDamaged proc on attacker when source exists', () {
      final world = EcsWorld();
      final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 12);
      final reactive = ReactiveProcSystem(
        weapons: const _ReactiveShieldCatalog(
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onDamaged,
              statusProfileId: StatusProfileId.silenceOnHit,
              target: ReactiveProcTarget.attacker,
              chanceBp: 10000,
            ),
          ],
        ),
        rngSeed: 12,
      );

      final source = _spawnEntity(world, hp: 5000, hpMax: 5000);
      final target = _spawnEntity(world, hp: 10000, hpMax: 10000);
      _equipReactiveOffhand(world, target);

      world.damageQueue.add(
        DamageRequest(target: target, amount100: 1000, source: source),
      );

      final queued = <StatusRequest>[];
      damage.step(world, currentTick: 1);
      reactive.step(world, currentTick: 1, queueStatus: queued.add);

      expect(queued, hasLength(1));
      expect(queued.single.target, equals(source));
      expect(queued.single.profileId, equals(StatusProfileId.silenceOnHit));
    });

    test('onLowHealth triggers only on threshold crossing', () {
      final world = EcsWorld();
      final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 13);
      final reactive = ReactiveProcSystem(
        weapons: const _ReactiveShieldCatalog(
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onLowHealth,
              statusProfileId: StatusProfileId.speedBoost,
              target: ReactiveProcTarget.self,
              chanceBp: 10000,
              lowHealthThresholdBp: 5000,
            ),
          ],
        ),
        rngSeed: 13,
      );

      final target = _spawnEntity(world, hp: 6000, hpMax: 10000);
      _equipReactiveOffhand(world, target);

      final queued = <StatusRequest>[];

      world.damageQueue.add(DamageRequest(target: target, amount100: 1000));
      damage.step(world, currentTick: 10);
      reactive.step(world, currentTick: 10, queueStatus: queued.add);

      world.damageQueue.add(DamageRequest(target: target, amount100: 500));
      damage.step(world, currentTick: 11);
      reactive.step(world, currentTick: 11, queueStatus: queued.add);

      expect(queued, hasLength(1));
      expect(queued.single.target, equals(target));
      expect(queued.single.profileId, equals(StatusProfileId.speedBoost));
    });

    test('onLowHealth respects internal cooldown ticks', () {
      final world = EcsWorld();
      final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 14);
      final reactive = ReactiveProcSystem(
        weapons: const _ReactiveShieldCatalog(
          reactiveProcs: <ReactiveProc>[
            ReactiveProc(
              hook: ReactiveProcHook.onLowHealth,
              statusProfileId: StatusProfileId.speedBoost,
              target: ReactiveProcTarget.self,
              chanceBp: 10000,
              lowHealthThresholdBp: 7000,
              internalCooldownTicks: 60,
            ),
          ],
        ),
        rngSeed: 14,
      );

      final target = _spawnEntity(world, hp: 9000, hpMax: 10000);
      _equipReactiveOffhand(world, target);
      final healthIndex = world.health.indexOf(target);

      final queued = <StatusRequest>[];

      world.damageQueue.add(DamageRequest(target: target, amount100: 2500));
      damage.step(world, currentTick: 10);
      reactive.step(world, currentTick: 10, queueStatus: queued.add);

      world.health.hp[healthIndex] = 9000;
      world.damageQueue.add(DamageRequest(target: target, amount100: 2500));
      damage.step(world, currentTick: 30);
      reactive.step(world, currentTick: 30, queueStatus: queued.add);

      world.health.hp[healthIndex] = 9000;
      world.damageQueue.add(DamageRequest(target: target, amount100: 2500));
      damage.step(world, currentTick: 80);
      reactive.step(world, currentTick: 80, queueStatus: queued.add);

      expect(queued, hasLength(2));
      expect(queued[0].target, equals(target));
      expect(queued[1].target, equals(target));
      expect(queued[0].profileId, equals(StatusProfileId.speedBoost));
      expect(queued[1].profileId, equals(StatusProfileId.speedBoost));
    });
  });
}

int _spawnEntity(EcsWorld world, {required int hp, required int hpMax}) {
  final entity = world.createEntity();
  world.health.add(
    entity,
    HealthDef(hp: hp, hpMax: hpMax, regenPerSecond100: 0),
  );
  return entity;
}

void _equipReactiveOffhand(EcsWorld world, int entity) {
  world.equippedLoadout.add(
    entity,
    const EquippedLoadoutDef(
      mask: LoadoutSlotMask.offHand,
      offhandWeaponId: WeaponId.roadguard,
    ),
  );
}

class _ReactiveShieldCatalog extends WeaponCatalog {
  const _ReactiveShieldCatalog({required this.reactiveProcs});

  final List<ReactiveProc> reactiveProcs;

  @override
  WeaponDef get(WeaponId id) {
    if (id == WeaponId.roadguard) {
      return WeaponDef(
        id: WeaponId.roadguard,
        category: WeaponCategory.offHand,
        weaponType: WeaponType.shield,
        reactiveProcs: reactiveProcs,
      );
    }
    return const WeaponDef(
      id: WeaponId.plainsteel,
      category: WeaponCategory.primary,
      weaponType: WeaponType.oneHandedSword,
    );
  }
}
