import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/accessories/accessory_def.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart' show WeaponType;
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
}

class _DefenseWeaponCatalog extends WeaponCatalog {
  const _DefenseWeaponCatalog();

  @override
  WeaponDef get(WeaponId id) {
    if (id == WeaponId.woodenSword) {
      return const WeaponDef(
        id: WeaponId.woodenSword,
        displayName: 'Defense Sword',
        description: 'Test weapon with defense bonus.',
        category: WeaponCategory.primary,
        weaponType: WeaponType.oneHandedSword,
        stats: GearStatBonuses(defenseBonusBp: 2000),
      );
    }
    return const WeaponDef(
      id: WeaponId.basicShield,
      displayName: 'Flat',
      description: 'Flat weapon.',
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
      displayName: 'Flat Projectile',
      description: 'Flat projectile.',
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
      displayName: 'Flat Spellbook',
      description: 'Flat spellbook.',
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
      displayName: 'Flat Accessory',
      description: 'Flat accessory.',
      stats: AccessoryStats(),
    );
  }
}
