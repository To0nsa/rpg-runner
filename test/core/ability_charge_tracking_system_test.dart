import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/ability_charge_tracking_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/events/game_event.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';

void main() {
  test(
    'tracks hold duration and captures release duration on release tick',
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
        health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
        mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
        stamina: const StaminaDef(
          stamina: 0,
          staminaMax: 0,
          regenPerSecond100: 0,
        ),
      );
      final system = AbilityChargeTrackingSystem(
        tickHz: 60,
        abilities: AbilityCatalog.shared,
      );

      const slot = AbilitySlot.projectile;

      system.step(world, currentTick: 10);
      expect(
        world.abilityCharge.commitChargeTicksOrUntracked(
          player,
          slot: slot,
          currentTick: 10,
        ),
        equals(-1),
      );

      world.playerInput.setAbilitySlotHeld(player, slot, true);
      system.step(world, currentTick: 11);
      expect(world.abilityCharge.currentHoldTicks(player, slot), equals(0));

      system.step(world, currentTick: 12);
      system.step(world, currentTick: 13);
      system.step(world, currentTick: 14);
      expect(world.abilityCharge.currentHoldTicks(player, slot), equals(3));
      expect(
        world.abilityCharge.commitChargeTicksOrUntracked(
          player,
          slot: slot,
          currentTick: 14,
        ),
        equals(3),
      );

      world.playerInput.setAbilitySlotHeld(player, slot, false);
      system.step(world, currentTick: 15);
      expect(world.abilityCharge.currentHoldTicks(player, slot), equals(0));
      expect(
        world.abilityCharge.commitChargeTicksOrUntracked(
          player,
          slot: slot,
          currentTick: 15,
        ),
        equals(4),
      );
      expect(
        world.abilityCharge.commitChargeTicksOrUntracked(
          player,
          slot: slot,
          currentTick: 16,
        ),
        equals(-1),
      );
    },
  );

  test('charged hold auto-cancels on authored timeout and emits event', () {
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
      health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );
    final loadoutIndex = world.equippedLoadout.indexOf(player);
    world.equippedLoadout.abilityProjectileId[loadoutIndex] =
        'eloise.charged_shot';

    final system = AbilityChargeTrackingSystem(
      tickHz: 60,
      abilities: AbilityCatalog.shared,
    );
    final events = <GameEvent>[];

    const slot = AbilitySlot.projectile;
    world.playerInput.setAbilitySlotHeld(player, slot, true);
    for (var tick = 1; tick <= 181; tick += 1) {
      system.step(world, currentTick: tick, queueEvent: events.add);
    }

    expect(world.playerInput.isAbilitySlotHeld(player, slot), isFalse);
    expect(world.abilityCharge.slotHeld(player, slot), isFalse);
    expect(world.abilityCharge.slotChargeCanceled(player, slot), isTrue);
    expect(events.whereType<AbilityChargeEndedEvent>().length, equals(1));
    final event = events.whereType<AbilityChargeEndedEvent>().single;
    expect(event.slot, equals(slot));
    expect(event.abilityId, equals('eloise.charged_shot'));
    expect(event.reason, equals(AbilityChargeEndReason.timeout));
  });
}
