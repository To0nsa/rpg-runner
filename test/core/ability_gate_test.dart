import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_gate.dart';
import 'package:rpg_runner/core/combat/control_lock.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/control_lock_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';

void main() {
  group('AbilityGate', () {
    late EcsWorld world;

    setUp(() {
      world = EcsWorld();
    });

    test('Combat: Insufficient mana fails gate', () {
      final player = world.createEntity();
      world.mana.add(
        player,
        const ManaDef(mana: 10, manaMax: 100, regenPerSecond100: 0),
      );

      final result = AbilityGate.canCommitCombat(
        world,
        entity: player,
        currentTick: 0,
        cooldownGroupId: 0,
        manaCost100: 20, // Need 20, have 10
        staminaCost100: 0,
      );

      expect(result, equals(AbilityGateFail.insufficientMana));
    });

    test('Combat: On Cooldown fails gate', () {
      final player = world.createEntity();
      world.cooldown.add(player);
      world.cooldown.startCooldown(player, 0, 10);

      final result = AbilityGate.canCommitCombat(
        world,
        entity: player,
        currentTick: 5,
        cooldownGroupId: 0,
        manaCost100: 0,
        staminaCost100: 0,
      );
      expect(result, equals(AbilityGateFail.onCooldown));
    });

    test('Combat: Stunned fails gate', () {
      final player = world.createEntity();
      world.controlLock.addLock(player, LockFlag.stun, 10, 0);

      final result = AbilityGate.canCommitCombat(
        world,
        entity: player,
        currentTick: 5,
        cooldownGroupId: 0,
        manaCost100: 0,
        staminaCost100: 0,
      );
      expect(result, equals(AbilityGateFail.stunned));
    });

    test('Mobility: Dash already active fails gate', () {
      final player = world.createEntity();
      world.movement.add(player, facing: Facing.right);
      // Ensure body is enabled/not-kinematic for standard mobility check
      world.body.add(player, const BodyDef(enabled: true, isKinematic: false));

      world.movement.dashTicksLeft[world.movement.indexOf(player)] = 5;

      final result = AbilityGate.canCommitMobility(
        world,
        entity: player,
        currentTick: 0,
        cooldownGroupId: 0,
        staminaCost100: 0,
      );
      expect(result, equals(AbilityGateFail.dashAlreadyActive));
    });

    test('Mobility: Aiming held fails gate', () {
      final player = world.createEntity();
      world.movement.add(player, facing: Facing.right);
      world.body.add(player, const BodyDef(enabled: true, isKinematic: false));
      world.playerInput.add(player);

      final i = world.playerInput.indexOf(player);
      world.playerInput.projectileAimDirX[i] = 1.0;

      final result = AbilityGate.canCommitMobility(
        world,
        entity: player,
        currentTick: 0,
        cooldownGroupId: 0,
        staminaCost100: 0,
      );
      expect(result, equals(AbilityGateFail.aimingHeld));
    });
  });
}
