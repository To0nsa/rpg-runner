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
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/spellBook/spell_book_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';

void main() {
  test('sword strike auto-aim commits melee intent toward nearest hostile', () {
    final world = EcsWorld();
    final system = _buildSystem();
    final player = _spawnPlayer(
      world,
      abilityPrimaryId: 'eloise.seeker_slash',
    );

    _spawnEnemy(world, x: 130, y: 140); // dx=30, dy=40, len=50
    _spawnEnemy(world, x: 320, y: 100);

    final inputIndex = world.playerInput.indexOf(player);
    world.playerInput.strikePressed[inputIndex] = true;

    system.step(world, player: player, currentTick: 1);

    final meleeIndex = world.meleeIntent.indexOf(player);
    expect(
      world.meleeIntent.abilityId[meleeIndex],
      'eloise.seeker_slash',
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
      abilitySecondaryId: 'eloise.seeker_bash',
    );

    _spawnEnemy(world, x: 70, y: 100);
    _spawnEnemy(world, x: 220, y: 100);

    final inputIndex = world.playerInput.indexOf(player);
    world.playerInput.secondaryPressed[inputIndex] = true;

    system.step(world, player: player, currentTick: 1);

    final meleeIndex = world.meleeIntent.indexOf(player);
    expect(
      world.meleeIntent.abilityId[meleeIndex],
      'eloise.seeker_bash',
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
        abilityPrimaryId: 'eloise.seeker_slash',
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
    final swordBase = AbilityCatalog.shared.resolve('eloise.bloodletter_slash')!;
    final swordAuto = AbilityCatalog.shared.resolve(
      'eloise.seeker_slash',
    )!;
    final shieldBase = AbilityCatalog.shared.resolve('eloise.concussive_bash')!;
    final shieldAuto = AbilityCatalog.shared.resolve(
      'eloise.seeker_bash',
    )!;

    expect(swordAuto.baseDamage, equals(1400));
    expect(swordAuto.defaultCost.staminaCost100, equals(550));
    expect(swordAuto.cooldownTicks, equals(24));
    expect(swordAuto.baseDamage, lessThan(swordBase.baseDamage));
    expect(
      swordAuto.defaultCost.staminaCost100,
      greaterThan(swordBase.defaultCost.staminaCost100),
    );
    expect(swordAuto.cooldownTicks, greaterThan(swordBase.cooldownTicks));

    expect(shieldAuto.baseDamage, equals(1400));
    expect(shieldAuto.defaultCost.staminaCost100, equals(550));
    expect(shieldAuto.cooldownTicks, equals(24));
    expect(shieldAuto.baseDamage, lessThan(shieldBase.baseDamage));
    expect(
      shieldAuto.defaultCost.staminaCost100,
      greaterThan(shieldBase.defaultCost.staminaCost100),
    );
    expect(shieldAuto.cooldownTicks, greaterThan(shieldBase.cooldownTicks));
  });

  test(
    'homing melee predicts execute-time position from source and target velocity',
    () {
      final world = EcsWorld();
      final system = _buildSystem();
      final player = _spawnPlayer(
        world,
        abilityPrimaryId: 'eloise.seeker_slash',
        velX: 300,
      );

      _spawnEnemy(world, x: 130, y: 140, velX: 0, velY: 0);

      final inputIndex = world.playerInput.indexOf(player);
      world.playerInput.strikePressed[inputIndex] = true;

      system.step(world, player: player, currentTick: 1);

      final meleeIndex = world.meleeIntent.indexOf(player);
      expect(world.meleeIntent.dirX[meleeIndex], lessThan(0));
      expect(world.meleeIntent.dirY[meleeIndex], greaterThan(0.95));
    },
  );
}

AbilityActivationSystem _buildSystem() {
  return AbilityActivationSystem(
    tickHz: 60,
    inputBufferTicks: 10,
    abilities: const AbilityCatalog(),
    weapons: const WeaponCatalog(),
    projectiles: const ProjectileCatalog(),
    spellBooks: const SpellBookCatalog(),
    accessories: const AccessoryCatalog(),
  );
}

EntityId _spawnPlayer(
  EcsWorld world, {
  String abilityPrimaryId = 'eloise.bloodletter_slash',
  String abilitySecondaryId = 'eloise.concussive_bash',
  Facing facing = Facing.right,
  double velX = 0,
  double velY = 0,
}) {
  final player = world.createEntity();
  world.transform.add(player, posX: 100, posY: 100, velX: velX, velY: velY);
  world.faction.add(player, const FactionDef(faction: Faction.player));
  world.health.add(
    player,
    const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
  );
  world.playerInput.add(player);
  world.movement.add(player, facing: facing);
  world.abilityInputBuffer.add(player);
  world.abilityCharge.add(player);
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

EntityId _spawnEnemy(
  EcsWorld world, {
  required double x,
  required double y,
  double velX = 0,
  double velY = 0,
}) {
  final enemy = world.createEntity();
  world.transform.add(enemy, posX: x, posY: y, velX: velX, velY: velY);
  world.faction.add(enemy, const FactionDef(faction: Faction.enemy));
  world.health.add(
    enemy,
    const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
  );
  return enemy;
}
