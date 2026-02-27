import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/combat/damage_type.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/combat/control_lock.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/stores/status/dot_store.dart';
import 'package:rpg_runner/core/ecs/stores/status/slow_store.dart';
import 'package:rpg_runner/core/ecs/systems/ability_activation_system.dart';
import 'package:rpg_runner/core/ecs/systems/self_ability_system.dart';
import 'package:rpg_runner/core/ecs/systems/status_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/spellBook/spell_book_catalog.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';

void main() {
  test(
    'spell-slot self spell commit consumes mana and starts spell cooldown',
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
      world.equippedLoadout.abilitySpellId[li] = 'eloise.arcane_haste';

      // Simulate spell input.
      final pi = world.playerInput.indexOf(player);
      world.playerInput.spellPressed[pi] = true;

      final system = AbilityActivationSystem(
        tickHz: 60,
        inputBufferTicks: 10,
        abilities: const AbilityCatalog(),
        weapons: const WeaponCatalog(),
        projectiles: const ProjectileCatalog(),
        spellBooks: const SpellBookCatalog(),
        accessories: const AccessoryCatalog(),
      );

      // Commit.
      system.step(world, player: player, currentTick: 5);

      // Verify active ability and commit side effects.
      expect(world.activeAbility.has(player), isTrue);
      final ai = world.activeAbility.indexOf(player);
      expect(world.activeAbility.abilityId[ai], equals('eloise.arcane_haste'));

      final ability = AbilityCatalog.shared.resolve('eloise.arcane_haste')!;
      expect(world.mana.mana[world.mana.indexOf(player)], equals(0));

      expect(
        world.cooldown.getTicksLeft(player, CooldownGroup.spell0),
        equals(ability.cooldownTicks),
      );
    },
  );

  test('restore mana self spell restores gradually and clamps to max', () {
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
    world.equippedLoadout.abilitySpellId[li] = 'eloise.mana_infusion';

    final pi = world.playerInput.indexOf(player);
    world.playerInput.spellPressed[pi] = true;

    final activation = AbilityActivationSystem(
      tickHz: 60,
      inputBufferTicks: 10,
      abilities: const AbilityCatalog(),
      weapons: const WeaponCatalog(),
      projectiles: const ProjectileCatalog(),
      spellBooks: const SpellBookCatalog(),
      accessories: const AccessoryCatalog(),
    );
    final selfAbility = SelfAbilitySystem();
    final status = StatusSystem(tickHz: 60);

    activation.step(world, player: player, currentTick: 5);
    selfAbility.step(world, currentTick: 5, queueStatus: status.queue);
    status.applyQueued(world, currentTick: 5);

    final ability = AbilityCatalog.shared.resolve('eloise.mana_infusion')!;
    final restoreProfile = const StatusProfileCatalog().get(
      ability.selfStatusProfileId,
    );
    final restoreApplication = restoreProfile.applications
        .where(
          (app) =>
              app.type == StatusEffectType.resourceOverTime &&
              app.resourceType == StatusResourceType.mana,
        )
        .first;
    final expectedRestoreBp = restoreApplication.magnitude;
    final durationTicks = (restoreApplication.durationSeconds * 60).ceil();
    final expectedRestore = (1000 * expectedRestoreBp) ~/ 10000;

    expect(world.mana.mana[world.mana.indexOf(player)], equals(200));

    for (var i = 0; i < durationTicks; i += 1) {
      status.tickExisting(world);
    }

    expect(
      world.mana.mana[world.mana.indexOf(player)],
      equals(200 + expectedRestore),
    );
    expect(
      world.stamina.stamina[world.stamina.indexOf(player)],
      equals(5000 - ability.defaultCost.staminaCost100),
    );

    // Re-cast after cooldown to verify clamping at max mana over time.
    world.cooldown.setTicksLeft(player, CooldownGroup.spell0, 0);
    world.activeAbility.clear(player);
    world.playerInput.spellPressed[pi] = true;
    activation.step(world, player: player, currentTick: 6);
    selfAbility.step(world, currentTick: 6, queueStatus: status.queue);
    status.applyQueued(world, currentTick: 6);

    expect(
      world.mana.mana[world.mana.indexOf(player)],
      equals(200 + expectedRestore),
    );
    for (var i = 0; i < durationTicks; i += 1) {
      status.tickExisting(world);
    }
    expect(world.mana.mana[world.mana.indexOf(player)], equals(900));

    world.cooldown.setTicksLeft(player, CooldownGroup.spell0, 0);
    world.activeAbility.clear(player);
    world.playerInput.spellPressed[pi] = true;
    activation.step(world, player: player, currentTick: 7);
    selfAbility.step(world, currentTick: 7, queueStatus: status.queue);
    status.applyQueued(world, currentTick: 7);

    for (var i = 0; i < durationTicks; i += 1) {
      status.tickExisting(world);
    }
    expect(world.mana.mana[world.mana.indexOf(player)], equals(1000));
  });

  test('Arcane Ward self spell applies damage reduction status', () {
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
        stamina: 1000,
        staminaMax: 1000,
        regenPerSecond100: 0,
      ),
    );

    final li = world.equippedLoadout.indexOf(player);
    world.equippedLoadout.mask[li] |= LoadoutSlotMask.projectile;
    world.equippedLoadout.spellBookId[li] = SpellBookId.epicSpellBook;
    world.equippedLoadout.abilitySpellId[li] = 'eloise.arcane_ward';

    final pi = world.playerInput.indexOf(player);
    world.playerInput.spellPressed[pi] = true;

    final activation = AbilityActivationSystem(
      tickHz: 60,
      inputBufferTicks: 10,
      abilities: const AbilityCatalog(),
      weapons: const WeaponCatalog(),
      projectiles: const ProjectileCatalog(),
      spellBooks: const SpellBookCatalog(),
      accessories: const AccessoryCatalog(),
    );
    final selfAbility = SelfAbilitySystem();
    final status = StatusSystem(tickHz: 60);

    activation.step(world, player: player, currentTick: 5);
    selfAbility.step(world, currentTick: 5, queueStatus: status.queue);
    status.applyQueued(world, currentTick: 5);

    expect(world.damageReduction.has(player), isTrue);
    final wardIndex = world.damageReduction.indexOf(player);
    expect(world.damageReduction.magnitude[wardIndex], equals(4000));
    expect(world.damageReduction.ticksLeft[wardIndex], equals(240));
    expect(world.mana.mana[world.mana.indexOf(player)], equals(800));
  });

  test(
    'Focus self spell increases projectile payload damage and crit chance',
    () {
      final baselineWorld = EcsWorld();
      final baselinePlayer = EntityFactory(baselineWorld).createPlayer(
        posX: 0,
        posY: 0,
        velX: 0,
        velY: 0,
        facing: Facing.right,
        grounded: true,
        body: const BodyDef(isKinematic: true, useGravity: false),
        collider: const ColliderAabbDef(halfX: 8, halfY: 8),
        health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
        mana: const ManaDef(mana: 5000, manaMax: 5000, regenPerSecond100: 0),
        stamina: const StaminaDef(
          stamina: 1000,
          staminaMax: 1000,
          regenPerSecond100: 0,
        ),
      );
      final baselineLoadoutIndex = baselineWorld.equippedLoadout.indexOf(
        baselinePlayer,
      );
      baselineWorld.equippedLoadout.mask[baselineLoadoutIndex] |=
          LoadoutSlotMask.projectile;
      baselineWorld.equippedLoadout.spellBookId[baselineLoadoutIndex] =
          SpellBookId.epicSpellBook;
      baselineWorld.equippedLoadout.abilityProjectileId[baselineLoadoutIndex] =
          'eloise.snap_shot';
      baselineWorld.equippedLoadout.abilitySpellId[baselineLoadoutIndex] =
          'eloise.focus';

      final baselineActivation = AbilityActivationSystem(
        tickHz: 60,
        inputBufferTicks: 10,
        abilities: const AbilityCatalog(),
        weapons: const WeaponCatalog(),
        projectiles: const ProjectileCatalog(),
        spellBooks: const SpellBookCatalog(),
        accessories: const AccessoryCatalog(),
      );

      final baselineInputIndex = baselineWorld.playerInput.indexOf(
        baselinePlayer,
      );
      baselineWorld.playerInput.projectilePressed[baselineInputIndex] = true;
      baselineActivation.step(
        baselineWorld,
        player: baselinePlayer,
        currentTick: 5,
      );
      baselineWorld.playerInput.projectilePressed[baselineInputIndex] = false;

      final baselineProjectileIndex = baselineWorld.projectileIntent.indexOf(
        baselinePlayer,
      );
      final baselineDamage =
          baselineWorld.projectileIntent.damage100[baselineProjectileIndex];
      final baselineCritChance =
          baselineWorld.projectileIntent.critChanceBp[baselineProjectileIndex];

      final focusWorld = EcsWorld();
      final focusPlayer = EntityFactory(focusWorld).createPlayer(
        posX: 0,
        posY: 0,
        velX: 0,
        velY: 0,
        facing: Facing.right,
        grounded: true,
        body: const BodyDef(isKinematic: true, useGravity: false),
        collider: const ColliderAabbDef(halfX: 8, halfY: 8),
        health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
        mana: const ManaDef(mana: 5000, manaMax: 5000, regenPerSecond100: 0),
        stamina: const StaminaDef(
          stamina: 1000,
          staminaMax: 1000,
          regenPerSecond100: 0,
        ),
      );
      final focusLoadoutIndex = focusWorld.equippedLoadout.indexOf(focusPlayer);
      focusWorld.equippedLoadout.mask[focusLoadoutIndex] |=
          LoadoutSlotMask.projectile;
      focusWorld.equippedLoadout.spellBookId[focusLoadoutIndex] =
          SpellBookId.epicSpellBook;
      focusWorld.equippedLoadout.abilityProjectileId[focusLoadoutIndex] =
          'eloise.snap_shot';
      focusWorld.equippedLoadout.abilitySpellId[focusLoadoutIndex] =
          'eloise.focus';

      final focusActivation = AbilityActivationSystem(
        tickHz: 60,
        inputBufferTicks: 10,
        abilities: const AbilityCatalog(),
        weapons: const WeaponCatalog(),
        projectiles: const ProjectileCatalog(),
        spellBooks: const SpellBookCatalog(),
        accessories: const AccessoryCatalog(),
      );
      final focusSelfAbility = SelfAbilitySystem();
      final focusStatus = StatusSystem(tickHz: 60);

      final focusInputIndex = focusWorld.playerInput.indexOf(focusPlayer);
      focusWorld.playerInput.spellPressed[focusInputIndex] = true;
      focusActivation.step(focusWorld, player: focusPlayer, currentTick: 5);
      focusWorld.playerInput.spellPressed[focusInputIndex] = false;

      focusSelfAbility.step(
        focusWorld,
        currentTick: 5,
        queueStatus: focusStatus.queue,
      );
      focusStatus.applyQueued(focusWorld, currentTick: 5);
      expect(focusWorld.offenseBuff.has(focusPlayer), isTrue);

      // Clear the utility active state so a projectile cast can commit immediately.
      focusWorld.activeAbility.clear(focusPlayer);

      focusWorld.playerInput.projectilePressed[focusInputIndex] = true;
      focusActivation.step(focusWorld, player: focusPlayer, currentTick: 6);
      focusWorld.playerInput.projectilePressed[focusInputIndex] = false;

      final focusProjectileIndex = focusWorld.projectileIntent.indexOf(
        focusPlayer,
      );
      final focusDamage =
          focusWorld.projectileIntent.damage100[focusProjectileIndex];
      final focusCritChance =
          focusWorld.projectileIntent.critChanceBp[focusProjectileIndex];

      expect(focusDamage, greaterThan(baselineDamage));
      expect(focusCritChance, equals(baselineCritChance + 1500));
    },
  );

  test('Cleanse self spell purges debuffs including stun', () {
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
        stamina: 1000,
        staminaMax: 1000,
        regenPerSecond100: 0,
      ),
    );

    world.dot.add(
      player,
      const DotDef(
        damageType: DamageType.fire,
        ticksLeft: 30,
        periodTicks: 1,
        dps100: 500,
      ),
    );
    world.slow.add(player, const SlowDef(ticksLeft: 30, magnitude: 2500));
    world.controlLock.addLock(player, LockFlag.stun, 30, 0);

    final li = world.equippedLoadout.indexOf(player);
    world.equippedLoadout.mask[li] |= LoadoutSlotMask.projectile;
    world.equippedLoadout.spellBookId[li] = SpellBookId.epicSpellBook;
    world.equippedLoadout.abilitySpellId[li] = 'eloise.cleanse';

    final pi = world.playerInput.indexOf(player);
    world.playerInput.spellPressed[pi] = true;

    final activation = AbilityActivationSystem(
      tickHz: 60,
      inputBufferTicks: 10,
      abilities: const AbilityCatalog(),
      weapons: const WeaponCatalog(),
      projectiles: const ProjectileCatalog(),
      spellBooks: const SpellBookCatalog(),
      accessories: const AccessoryCatalog(),
    );
    final selfAbility = SelfAbilitySystem();
    final status = StatusSystem(tickHz: 60);

    activation.step(world, player: player, currentTick: 5);
    selfAbility.step(
      world,
      currentTick: 5,
      queueStatus: status.queue,
      queuePurge: status.queuePurge,
    );
    status.tickExisting(world);

    expect(world.dot.has(player), isFalse);
    expect(world.slow.has(player), isFalse);
    expect(world.controlLock.isLocked(player, LockFlag.stun, 5), isFalse);
    expect(world.mana.mana[world.mana.indexOf(player)], equals(600));
  });

  test(
    'spell-slot self spell commit is blocked when spellbook does not grant it',
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
      world.equippedLoadout.abilitySpellId[li] = 'eloise.mana_infusion';

      final pi = world.playerInput.indexOf(player);
      world.playerInput.spellPressed[pi] = true;

      final activation = AbilityActivationSystem(
        tickHz: 60,
        inputBufferTicks: 10,
        abilities: const AbilityCatalog(),
        weapons: const WeaponCatalog(),
        projectiles: const ProjectileCatalog(),
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
