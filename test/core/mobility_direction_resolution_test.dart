import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/combat/faction.dart';
import 'package:rpg_runner/core/ecs/entity_id.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/faction_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/ability_activation_system.dart';
import 'package:rpg_runner/core/ecs/systems/ability_charge_tracking_system.dart';
import 'package:rpg_runner/core/ecs/systems/mobility_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/spellBook/spell_book_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';

void main() {
  test(
    'directional mobility falls back to movement axis when aim is unset',
    () {
      final world = EcsWorld();
      final system = _buildSystem();
      final player = _spawnPlayer(
        world,
        abilityMobilityId: 'test.mobility_directional',
      );
      final inputIndex = world.playerInput.indexOf(player);
      world.playerInput.moveAxis[inputIndex] = -1.0;
      world.playerInput.dashPressed[inputIndex] = true;

      system.step(world, player: player, currentTick: 1);

      final mobilityIndex = world.mobilityIntent.indexOf(player);
      expect(world.mobilityIntent.dirX[mobilityIndex], closeTo(-1.0, 1e-9));
      expect(world.mobilityIntent.dirY[mobilityIndex].abs(), lessThan(1e-9));
    },
  );

  test(
    'aimed mobility normalizes authored aim direction deterministically',
    () {
      (double, double) commitDir() {
        final world = EcsWorld();
        final system = _buildSystem();
        final player = _spawnPlayer(
          world,
          abilityMobilityId: 'test.mobility_aimed',
        );
        final inputIndex = world.playerInput.indexOf(player);
        world.playerInput.aimDirX[inputIndex] = 2.0;
        world.playerInput.aimDirY[inputIndex] = -2.0;
        world.playerInput.dashPressed[inputIndex] = true;

        system.step(world, player: player, currentTick: 1);

        final mobilityIndex = world.mobilityIntent.indexOf(player);
        return (
          world.mobilityIntent.dirX[mobilityIndex],
          world.mobilityIntent.dirY[mobilityIndex],
        );
      }

      final runA = commitDir();
      final runB = commitDir();
      expect(runA.$1, closeTo(0.70710678, 1e-6));
      expect(runA.$2, closeTo(-0.70710678, 1e-6));
      expect(runB.$1, closeTo(runA.$1, 1e-9));
      expect(runB.$2, closeTo(runA.$2, 1e-9));
    },
  );

  test(
    'homing mobility chooses deterministic nearest hostile and executes vector dash',
    () {
      final world = EcsWorld();
      final activation = _buildSystem();
      final mobility = MobilitySystem();
      final tuning = MovementTuningDerived.from(
        const MovementTuning(),
        tickHz: 60,
      );
      final player = _spawnPlayer(
        world,
        abilityMobilityId: 'test.mobility_homing',
      );
      _spawnEnemy(world, x: 130, y: 140); // first spawned, wins tie
      _spawnEnemy(world, x: 130, y: 60); // same distance, larger entity id

      final inputIndex = world.playerInput.indexOf(player);
      world.playerInput.dashPressed[inputIndex] = true;

      activation.step(world, player: player, currentTick: 1);
      final mobilityIndex = world.mobilityIntent.indexOf(player);
      expect(world.mobilityIntent.dirX[mobilityIndex], closeTo(0.6, 1e-9));
      expect(world.mobilityIntent.dirY[mobilityIndex], closeTo(0.8, 1e-9));

      mobility.step(world, tuning, currentTick: 1);

      final transformIndex = world.transform.indexOf(player);
      final velX = world.transform.velX[transformIndex];
      final velY = world.transform.velY[transformIndex];
      expect(velX, greaterThan(0));
      expect(velY, greaterThan(0));
      expect(velX / velY, closeTo(0.75, 1e-6));
    },
  );

  test(
    'hold-maintain homing tiered mobility resolves deterministic direction and commit tier from authoritative hold ticks',
    () {
      (int speedScaleBp, double dirX, double dirY) commitIntentForHoldTicks(
        int heldTicks,
      ) {
        final world = EcsWorld();
        const abilities = _MobilityDirectionAbilities();
        final activation = AbilityActivationSystem(
          tickHz: 60,
          inputBufferTicks: 8,
          abilities: abilities,
          weapons: const WeaponCatalog(),
          projectiles: const ProjectileCatalog(),
          spellBooks: const SpellBookCatalog(),
          accessories: const AccessoryCatalog(),
        );
        final chargeTracking = AbilityChargeTrackingSystem(
          tickHz: 60,
          abilities: abilities,
        );
        final player = _spawnPlayer(
          world,
          abilityMobilityId: 'eloise.hold_auto_dash',
        );
        _spawnEnemy(world, x: 130, y: 140); // dx=30, dy=40

        final inputIndex = world.playerInput.indexOf(player);

        var tick = 1;
        world.playerInput.setAbilitySlotHeld(
          player,
          AbilitySlot.mobility,
          true,
        );
        chargeTracking.step(world, currentTick: tick);
        for (var i = 0; i < heldTicks; i += 1) {
          tick += 1;
          world.playerInput.setAbilitySlotHeld(
            player,
            AbilitySlot.mobility,
            true,
          );
          chargeTracking.step(world, currentTick: tick);
        }

        tick += 1;
        world.playerInput.setAbilitySlotHeld(
          player,
          AbilitySlot.mobility,
          true,
        );
        chargeTracking.step(world, currentTick: tick);
        world.playerInput.dashPressed[inputIndex] = true;
        activation.step(world, player: player, currentTick: tick);

        final mobilityIndex = world.mobilityIntent.indexOf(player);
        return (
          world.mobilityIntent.speedScaleBp[mobilityIndex],
          world.mobilityIntent.dirX[mobilityIndex],
          world.mobilityIntent.dirY[mobilityIndex],
        );
      }

      final shortHold = commitIntentForHoldTicks(0);
      final longHoldA = commitIntentForHoldTicks(20);
      final longHoldB = commitIntentForHoldTicks(20);

      expect(shortHold.$1, equals(9000));
      expect(longHoldA.$1, equals(12400));
      expect(longHoldA.$1, greaterThan(shortHold.$1));

      expect(shortHold.$2, closeTo(0.6, 1e-9));
      expect(shortHold.$3, closeTo(0.8, 1e-9));
      expect(longHoldA.$2, closeTo(0.6, 1e-9));
      expect(longHoldA.$3, closeTo(0.8, 1e-9));
      expect(longHoldB.$1, equals(longHoldA.$1));
      expect(longHoldB.$2, closeTo(longHoldA.$2, 1e-9));
      expect(longHoldB.$3, closeTo(longHoldA.$3, 1e-9));
    },
  );
}

AbilityActivationSystem _buildSystem() {
  return AbilityActivationSystem(
    tickHz: 60,
    inputBufferTicks: 8,
    abilities: const _MobilityDirectionAbilities(),
    weapons: const WeaponCatalog(),
    projectiles: const ProjectileCatalog(),
    spellBooks: const SpellBookCatalog(),
    accessories: const AccessoryCatalog(),
  );
}

EntityId _spawnPlayer(EcsWorld world, {required String abilityMobilityId}) {
  final player = world.createEntity();
  world.transform.add(player, posX: 100, posY: 100, velX: 0, velY: 0);
  world.faction.add(player, const FactionDef(faction: Faction.player));
  world.health.add(
    player,
    const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
  );
  world.playerInput.add(player);
  world.movement.add(player, facing: Facing.right);
  world.body.add(
    player,
    const BodyDef(isKinematic: false, useGravity: false, enabled: true),
  );
  world.abilityInputBuffer.add(player);
  world.abilityCharge.add(player);
  world.activeAbility.add(player);
  world.cooldown.add(player);
  world.stamina.add(
    player,
    const StaminaDef(stamina: 1000, staminaMax: 1000, regenPerSecond100: 0),
  );
  world.mobilityIntent.add(player);
  world.equippedLoadout.add(
    player,
    EquippedLoadoutDef(
      mask: LoadoutSlotMask.all,
      abilityMobilityId: abilityMobilityId,
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

class _MobilityDirectionAbilities extends AbilityCatalog {
  const _MobilityDirectionAbilities();

  @override
  AbilityDef? resolve(AbilityKey key) {
    switch (key) {
      case 'test.mobility_directional':
        return const AbilityDef(
          id: 'test.mobility_directional',
          category: AbilityCategory.mobility,
          allowedSlots: {AbilitySlot.mobility},
          targetingModel: TargetingModel.directional,
          inputLifecycle: AbilityInputLifecycle.tap,
          hitDelivery: SelfHitDelivery(),
          windupTicks: 0,
          activeTicks: 8,
          recoveryTicks: 0,
          defaultCost: AbilityResourceCost(staminaCost100: 0, manaCost100: 0),
          cooldownTicks: 0,
          animKey: AnimKey.dash,
          baseDamage: 0,
        );
      case 'test.mobility_aimed':
        return const AbilityDef(
          id: 'test.mobility_aimed',
          category: AbilityCategory.mobility,
          allowedSlots: {AbilitySlot.mobility},
          targetingModel: TargetingModel.aimed,
          inputLifecycle: AbilityInputLifecycle.tap,
          hitDelivery: SelfHitDelivery(),
          windupTicks: 0,
          activeTicks: 8,
          recoveryTicks: 0,
          defaultCost: AbilityResourceCost(staminaCost100: 0, manaCost100: 0),
          cooldownTicks: 0,
          animKey: AnimKey.dash,
          baseDamage: 0,
        );
      case 'test.mobility_homing':
        return const AbilityDef(
          id: 'test.mobility_homing',
          category: AbilityCategory.mobility,
          allowedSlots: {AbilitySlot.mobility},
          targetingModel: TargetingModel.homing,
          inputLifecycle: AbilityInputLifecycle.tap,
          hitDelivery: SelfHitDelivery(),
          windupTicks: 0,
          activeTicks: 8,
          recoveryTicks: 0,
          defaultCost: AbilityResourceCost(staminaCost100: 0, manaCost100: 0),
          cooldownTicks: 0,
          animKey: AnimKey.dash,
          baseDamage: 0,
        );
      default:
        return super.resolve(key);
    }
  }
}
