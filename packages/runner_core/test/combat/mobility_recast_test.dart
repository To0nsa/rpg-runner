import 'package:test/test.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/accessories/accessory_catalog.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/ability_activation_system.dart';
import 'package:runner_core/ecs/systems/mobility_system.dart';
import 'package:runner_core/ecs/systems/player_movement_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spellBook/spell_book_catalog.dart';
import 'package:runner_core/weapons/weapon_catalog.dart';

void main() {
  test('two separate costs and directions, one cooldown, no third burst', () {
    final h = _Harness();
    h.step(press: true);
    expect(h.stamina, 800);
    final firstCooldown = h.cooldown;
    expect(firstCooldown, greaterThan(0));
    h.advanceTo(8, press: true); // Repeated presses cannot overlap burst one.
    expect(h.stamina, 800);
    h.step(press: true, axis: -1);
    expect(h.stamina, 600);
    expect(h.cooldown, firstCooldown - 8);
    expect(h.world.transform.velX[h.ti], -515.625);
    expect(h.world.movement.recastAbilityId[h.mi], isNull);
    h.advanceTo(18, press: true);
    expect(h.stamina, 600);
    h.advanceTo(firstCooldown);
    h.step(press: true);
    expect(h.stamina, 400);
    expect(h.cooldown, firstCooldown);
  });

  for (final tickHz in [60, 120]) {
    test('follow-up window is half-open and scales at $tickHz Hz', () {
      final factor = tickHz ~/ 60;
      final last = 1 + (8 + 30) * factor - 1;
      final accepted = _Harness(tickHz: tickHz)..step(press: true);
      accepted.advanceTo(last - 1);
      accepted.step(press: true);
      expect(accepted.stamina, 600);
      final expired = _Harness(tickHz: tickHz)..step(press: true);
      expired.advanceTo(last);
      expired.step(press: true);
      expect(expired.stamina, 800);
      expect(expired.world.movement.recastAbilityId[expired.mi], isNull);
    });
  }

  test(
    'failed resource check retains follow-up without spending or refreshing',
    () {
      final h = _Harness()..step(press: true);
      final firstCooldown = h.cooldown;
      h.advanceTo(8);
      h.world.stamina.stamina[h.si] = 100;
      h.step(press: true);
      expect(h.stamina, 100);
      expect(h.cooldown, firstCooldown - 8);
      h.world.stamina.stamina[h.si] = 200;
      h.step(press: true);
      expect(h.stamina, 0);
      expect(h.cooldown, firstCooldown - 9);
    },
  );

  for (final cause in ['stun', 'water', 'loadout']) {
    test('$cause cancels the earned follow-up', () {
      final h = _Harness()..step(press: true);
      h.advanceTo(8);
      switch (cause) {
        case 'stun':
          h.world.controlLock.addLock(h.player, LockFlag.stun, 1, 9);
        case 'water':
          h.world.swimState.add(h.player);
          h.world.swimState.setImmersion(0, 1000);
        case 'loadout':
          h.world.equippedLoadout.abilityMobilityId[0] = 'eloise.dash';
      }
      h.step(press: true);
      expect(h.stamina, 800);
      expect(h.world.movement.recastAbilityId[h.mi], isNull);
      if (cause == 'water') h.world.swimState.setImmersion(0, 0);
      h.world.equippedLoadout.abilityMobilityId[0] = 'eloise.double_dash';
      h.step(press: true);
      expect(h.stamina, 800);
    });
  }

  test(
    'movement swap removal and recycled entities cannot inherit follow-ups',
    () {
      final h = _Harness()..step(press: true);
      final other = h.world.createEntity();
      h.world.movement.add(other, facing: Facing.left);
      h.world.movement.armRecast(other, 'other', 5, 10);
      h.world.destroyEntity(h.player);
      expect(h.world.movement.canRecast(other, 'other', 6), isTrue);
      final recycled = h.world.createEntity();
      h.world.movement.add(recycled, facing: Facing.right);
      expect(
        h.world.movement.canRecast(recycled, 'eloise.double_dash', 9),
        isFalse,
      );
    },
  );

  test('ordinary Dash and Roll do not earn follow-ups', () {
    for (final id in ['eloise.dash', 'eloise.roll']) {
      final h = _Harness(ability: id)..step(press: true);
      h.advanceTo(20, press: true);
      expect(h.stamina, 800);
      expect(h.world.movement.recastAbilityId[h.mi], isNull);
    }
  });
}

class _Harness {
  _Harness({this.tickHz = 60, String ability = 'eloise.double_dash'}) {
    player = world.createEntity();
    world.transform.add(player, posX: 0, posY: 0, velX: 0, velY: 0);
    world.health.add(
      player,
      const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
    );
    world.playerInput.add(player);
    world.movement.add(player, facing: Facing.right);
    world.body.add(player, const BodyDef(useGravity: false));
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
      EquippedLoadoutDef(abilityMobilityId: ability),
    );
    activation = AbilityActivationSystem(
      tickHz: tickHz,
      inputBufferTicks: 8,
      abilities: const AbilityCatalog(),
      weapons: const WeaponCatalog(),
      projectiles: const ProjectileCatalog(),
      spellBooks: const SpellBookCatalog(),
      accessories: const AccessoryCatalog(),
    );
    tuning = MovementTuningDerived.from(const MovementTuning(), tickHz: tickHz);
  }

  final int tickHz;
  final world = EcsWorld();
  late final int player;
  late final AbilityActivationSystem activation;
  late final MovementTuningDerived tuning;
  final movement = PlayerMovementSystem();
  final mobility = MobilitySystem();
  int tick = 0;
  int get mi => world.movement.indexOf(player);
  int get ti => world.transform.indexOf(player);
  int get si => world.stamina.indexOf(player);
  int get stamina => world.stamina.stamina[si];
  int get cooldown =>
      world.cooldown.getTicksLeft(player, CooldownGroup.mobility);

  void step({bool press = false, double axis = 0}) {
    tick++;
    world.cooldown.tickAll();
    final ii = world.playerInput.indexOf(player);
    world.playerInput.dashPressed[ii] = press;
    world.playerInput.moveAxis[ii] = axis;
    activation.step(world, player: player, currentTick: tick);
    movement.step(world, tuning, currentTick: tick);
    mobility.step(world, tuning, currentTick: tick);
  }

  void advanceTo(int target, {bool press = false}) {
    while (tick < target) {
      step(press: press);
    }
  }
}
