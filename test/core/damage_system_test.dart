import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/accessories/accessory_def.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart'
    show AbilitySlot, CooldownGroup, WeaponType;
import 'package:rpg_runner/core/combat/damage.dart';
import 'package:rpg_runner/core/combat/damage_type.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/damage_resistance_store.dart';
import 'package:rpg_runner/core/ecs/stores/status/weaken_store.dart';
import 'package:rpg_runner/core/ecs/systems/damage_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/events/game_event.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_def.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/spellBook/spell_book_catalog.dart';
import 'package:rpg_runner/core/spellBook/spell_book_def.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/core/stats/character_stats_resolver.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_category.dart';
import 'package:rpg_runner/core/weapons/weapon_def.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';
import 'package:rpg_runner/core/weapons/weapon_proc.dart';
import 'package:rpg_runner/core/stats/gear_stat_bonuses.dart';

void main() {
  test('DamageSystem clamps health and ignores missing targets', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

    final e = world.createEntity();
    world.health.add(
      e,
      const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
    );

    world.damageQueue.add(const DamageRequest(target: 999, amount100: 500));
    world.damageQueue.add(DamageRequest(target: e, amount100: 300));
    world.damageQueue.add(DamageRequest(target: e, amount100: 10000));

    damage.step(world, currentTick: 1);

    final hi = world.health.indexOf(e);
    expect(world.health.hp[hi], equals(0));
  });

  test('DamageSystem reports callbacks only for applied direct hits', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
    );

    final callbackTargets = <int>[];
    final callbackAmounts = <int>[];
    final callbackKinds = <DeathSourceKind>[];

    world.damageQueue.add(const DamageRequest(target: 999, amount100: 500));
    world.damageQueue.add(
      const DamageRequest(
        target: 999,
        amount100: 400,
        sourceKind: DeathSourceKind.statusEffect,
      ),
    );
    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 300,
        sourceKind: DeathSourceKind.projectile,
      ),
    );

    damage.step(
      world,
      currentTick: 1,
      onDamageApplied:
          ({
            required target,
            required appliedAmount100,
            required sourceKind,
            required damageType,
          }) {
            callbackTargets.add(target);
            callbackAmounts.add(appliedAmount100);
            callbackKinds.add(sourceKind);
          },
    );

    expect(callbackTargets, equals(<int>[target]));
    expect(callbackAmounts, equals(<int>[300]));
    expect(
      callbackKinds,
      equals(<DeathSourceKind>[DeathSourceKind.projectile]),
    );
  });

  test('DamageSystem applies global defense from equipped loadout', () {
    final world = EcsWorld();
    final resolver = CharacterStatsResolver(
      weapons: const _DefenseWeaponCatalog(),
      projectiles: const _FlatProjectileCatalog(),
      spellBooks: const _FlatSpellBookCatalog(),
      accessories: const _FlatAccessoryCatalog(),
    );
    final damage = DamageSystem(
      invulnerabilityTicksOnHit: 0,
      rngSeed: 1,
      statsResolver: resolver,
    );

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.equippedLoadout.add(
      target,
      const EquippedLoadoutDef(
        mask: LoadoutSlotMask.mainHand,
        mainWeaponId: WeaponId.plainsteel,
      ),
    );

    world.damageQueue.add(DamageRequest(target: target, amount100: 1000));

    damage.step(world, currentTick: 1);

    expect(world.health.hp[world.health.indexOf(target)], equals(9200));
  });

  test('DamageSystem combines store typed mod with gear typed resistance', () {
    final world = EcsWorld();
    final resolver = CharacterStatsResolver(
      weapons: const _FlatWeaponCatalog(),
      projectiles: const _FlatProjectileCatalog(),
      spellBooks: const _FlatSpellBookCatalog(),
      accessories: const _TypedResistanceAccessoryCatalog(),
    );
    final damage = DamageSystem(
      invulnerabilityTicksOnHit: 0,
      rngSeed: 1,
      statsResolver: resolver,
    );

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.equippedLoadout.add(
      target,
      const EquippedLoadoutDef(
        mask: LoadoutSlotMask.mainHand,
        accessoryId: AccessoryId.speedBoots,
      ),
    );
    world.damageResistance.add(target, const DamageResistanceDef(fireBp: 2000));

    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 1000,
        damageType: DamageType.fire,
      ),
    );

    damage.step(world, currentTick: 1);

    // Base fire vulnerability (+20%) plus gear fire resistance (+30%) = net -10%.
    expect(world.health.hp[world.health.indexOf(target)], equals(9100));
  });

  test('DamageSystem applies deterministic critical damage', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );

    world.damageQueue.add(
      DamageRequest(target: target, amount100: 1000, critChanceBp: 10000),
    );

    damage.step(world, currentTick: 1);

    // 1000 with fixed +50% crit bonus => 1500 applied.
    expect(world.health.hp[world.health.indexOf(target)], equals(3500));
  });

  test('DamageSystem applies weaken from source before hit resolution', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

    final source = world.createEntity();
    world.weaken.add(source, const WeakenDef(ticksLeft: 60, magnitude: 3500));

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );

    world.damageQueue.add(
      DamageRequest(target: target, amount100: 1000, source: source),
    );

    damage.step(world, currentTick: 1);

    // Weaken reduces outgoing damage by 35% -> 1000 becomes 650.
    expect(world.health.hp[world.health.indexOf(target)], equals(9350));
  });

  test('DamageSystem interrupts charged shot on hit', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.activeAbility.add(target);
    world.projectileIntent.add(target);
    world.abilityInputBuffer.add(target);

    world.activeAbility.set(
      target,
      id: 'eloise.overcharge_shot',
      slot: AbilitySlot.projectile,
      commitTick: 10,
      windupTicks: 24,
      activeTicks: 2,
      recoveryTicks: 10,
      facingDir: Facing.right,
    );
    final intentIndex = world.projectileIntent.indexOf(target);
    world.projectileIntent.tick[intentIndex] = 34;
    world.projectileIntent.commitTick[intentIndex] = 10;
    world.abilityInputBuffer.setBuffer(
      target,
      slot: AbilitySlot.projectile,
      abilityId: 'eloise.overcharge_shot',
      aimDirX: 1.0,
      aimDirY: 0.0,
      facing: Facing.right,
      commitTick: 10,
      expiresTick: 16,
    );

    world.damageQueue.add(DamageRequest(target: target, amount100: 500));
    damage.step(world, currentTick: 11);

    expect(world.health.hp[world.health.indexOf(target)], equals(9500));
    expect(world.activeAbility.hasActiveAbility(target), isFalse);
    expect(world.projectileIntent.tick[intentIndex], equals(-1));
    expect(world.projectileIntent.commitTick[intentIndex], equals(-1));
    expect(
      world.abilityInputBuffer.hasBuffered[world.abilityInputBuffer.indexOf(
        target,
      )],
      isFalse,
    );
  });

  test(
    'DamageSystem starts deferred cooldown when damage interrupts ability',
    () {
      final world = EcsWorld();
      final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

      final target = world.createEntity();
      world.health.add(
        target,
        const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      );
      world.cooldown.add(target);
      world.activeAbility.add(target);

      world.activeAbility.set(
        target,
        id: 'eloise.overcharge_shot',
        slot: AbilitySlot.projectile,
        commitTick: 10,
        windupTicks: 24,
        activeTicks: 2,
        recoveryTicks: 10,
        facingDir: Facing.right,
        cooldownGroupId: CooldownGroup.projectile,
        cooldownTicks: 17,
        cooldownStarted: false,
      );

      world.damageQueue.add(DamageRequest(target: target, amount100: 500));
      damage.step(world, currentTick: 11);

      expect(world.activeAbility.hasActiveAbility(target), isFalse);
      expect(
        world.cooldown.getTicksLeft(target, CooldownGroup.projectile),
        equals(17),
      );
    },
  );

  test('DamageSystem keeps non-charged projectile abilities active on hit', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.activeAbility.add(target);
    world.projectileIntent.add(target);
    world.abilityInputBuffer.add(target);

    world.activeAbility.set(
      target,
      id: 'eloise.quick_shot',
      slot: AbilitySlot.projectile,
      commitTick: 10,
      windupTicks: 3,
      activeTicks: 1,
      recoveryTicks: 5,
      facingDir: Facing.right,
    );
    final intentIndex = world.projectileIntent.indexOf(target);
    world.projectileIntent.tick[intentIndex] = 13;
    world.projectileIntent.commitTick[intentIndex] = 10;
    world.abilityInputBuffer.setBuffer(
      target,
      slot: AbilitySlot.projectile,
      abilityId: 'eloise.quick_shot',
      aimDirX: 1.0,
      aimDirY: 0.0,
      facing: Facing.right,
      commitTick: 10,
      expiresTick: 16,
    );

    world.damageQueue.add(DamageRequest(target: target, amount100: 500));
    damage.step(world, currentTick: 11);

    expect(world.health.hp[world.health.indexOf(target)], equals(9500));
    expect(world.activeAbility.hasActiveAbility(target), isTrue);
    final activeIndex = world.activeAbility.indexOf(target);
    expect(
      world.activeAbility.abilityId[activeIndex],
      equals('eloise.quick_shot'),
    );
    expect(world.projectileIntent.tick[intentIndex], equals(13));
    expect(world.projectileIntent.commitTick[intentIndex], equals(10));
    expect(
      world.abilityInputBuffer.hasBuffered[world.abilityInputBuffer.indexOf(
        target,
      )],
      isTrue,
    );
  });

  test('DamageSystem queues onCrit status only when hit crits', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 2000, hpMax: 2000, regenPerSecond100: 0),
    );

    final queued = <StatusRequest>[];
    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 1000,
        critChanceBp: 10000,
        procs: const <WeaponProc>[
          WeaponProc(
            hook: ProcHook.onCrit,
            statusProfileId: StatusProfileId.burnOnHit,
            chanceBp: 10000,
          ),
        ],
      ),
    );

    damage.step(world, currentTick: 1, queueStatus: queued.add);

    expect(queued, hasLength(1));
    expect(queued.single.target, equals(target));
    expect(queued.single.profileId, equals(StatusProfileId.burnOnHit));
  });

  test('DamageSystem queues onKill status on source entity', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

    final source = world.createEntity();
    world.health.add(
      source,
      const HealthDef(hp: 2000, hpMax: 2000, regenPerSecond100: 0),
    );
    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
    );

    final queued = <StatusRequest>[];
    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 1000,
        source: source,
        procs: const <WeaponProc>[
          WeaponProc(
            hook: ProcHook.onKill,
            statusProfileId: StatusProfileId.speedBoost,
            chanceBp: 10000,
          ),
        ],
      ),
    );

    damage.step(world, currentTick: 1, queueStatus: queued.add);

    expect(world.health.hp[world.health.indexOf(target)], equals(0));
    expect(queued, hasLength(1));
    expect(queued.single.target, equals(source));
    expect(queued.single.profileId, equals(StatusProfileId.speedBoost));
  });
}

class _DefenseWeaponCatalog extends WeaponCatalog {
  const _DefenseWeaponCatalog();

  @override
  WeaponDef get(WeaponId id) {
    if (id == WeaponId.plainsteel) {
      return const WeaponDef(
        id: WeaponId.plainsteel,
        category: WeaponCategory.primary,
        weaponType: WeaponType.oneHandedSword,
        stats: GearStatBonuses(defenseBonusBp: 2000),
      );
    }
    return const WeaponDef(
      id: WeaponId.basicShield,
      category: WeaponCategory.offHand,
      weaponType: WeaponType.shield,
    );
  }
}

class _FlatWeaponCatalog extends WeaponCatalog {
  const _FlatWeaponCatalog();

  @override
  WeaponDef get(WeaponId id) {
    return const WeaponDef(
      id: WeaponId.plainsteel,
      category: WeaponCategory.primary,
      weaponType: WeaponType.oneHandedSword,
      stats: GearStatBonuses(),
    );
  }
}

class _FlatProjectileCatalog extends ProjectileCatalog {
  const _FlatProjectileCatalog();

  @override
  ProjectileItemDef get(ProjectileId id) {
    return const ProjectileItemDef(
      id: ProjectileId.throwingKnife,
      weaponType: WeaponType.throwingWeapon,
      speedUnitsPerSecond: 900.0,
      lifetimeSeconds: 1.2,
      colliderSizeX: 14.0,
      colliderSizeY: 6.0,
    );
  }
}

class _FlatSpellBookCatalog extends SpellBookCatalog {
  const _FlatSpellBookCatalog();

  @override
  SpellBookDef get(SpellBookId id) {
    return const SpellBookDef(
      id: SpellBookId.basicSpellBook,
      weaponType: WeaponType.spell,
    );
  }
}

class _FlatAccessoryCatalog extends AccessoryCatalog {
  const _FlatAccessoryCatalog();

  @override
  AccessoryDef get(AccessoryId id) {
    return const AccessoryDef(
      id: AccessoryId.speedBoots,
      stats: GearStatBonuses(),
    );
  }
}

class _TypedResistanceAccessoryCatalog extends AccessoryCatalog {
  const _TypedResistanceAccessoryCatalog();

  @override
  AccessoryDef get(AccessoryId id) {
    return const AccessoryDef(
      id: AccessoryId.speedBoots,
      stats: GearStatBonuses(fireResistanceBp: 3000),
    );
  }
}
