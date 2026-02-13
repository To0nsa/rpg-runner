import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/combat/control_lock.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/active_ability_phase_system.dart';
import 'package:rpg_runner/core/ecs/systems/hold_ability_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/events/game_event.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';

void main() {
  const tickHz = 60;
  const commitTick = 10;

  EcsWorld makeWorld({required int stamina100}) {
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
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: StaminaDef(
        stamina: stamina100,
        staminaMax: stamina100,
        regenPerSecond100: 0,
      ),
    );

    final ability = AbilityCatalog.shared.resolve('eloise.sword_parry')!;
    world.activeAbility.set(
      player,
      id: ability.id,
      slot: AbilitySlot.primary,
      commitTick: commitTick,
      windupTicks: ability.windupTicks,
      activeTicks: ability.activeTicks,
      recoveryTicks: ability.recoveryTicks,
      facingDir: Facing.right,
      cooldownGroupId: ability.effectiveCooldownGroup(AbilitySlot.primary),
      cooldownTicks: ability.cooldownTicks,
      cooldownStarted: false,
    );

    return world;
  }

  test(
    'hold ability times out at max duration and emits timeout event once',
    () {
      final world = makeWorld(stamina100: 100000);
      final player = world.playerInput.denseEntities.single;
      final phase = ActiveAbilityPhaseSystem();
      final hold = HoldAbilitySystem(
        tickHz: tickHz,
        abilities: AbilityCatalog.shared,
      );
      final events = <GameEvent>[];

      final timeoutTick = commitTick + 2 + 180;
      for (var tick = commitTick; tick <= timeoutTick; tick += 1) {
        world.playerInput.setAbilitySlotHeld(player, AbilitySlot.primary, true);
        phase.step(world, currentTick: tick);
        hold.step(
          world,
          currentTick: tick,
          queueEvent: (event) => events.add(event),
        );
      }

      final timeoutEvents = events.whereType<AbilityHoldEndedEvent>().toList();
      expect(timeoutEvents.length, 1);
      final timeout = timeoutEvents.single;
      expect(timeout.reason, AbilityHoldEndReason.timeout);
      expect(timeout.tick, timeoutTick);
      expect(timeout.abilityId, 'eloise.sword_parry');

      final staminaIndex = world.stamina.indexOf(player);
      // 180 active ticks at 7.00 stamina/sec => floor(180 * 700 / 60) = 2100.
      expect(world.stamina.stamina[staminaIndex], 97900);
      expect(
        world.cooldown.getTicksLeft(player, CooldownGroup.primary),
        equals(
          AbilityCatalog.shared.resolve('eloise.sword_parry')!.cooldownTicks,
        ),
      );
    },
  );

  test('releasing hold ends the ability without auto-end vibration event', () {
    final world = makeWorld(stamina100: 1000);
    final player = world.playerInput.denseEntities.single;
    final phase = ActiveAbilityPhaseSystem();
    final hold = HoldAbilitySystem(
      tickHz: tickHz,
      abilities: AbilityCatalog.shared,
    );
    final events = <GameEvent>[];

    for (var tick = commitTick; tick <= commitTick + 30; tick += 1) {
      final held = tick <= commitTick + 12;
      world.playerInput.setAbilitySlotHeld(player, AbilitySlot.primary, held);
      phase.step(world, currentTick: tick);
      hold.step(
        world,
        currentTick: tick,
        queueEvent: (event) => events.add(event),
      );
    }

    expect(events.whereType<AbilityHoldEndedEvent>(), isEmpty);
    final activeIndex = world.activeAbility.indexOf(player);
    expect(world.activeAbility.phase[activeIndex], isNot(AbilityPhase.active));
    expect(world.activeAbility.activeTicks[activeIndex], 0);
    expect(
      world.cooldown.getTicksLeft(player, CooldownGroup.primary),
      equals(
        AbilityCatalog.shared.resolve('eloise.sword_parry')!.cooldownTicks,
      ),
    );
  });

  test('hold ability emits stamina-depleted event when drain reaches zero', () {
    final world = makeWorld(stamina100: 25);
    final player = world.playerInput.denseEntities.single;
    final phase = ActiveAbilityPhaseSystem();
    final hold = HoldAbilitySystem(
      tickHz: tickHz,
      abilities: AbilityCatalog.shared,
    );
    final events = <GameEvent>[];

    for (var tick = commitTick; tick <= commitTick + 120; tick += 1) {
      world.playerInput.setAbilitySlotHeld(player, AbilitySlot.primary, true);
      phase.step(world, currentTick: tick);
      hold.step(
        world,
        currentTick: tick,
        queueEvent: (event) => events.add(event),
      );
      if (events.whereType<AbilityHoldEndedEvent>().isNotEmpty) {
        break;
      }
    }

    final depletedEvents = events.whereType<AbilityHoldEndedEvent>().toList();
    expect(depletedEvents.length, 1);
    final depleted = depletedEvents.single;
    expect(depleted.reason, AbilityHoldEndReason.staminaDepleted);

    final staminaIndex = world.stamina.indexOf(player);
    expect(world.stamina.stamina[staminaIndex], 0);
    final activeIndex = world.activeAbility.indexOf(player);
    expect(world.activeAbility.phase[activeIndex], AbilityPhase.recovery);
    expect(
      world.cooldown.getTicksLeft(player, CooldownGroup.primary),
      equals(
        AbilityCatalog.shared.resolve('eloise.sword_parry')!.cooldownTicks,
      ),
    );
  });

  test('forced interruption starts deferred hold cooldown before clear', () {
    final world = makeWorld(stamina100: 1000);
    final player = world.playerInput.denseEntities.single;
    final phase = ActiveAbilityPhaseSystem();

    final tick = commitTick + 4;
    world.playerInput.setAbilitySlotHeld(player, AbilitySlot.primary, true);
    world.controlLock.addLock(player, LockFlag.stun, 5, tick);

    phase.step(world, currentTick: tick);

    final activeIndex = world.activeAbility.indexOf(player);
    expect(world.activeAbility.phase[activeIndex], AbilityPhase.idle);
    expect(
      world.cooldown.getTicksLeft(player, CooldownGroup.primary),
      equals(
        AbilityCatalog.shared.resolve('eloise.sword_parry')!.cooldownTicks,
      ),
    );
  });
}
