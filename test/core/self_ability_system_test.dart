import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/ability_activation_system.dart';
import 'package:rpg_runner/core/ecs/systems/self_ability_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_catalog.dart';
import 'package:rpg_runner/core/spells/spell_book_catalog.dart';
import 'package:rpg_runner/core/spells/spell_book_id.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';

void main() {
  test('bonus self spell commit consumes mana and starts bonus cooldown', () {
    final world = EcsWorld();
    final player = EntityFactory(world).createPlayer(
      posX: 0,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 1000, manaMax: 1000, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 1000,
        staminaMax: 1000,
        regenPerSecond100: 0,
      ),
    );

    // Setup loadout to map Bonus -> eloise.arcane_haste.
    final li = world.equippedLoadout.indexOf(player);
    world.equippedLoadout.mask[li] |= LoadoutSlotMask.projectile;
    world.equippedLoadout.abilityBonusId[li] = 'eloise.arcane_haste';

    // Simulate bonus input.
    final pi = world.playerInput.indexOf(player);
    world.playerInput.bonusPressed[pi] = true;

    final system = AbilityActivationSystem(
      tickHz: 60,
      inputBufferTicks: 10,
      abilities: const AbilityCatalog(),
      weapons: const WeaponCatalog(),
      projectileItems: const ProjectileItemCatalog(),
      spellBooks: const SpellBookCatalog(),
      accessories: const AccessoryCatalog(),
    );

    // Commit.
    system.step(world, player: player, currentTick: 5);

    // Verify active ability and commit side effects.
    expect(world.activeAbility.has(player), isTrue);
    final ai = world.activeAbility.indexOf(player);
    expect(world.activeAbility.abilityId[ai], equals('eloise.arcane_haste'));

    final ability = AbilityCatalog.tryGet('eloise.arcane_haste')!;
    expect(world.mana.mana[world.mana.indexOf(player)], equals(0));

    expect(
      world.cooldown.getTicksLeft(player, CooldownGroup.bonus0),
      equals(ability.cooldownTicks),
    );
  });

  test('restore mana self spell applies restore and clamps to max', () {
    final world = EcsWorld();
    final player = EntityFactory(world).createPlayer(
      posX: 0,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 200, manaMax: 1000, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 5000,
        staminaMax: 5000,
        regenPerSecond100: 0,
      ),
    );

    final li = world.equippedLoadout.indexOf(player);
    world.equippedLoadout.mask[li] |= LoadoutSlotMask.projectile;
    world.equippedLoadout.spellBookId[li] = SpellBookId.epicSpellBook;
    world.equippedLoadout.abilityBonusId[li] = 'eloise.restore_mana';

    final pi = world.playerInput.indexOf(player);
    world.playerInput.bonusPressed[pi] = true;

    final activation = AbilityActivationSystem(
      tickHz: 60,
      inputBufferTicks: 10,
      abilities: const AbilityCatalog(),
      weapons: const WeaponCatalog(),
      projectileItems: const ProjectileItemCatalog(),
      spellBooks: const SpellBookCatalog(),
      accessories: const AccessoryCatalog(),
    );
    final selfAbility = SelfAbilitySystem();

    activation.step(world, player: player, currentTick: 5);
    selfAbility.step(world, currentTick: 5);

    final ability = AbilityCatalog.tryGet('eloise.restore_mana')!;
    final expectedRestore = (1000 * ability.selfRestoreManaBp) ~/ 10000;
    expect(
      world.mana.mana[world.mana.indexOf(player)],
      equals(200 + expectedRestore),
    );
    expect(
      world.stamina.stamina[world.stamina.indexOf(player)],
      equals(5000 - ability.staminaCost),
    );

    // Re-cast after cooldown to verify clamping at max mana.
    world.cooldown.setTicksLeft(player, CooldownGroup.bonus0, 0);
    world.activeAbility.clear(player);
    world.playerInput.bonusPressed[pi] = true;
    activation.step(world, player: player, currentTick: 6);
    selfAbility.step(world, currentTick: 6);

    expect(world.mana.mana[world.mana.indexOf(player)], equals(900));

    world.cooldown.setTicksLeft(player, CooldownGroup.bonus0, 0);
    world.activeAbility.clear(player);
    world.playerInput.bonusPressed[pi] = true;
    activation.step(world, player: player, currentTick: 7);
    selfAbility.step(world, currentTick: 7);

    expect(world.mana.mana[world.mana.indexOf(player)], equals(1000));
  });

  test(
    'bonus self spell commit is blocked when spellbook does not grant it',
    () {
      final world = EcsWorld();
      final player = EntityFactory(world).createPlayer(
        posX: 0,
        posY: 0,
        velX: 0,
        velY: 0,
        facing: Facing.right,
        grounded: true,
        body: const BodyDef(isKinematic: true, useGravity: false),
        collider: const ColliderAabbDef(halfX: 8, halfY: 8),
        health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
        mana: const ManaDef(mana: 2000, manaMax: 2000, regenPerSecond100: 0),
        stamina: const StaminaDef(
          stamina: 5000,
          staminaMax: 5000,
          regenPerSecond100: 0,
        ),
      );

      final li = world.equippedLoadout.indexOf(player);
      world.equippedLoadout.mask[li] |= LoadoutSlotMask.projectile;
      world.equippedLoadout.spellBookId[li] = SpellBookId.basicSpellBook;
      world.equippedLoadout.abilityBonusId[li] = 'eloise.restore_mana';

      final pi = world.playerInput.indexOf(player);
      world.playerInput.bonusPressed[pi] = true;

      final activation = AbilityActivationSystem(
        tickHz: 60,
        inputBufferTicks: 10,
        abilities: const AbilityCatalog(),
        weapons: const WeaponCatalog(),
        projectileItems: const ProjectileItemCatalog(),
        spellBooks: const SpellBookCatalog(),
        accessories: const AccessoryCatalog(),
      );

      activation.step(world, player: player, currentTick: 5);

      expect(world.activeAbility.hasActiveAbility(player), isFalse);
      expect(
        world.selfIntent.tick[world.selfIntent.indexOf(player)],
        equals(-1),
      );
      expect(world.mana.mana[world.mana.indexOf(player)], equals(2000));
    },
  );
}
