import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/accessories/accessory_def.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart'
    show AbilitySlot, WeaponType;
import 'package:rpg_runner/core/combat/damage.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/systems/damage_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_def.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/spells/spell_book_catalog.dart';
import 'package:rpg_runner/core/spells/spell_book_def.dart';
import 'package:rpg_runner/core/spells/spell_book_id.dart';
import 'package:rpg_runner/core/stats/character_stats_resolver.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_category.dart';
import 'package:rpg_runner/core/weapons/weapon_def.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';
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

  test('DamageSystem applies global defense from equipped loadout', () {
    final world = EcsWorld();
    final resolver = CharacterStatsResolver(
      weapons: const _DefenseWeaponCatalog(),
      projectileItems: const _FlatProjectileCatalog(),
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
        mainWeaponId: WeaponId.woodenSword,
      ),
    );

    world.damageQueue.add(DamageRequest(target: target, amount100: 1000));

    damage.step(world, currentTick: 1);

    expect(world.health.hp[world.health.indexOf(target)], equals(9200));
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
      id: 'eloise.charged_shot',
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
      abilityId: 'eloise.charged_shot',
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
}

class _DefenseWeaponCatalog extends WeaponCatalog {
  const _DefenseWeaponCatalog();

  @override
  WeaponDef get(WeaponId id) {
    if (id == WeaponId.woodenSword) {
      return const WeaponDef(
        id: WeaponId.woodenSword,
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

class _FlatProjectileCatalog extends ProjectileItemCatalog {
  const _FlatProjectileCatalog();

  @override
  ProjectileItemDef get(ProjectileItemId id) {
    return const ProjectileItemDef(
      id: ProjectileItemId.throwingKnife,
      weaponType: WeaponType.throwingWeapon,
      projectileId: ProjectileId.throwingKnife,
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
