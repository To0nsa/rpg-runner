import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/accessories/accessory_def.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart'
    show AbilitySlot, WeaponType;
import 'package:rpg_runner/core/combat/damage.dart';
import 'package:rpg_runner/core/combat/damage_type.dart';
import 'package:rpg_runner/core/combat/control_lock.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/damage_resistance_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/enemies/enemy_store.dart';
import 'package:rpg_runner/core/ecs/stores/status/dot_store.dart';
import 'package:rpg_runner/core/ecs/stores/status/slow_store.dart';
import 'package:rpg_runner/core/ecs/stores/status/haste_store.dart';
import 'package:rpg_runner/core/ecs/stores/status/vulnerable_store.dart';
import 'package:rpg_runner/core/ecs/stores/status/weaken_store.dart';
import 'package:rpg_runner/core/ecs/stores/status/drench_store.dart';
import 'package:rpg_runner/core/ecs/systems/damage_system.dart';
import 'package:rpg_runner/core/ecs/systems/status_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/enemies/enemy_id.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_def.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/spellBook/spell_book_catalog.dart';
import 'package:rpg_runner/core/spellBook/spell_book_def.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/core/stats/character_stats_resolver.dart';
import 'package:rpg_runner/core/stats/gear_stat_bonuses.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_category.dart';
import 'package:rpg_runner/core/weapons/weapon_def.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';
import 'package:rpg_runner/core/weapons/weapon_proc.dart';

void main() {
  test('DamageSystem applies resistance and vulnerability modifiers', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.damageResistance.add(
      target,
      const DamageResistanceDef(fireBp: -5000, iceBp: 5000),
    );

    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 1000,
        damageType: DamageType.fire,
      ),
    );
    damage.step(world, currentTick: 1);

    expect(world.health.hp[world.health.indexOf(target)], equals(9500));

    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 1000,
        damageType: DamageType.ice,
      ),
    );
    damage.step(world, currentTick: 2);

    expect(world.health.hp[world.health.indexOf(target)], equals(8000));
  });

  test('status applies even when damage is fully resisted', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    final status = StatusSystem(tickHz: 60);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.damageResistance.add(
      target,
      const DamageResistanceDef(iceBp: -10000),
    );
    world.invulnerability.add(target);
    world.statusImmunity.add(target);
    world.statModifier.add(target);

    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 1000,
        damageType: DamageType.ice,
        procs: const <WeaponProc>[
          WeaponProc(
            hook: ProcHook.onHit,
            statusProfileId: StatusProfileId.slowOnHit,
            chanceBp: 10000,
          ),
        ],
      ),
    );
    damage.step(world, currentTick: 1, queueStatus: status.queue);
    status.applyQueued(world, currentTick: 1);

    expect(world.health.hp[world.health.indexOf(target)], equals(5000));
    expect(world.slow.has(target), isTrue);
  });

  test('bleed ticks damage on its period', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    final status = StatusSystem(tickHz: 10);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 2000, hpMax: 2000, regenPerSecond100: 0),
    );
    world.damageResistance.add(target, const DamageResistanceDef());
    world.invulnerability.add(target);
    world.statusImmunity.add(target);

    status.queue(
      StatusRequest(target: target, profileId: StatusProfileId.meleeBleed),
    );
    status.applyQueued(world, currentTick: 0);

    for (var tick = 1; tick <= 10; tick += 1) {
      status.tickExisting(world);
      damage.step(world, currentTick: tick);
    }

    expect(world.health.hp[world.health.indexOf(target)], equals(1700));
  });

  test('restore mana profile restores gradually across its duration', () {
    final world = EcsWorld();
    final status = StatusSystem(tickHz: 60);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.mana.add(
      target,
      const ManaDef(mana: 200, manaMax: 1000, regenPerSecond100: 0),
    );

    status.queue(
      StatusRequest(target: target, profileId: StatusProfileId.restoreMana),
    );
    status.applyQueued(world, currentTick: 1);

    expect(world.mana.mana[world.mana.indexOf(target)], equals(200));

    for (var tick = 0; tick < 60 * 5; tick += 1) {
      status.tickExisting(world);
    }

    expect(world.mana.mana[world.mana.indexOf(target)], equals(550));
  });

  test('resource-over-time profile restores configured total smoothly', () {
    final world = EcsWorld();
    final status = StatusSystem(
      tickHz: 10,
      profiles: const _ResourceOverTimeStatusProfileCatalog(),
    );

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.stamina.add(
      target,
      const StaminaDef(stamina: 0, staminaMax: 1000, regenPerSecond100: 0),
    );

    status.queue(
      StatusRequest(target: target, profileId: StatusProfileId.restoreStamina),
    );
    status.applyQueued(world, currentTick: 0);

    expect(world.stamina.stamina[world.stamina.indexOf(target)], equals(0));

    for (var tick = 1; tick <= 21; tick += 1) {
      status.tickExisting(world);
    }

    expect(world.stamina.stamina[world.stamina.indexOf(target)], equals(100));
  });

  test('haste stacks additively with slow', () {
    final world = EcsWorld();
    final status = StatusSystem(tickHz: 60);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.statModifier.add(target);

    status.queue(
      StatusRequest(target: target, profileId: StatusProfileId.slowOnHit),
    );
    status.queue(
      StatusRequest(target: target, profileId: StatusProfileId.speedBoost),
    );
    status.applyQueued(world, currentTick: 1);

    final index = world.statModifier.indexOf(target);
    expect(world.statModifier.moveSpeedMul[index], closeTo(1.25, 1e-6));
  });

  test('move speed clamps with excessive haste', () {
    final world = EcsWorld();
    final status = StatusSystem(
      tickHz: 60,
      profiles: const TestStatusProfileCatalog(),
    );

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.statModifier.add(target);

    status.queue(
      StatusRequest(target: target, profileId: StatusProfileId.speedBoost),
    );
    status.applyQueued(world, currentTick: 1);

    final index = world.statModifier.indexOf(target);
    expect(world.statModifier.moveSpeedMul[index], closeTo(2.0, 1e-6));
  });

  test(
    'invulnerability blocks harmful statuses but allows Arcane Ward',
    () {
      final world = EcsWorld();
      final status = StatusSystem(tickHz: 60);

      final target = world.createEntity();
      world.health.add(
        target,
        const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
      );
      world.invulnerability.add(target);
      world.statusImmunity.add(target);

      final invulnIndex = world.invulnerability.indexOf(target);
      world.invulnerability.ticksLeft[invulnIndex] = 120;

      status.queue(
        StatusRequest(target: target, profileId: StatusProfileId.arcaneWard),
      );
      status.queue(
        StatusRequest(target: target, profileId: StatusProfileId.burnOnHit),
      );
      status.applyQueued(world, currentTick: 1);

      expect(world.damageReduction.has(target), isTrue);
      final wardIndex = world.damageReduction.indexOf(target);
      expect(world.damageReduction.magnitude[wardIndex], equals(4000));
      expect(world.damageReduction.ticksLeft[wardIndex], equals(240));
      expect(world.dot.has(target), isFalse);
    },
  );

  test('Arcane Ward stack policy uses stronger replace and equal refresh', () {
    final world = EcsWorld();
    final status = StatusSystem(
      tickHz: 60,
      profiles: const _DamageReductionStatusProfileCatalog(),
    );

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );

    status.queue(
      StatusRequest(target: target, profileId: StatusProfileId.arcaneWard),
    );
    status.applyQueued(world, currentTick: 1);

    var wardIndex = world.damageReduction.indexOf(target);
    expect(world.damageReduction.magnitude[wardIndex], equals(4000));
    expect(world.damageReduction.ticksLeft[wardIndex], equals(240));

    for (var tick = 0; tick < 100; tick += 1) {
      status.tickExisting(world);
    }

    status.queue(
      StatusRequest(target: target, profileId: StatusProfileId.restoreHealth),
    );
    status.applyQueued(world, currentTick: 2);

    wardIndex = world.damageReduction.indexOf(target);
    expect(world.damageReduction.magnitude[wardIndex], equals(4000));
    expect(world.damageReduction.ticksLeft[wardIndex], equals(420));

    status.queue(
      StatusRequest(target: target, profileId: StatusProfileId.speedBoost),
    );
    status.applyQueued(world, currentTick: 3);

    wardIndex = world.damageReduction.indexOf(target);
    expect(world.damageReduction.magnitude[wardIndex], equals(4000));
    expect(world.damageReduction.ticksLeft[wardIndex], equals(420));

    status.queue(
      StatusRequest(target: target, profileId: StatusProfileId.restoreMana),
    );
    status.applyQueued(world, currentTick: 4);

    wardIndex = world.damageReduction.indexOf(target);
    expect(world.damageReduction.magnitude[wardIndex], equals(6000));
    expect(world.damageReduction.ticksLeft[wardIndex], equals(120));
  });

  test('cleanse purge removes debuffs including stun but preserves buffs', () {
    final world = EcsWorld();
    final status = StatusSystem(tickHz: 60);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.dot.add(
      target,
      const DotDef(
        damageType: DamageType.fire,
        ticksLeft: 30,
        periodTicks: 1,
        dps100: 500,
      ),
    );
    world.slow.add(target, const SlowDef(ticksLeft: 30, magnitude: 2500));
    world.vulnerable.add(
      target,
      const VulnerableDef(ticksLeft: 30, magnitude: 5000),
    );
    world.weaken.add(target, const WeakenDef(ticksLeft: 30, magnitude: 3500));
    world.drench.add(target, const DrenchDef(ticksLeft: 30, magnitude: 5000));
    world.haste.add(target, const HasteDef(ticksLeft: 30, magnitude: 2000));
    world.controlLock.addLock(target, LockFlag.stun, 20, 0);
    world.controlLock.addLock(target, LockFlag.cast, 20, 0);

    status.queuePurge(
      PurgeRequest(target: target, profileId: PurgeProfileId.cleanse),
    );
    status.tickExisting(world);

    expect(world.dot.has(target), isFalse);
    expect(world.slow.has(target), isFalse);
    expect(world.vulnerable.has(target), isFalse);
    expect(world.weaken.has(target), isFalse);
    expect(world.drench.has(target), isFalse);
    expect(world.haste.has(target), isTrue);

    expect(world.controlLock.isLocked(target, LockFlag.stun, 0), isFalse);
    expect(world.controlLock.isLocked(target, LockFlag.cast, 0), isFalse);
    expect(world.damageQueue.length, equals(0));
  });

  test('status scaling uses combined typed modifier from store and gear', () {
    final world = EcsWorld();
    final status = StatusSystem(
      tickHz: 60,
      statsResolver: CharacterStatsResolver(
        weapons: const _FlatWeaponCatalog(),
        projectiles: const _FlatProjectileCatalog(),
        spellBooks: const _FlatSpellBookCatalog(),
        accessories: const _FireResistAccessoryCatalog(),
      ),
    );

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.damageResistance.add(target, const DamageResistanceDef(fireBp: 5000));
    world.equippedLoadout.add(
      target,
      const EquippedLoadoutDef(
        mask: LoadoutSlotMask.mainHand,
        accessoryId: AccessoryId.speedBoots,
      ),
    );
    world.invulnerability.add(target);
    world.statusImmunity.add(target);
    world.statModifier.add(target);

    status.queue(
      StatusRequest(
        target: target,
        profileId: StatusProfileId.burnOnHit,
        damageType: DamageType.fire,
      ),
    );
    status.applyQueued(world, currentTick: 1);

    final dotIndex = world.dot.indexOf(target);
    final fireChannel = world.dot.channelIndexFor(target, DamageType.fire);
    expect(fireChannel, isNotNull);
    // FireBolt base dps100=500. Combined typed mod: +5000 store - 4000 gear = +1000.
    expect(world.dot.dps100[dotIndex][fireChannel!], equals(550));
  });

  test('acid on-hit applies +50% global vulnerability for 5 seconds', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    final status = StatusSystem(
      tickHz: 60,
      statsResolver: CharacterStatsResolver(
        weapons: const _FlatWeaponCatalog(),
        projectiles: const _FlatProjectileCatalog(),
        spellBooks: const _FlatSpellBookCatalog(),
        accessories: const _AcidResistAccessoryCatalog(),
      ),
    );

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.damageResistance.add(target, const DamageResistanceDef(acidBp: 5000));
    world.equippedLoadout.add(
      target,
      const EquippedLoadoutDef(
        mask: LoadoutSlotMask.mainHand,
        accessoryId: AccessoryId.speedBoots,
      ),
    );
    world.invulnerability.add(target);
    world.statusImmunity.add(target);
    world.statModifier.add(target);

    status.queue(
      StatusRequest(
        target: target,
        profileId: StatusProfileId.acidOnHit,
        damageType: DamageType.acid,
      ),
    );
    status.applyQueued(world, currentTick: 1);

    expect(world.dot.has(target), isFalse);
    expect(world.vulnerable.has(target), isTrue);

    final vulnerableIndex = world.vulnerable.indexOf(target);
    expect(world.vulnerable.magnitude[vulnerableIndex], equals(5000));
    expect(world.vulnerable.ticksLeft[vulnerableIndex], equals(300));

    world.damageQueue.add(
      DamageRequest(
        target: target,
        amount100: 1000,
        damageType: DamageType.physical,
      ),
    );
    damage.step(world, currentTick: 2);
    expect(world.health.hp[world.health.indexOf(target)], equals(3500));

    for (var tick = 0; tick < 299; tick += 1) {
      status.tickExisting(world);
    }
    expect(world.vulnerable.has(target), isTrue);

    status.tickExisting(world);
    expect(world.vulnerable.has(target), isFalse);
  });

  test('weaken on-hit reduces source outgoing damage for 5 seconds', () {
    final world = EcsWorld();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    final status = StatusSystem(tickHz: 60);

    final source = world.createEntity();
    world.health.add(
      source,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );

    status.queue(
      StatusRequest(
        target: source,
        profileId: StatusProfileId.weakenOnHit,
        damageType: DamageType.dark,
      ),
    );
    status.applyQueued(world, currentTick: 1);

    expect(world.weaken.has(source), isTrue);
    final weakenIndex = world.weaken.indexOf(source);
    expect(world.weaken.magnitude[weakenIndex], equals(3500));
    expect(world.weaken.ticksLeft[weakenIndex], equals(300));

    world.damageQueue.add(
      DamageRequest(target: target, amount100: 1000, source: source),
    );
    damage.step(world, currentTick: 2);
    expect(world.health.hp[world.health.indexOf(target)], equals(9350));

    for (var tick = 0; tick < 300; tick += 1) {
      status.tickExisting(world);
    }
    expect(world.weaken.has(source), isFalse);

    world.damageQueue.add(
      DamageRequest(target: target, amount100: 1000, source: source),
    );
    damage.step(world, currentTick: 3);
    expect(world.health.hp[world.health.indexOf(target)], equals(8350));
  });

  test('drench on-hit reduces action speed by 50% for 5 seconds', () {
    final world = EcsWorld();
    final status = StatusSystem(tickHz: 60);

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.statModifier.add(target);

    status.queue(
      StatusRequest(
        target: target,
        profileId: StatusProfileId.drenchOnHit,
        damageType: DamageType.water,
      ),
    );
    status.applyQueued(world, currentTick: 1);

    expect(world.drench.has(target), isTrue);
    final drenchIndex = world.drench.indexOf(target);
    expect(world.drench.magnitude[drenchIndex], equals(5000));
    expect(world.drench.ticksLeft[drenchIndex], equals(300));
    expect(
      world.statModifier.actionSpeedBp[world.statModifier.indexOf(target)],
      equals(5000),
    );

    for (var tick = 2; tick <= 301; tick += 1) {
      status.tickExisting(world);
      status.applyQueued(world, currentTick: tick);
    }

    expect(world.drench.has(target), isFalse);
    expect(
      world.statModifier.actionSpeedBp[world.statModifier.indexOf(target)],
      equals(10000),
    );
  });

  test(
    'silence on-hit applies cast lock and interrupts enemy projectile cast during windup',
    () {
      final world = EcsWorld();
      final status = StatusSystem(tickHz: 60);

      final enemy = world.createEntity();
      world.health.add(
        enemy,
        const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
      );
      world.enemy.add(
        enemy,
        const EnemyDef(enemyId: EnemyId.unocoDemon, facing: Facing.left),
      );
      world.activeAbility.add(enemy);
      world.projectileIntent.add(enemy);

      world.activeAbility.set(
        enemy,
        id: 'common.enemy_cast',
        slot: AbilitySlot.projectile,
        commitTick: 10,
        windupTicks: 5,
        activeTicks: 2,
        recoveryTicks: 3,
        facingDir: Facing.left,
      );

      status.queue(
        StatusRequest(
          target: enemy,
          profileId: StatusProfileId.silenceOnHit,
          damageType: DamageType.holy,
        ),
      );
      status.applyQueued(world, currentTick: 12);

      expect(world.controlLock.isLocked(enemy, LockFlag.cast, 12), isTrue);
      expect(world.activeAbility.hasActiveAbility(enemy), isFalse);
    },
  );

  test('silence does not interrupt enemy projectile cast outside windup', () {
    final world = EcsWorld();
    final status = StatusSystem(tickHz: 60);

    final enemy = world.createEntity();
    world.health.add(
      enemy,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.enemy.add(
      enemy,
      const EnemyDef(enemyId: EnemyId.unocoDemon, facing: Facing.left),
    );
    world.activeAbility.add(enemy);

    world.activeAbility.set(
      enemy,
      id: 'common.enemy_cast',
      slot: AbilitySlot.projectile,
      commitTick: 10,
      windupTicks: 2,
      activeTicks: 3,
      recoveryTicks: 2,
      facingDir: Facing.left,
    );

    status.queue(
      StatusRequest(
        target: enemy,
        profileId: StatusProfileId.silenceOnHit,
        damageType: DamageType.holy,
      ),
    );
    status.applyQueued(world, currentTick: 13); // elapsed=3 => active phase.

    expect(world.controlLock.isLocked(enemy, LockFlag.cast, 13), isTrue);
    expect(world.activeAbility.hasActiveAbility(enemy), isTrue);
  });
}

class TestStatusProfileCatalog extends StatusProfileCatalog {
  const TestStatusProfileCatalog();

  @override
  StatusProfile get(StatusProfileId id) {
    switch (id) {
      case StatusProfileId.speedBoost:
        return const StatusProfile(<StatusApplication>[
          StatusApplication(
            type: StatusEffectType.haste,
            magnitude: 30000,
            durationSeconds: 5.0,
          ),
        ]);
      default:
        return super.get(id);
    }
  }
}

class _FlatWeaponCatalog extends WeaponCatalog {
  const _FlatWeaponCatalog();

  @override
  WeaponDef get(WeaponId id) {
    return const WeaponDef(
      id: WeaponId.basicSword,
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
      stats: GearStatBonuses(),
    );
  }
}

class _FlatSpellBookCatalog extends SpellBookCatalog {
  const _FlatSpellBookCatalog();

  @override
  SpellBookDef get(SpellBookId id) {
    return const SpellBookDef(
      id: SpellBookId.basicSpellBook,
      weaponType: WeaponType.projectileSpell,
      stats: GearStatBonuses(),
    );
  }
}

class _FireResistAccessoryCatalog extends AccessoryCatalog {
  const _FireResistAccessoryCatalog();

  @override
  AccessoryDef get(AccessoryId id) {
    return const AccessoryDef(
      id: AccessoryId.speedBoots,
      stats: GearStatBonuses(fireResistanceBp: 4000),
    );
  }
}

class _AcidResistAccessoryCatalog extends AccessoryCatalog {
  const _AcidResistAccessoryCatalog();

  @override
  AccessoryDef get(AccessoryId id) {
    return const AccessoryDef(
      id: AccessoryId.speedBoots,
      stats: GearStatBonuses(acidResistanceBp: 4000),
    );
  }
}

class _ResourceOverTimeStatusProfileCatalog extends StatusProfileCatalog {
  const _ResourceOverTimeStatusProfileCatalog();

  @override
  StatusProfile get(StatusProfileId id) {
    switch (id) {
      case StatusProfileId.restoreStamina:
        return const StatusProfile(<StatusApplication>[
          StatusApplication(
            type: StatusEffectType.resourceOverTime,
            magnitude: 1000, // 10% total across duration
            durationSeconds: 2.1,
            periodSeconds: 1.0,
            resourceType: StatusResourceType.stamina,
          ),
        ]);
      default:
        return super.get(id);
    }
  }
}

class _DamageReductionStatusProfileCatalog extends StatusProfileCatalog {
  const _DamageReductionStatusProfileCatalog();

  @override
  StatusProfile get(StatusProfileId id) {
    switch (id) {
      case StatusProfileId.arcaneWard:
        return const StatusProfile(<StatusApplication>[
          StatusApplication(
            type: StatusEffectType.damageReduction,
            magnitude: 4000,
            durationSeconds: 4.0,
          ),
        ]);
      case StatusProfileId.restoreHealth:
        return const StatusProfile(<StatusApplication>[
          StatusApplication(
            type: StatusEffectType.damageReduction,
            magnitude: 4000,
            durationSeconds: 7.0,
          ),
        ]);
      case StatusProfileId.speedBoost:
        return const StatusProfile(<StatusApplication>[
          StatusApplication(
            type: StatusEffectType.damageReduction,
            magnitude: 2500,
            durationSeconds: 10.0,
          ),
        ]);
      case StatusProfileId.restoreMana:
        return const StatusProfile(<StatusApplication>[
          StatusApplication(
            type: StatusEffectType.damageReduction,
            magnitude: 6000,
            durationSeconds: 2.0,
          ),
        ]);
      default:
        return super.get(id);
    }
  }
}
