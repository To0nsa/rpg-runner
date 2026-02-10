import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/combat/faction.dart';
import 'package:rpg_runner/core/ecs/entity_id.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/faction_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/ability_activation_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/spells/spell_book_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';

void main() {
  test('sword strike auto-aim commits melee intent toward nearest hostile', () {
    final world = EcsWorld();
    final system = _buildSystem();
    final player = _spawnPlayer(
      world,
      abilityPrimaryId: 'eloise.sword_strike_auto_aim',
    );

    _spawnEnemy(world, x: 130, y: 140); // dx=30, dy=40, len=50
    _spawnEnemy(world, x: 320, y: 100);

    final inputIndex = world.playerInput.indexOf(player);
    world.playerInput.strikePressed[inputIndex] = true;

    system.step(world, player: player, currentTick: 1);

    final meleeIndex = world.meleeIntent.indexOf(player);
    expect(
      world.meleeIntent.abilityId[meleeIndex],
      'eloise.sword_strike_auto_aim',
    );
    expect(world.meleeIntent.tick[meleeIndex], greaterThanOrEqualTo(1));
    expect(world.meleeIntent.dirX[meleeIndex], closeTo(0.6, 1e-9));
    expect(world.meleeIntent.dirY[meleeIndex], closeTo(0.8, 1e-9));
  });

  test('shield bash auto-aim commits melee intent toward nearest hostile', () {
    final world = EcsWorld();
    final system = _buildSystem();
    final player = _spawnPlayer(
      world,
      abilitySecondaryId: 'eloise.shield_bash_auto_aim',
    );

    _spawnEnemy(world, x: 70, y: 100);
    _spawnEnemy(world, x: 220, y: 100);

    final inputIndex = world.playerInput.indexOf(player);
    world.playerInput.secondaryPressed[inputIndex] = true;

    system.step(world, player: player, currentTick: 1);

    final meleeIndex = world.meleeIntent.indexOf(player);
    expect(
      world.meleeIntent.abilityId[meleeIndex],
      'eloise.shield_bash_auto_aim',
    );
    expect(world.meleeIntent.dirX[meleeIndex], closeTo(-1.0, 1e-9));
    expect(world.meleeIntent.dirY[meleeIndex].abs(), lessThan(1e-9));
  });

  test(
    'homing melee falls back to facing direction when no hostile exists',
    () {
      final world = EcsWorld();
      final system = _buildSystem();
      final player = _spawnPlayer(
        world,
        abilityPrimaryId: 'eloise.sword_strike_auto_aim',
        facing: Facing.left,
      );

      final inputIndex = world.playerInput.indexOf(player);
      world.playerInput.strikePressed[inputIndex] = true;

      system.step(world, player: player, currentTick: 1);

      final meleeIndex = world.meleeIntent.indexOf(player);
      expect(world.meleeIntent.dirX[meleeIndex], closeTo(-1.0, 1e-9));
      expect(world.meleeIntent.dirY[meleeIndex].abs(), lessThan(1e-9));
    },
  );

  test('auto-aim melee variants apply explicit reliability tax', () {
    final swordBase = AbilityCatalog.tryGet('eloise.sword_strike')!;
    final swordAuto = AbilityCatalog.tryGet('eloise.sword_strike_auto_aim')!;
    final shieldBase = AbilityCatalog.tryGet('eloise.shield_bash')!;
    final shieldAuto = AbilityCatalog.tryGet('eloise.shield_bash_auto_aim')!;

    expect(swordAuto.baseDamage, equals(1400));
    expect(swordAuto.staminaCost, equals(550));
    expect(swordAuto.cooldownTicks, equals(24));
    expect(swordAuto.baseDamage, lessThan(swordBase.baseDamage));
    expect(swordAuto.staminaCost, greaterThan(swordBase.staminaCost));
    expect(swordAuto.cooldownTicks, greaterThan(swordBase.cooldownTicks));

    expect(shieldAuto.baseDamage, equals(1400));
    expect(shieldAuto.staminaCost, equals(550));
    expect(shieldAuto.cooldownTicks, equals(24));
    expect(shieldAuto.baseDamage, lessThan(shieldBase.baseDamage));
    expect(shieldAuto.staminaCost, greaterThan(shieldBase.staminaCost));
    expect(shieldAuto.cooldownTicks, greaterThan(shieldBase.cooldownTicks));
  });
}

AbilityActivationSystem _buildSystem() {
  return AbilityActivationSystem(
    tickHz: 60,
    inputBufferTicks: 10,
    abilities: const AbilityCatalog(),
    weapons: const WeaponCatalog(),
    projectileItems: const ProjectileItemCatalog(),
    spellBooks: const SpellBookCatalog(),
    accessories: const AccessoryCatalog(),
  );
}

EntityId _spawnPlayer(
  EcsWorld world, {
  String abilityPrimaryId = 'eloise.sword_strike',
  String abilitySecondaryId = 'eloise.shield_bash',
  Facing facing = Facing.right,
}) {
  final player = world.createEntity();
  world.transform.add(player, posX: 100, posY: 100, velX: 0, velY: 0);
  world.faction.add(player, const FactionDef(faction: Faction.player));
  world.health.add(
    player,
    const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
  );
  world.playerInput.add(player);
  world.movement.add(player, facing: facing);
  world.abilityInputBuffer.add(player);
  world.activeAbility.add(player);
  world.cooldown.add(player);
  world.mana.add(
    player,
    const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
  );
  world.stamina.add(
    player,
    const StaminaDef(stamina: 5000, staminaMax: 5000, regenPerSecond100: 0),
  );
  world.meleeIntent.add(player);
  world.equippedLoadout.add(
    player,
    EquippedLoadoutDef(
      mask: LoadoutSlotMask.all,
      abilityPrimaryId: abilityPrimaryId,
      abilitySecondaryId: abilitySecondaryId,
    ),
  );
  return player;
}

EntityId _spawnEnemy(EcsWorld world, {required double x, required double y}) {
  final enemy = world.createEntity();
  world.transform.add(enemy, posX: x, posY: y, velX: 0, velY: 0);
  world.faction.add(enemy, const FactionDef(faction: Faction.enemy));
  world.health.add(
    enemy,
    const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
  );
  return enemy;
}
