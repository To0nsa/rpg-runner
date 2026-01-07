import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/commands/command.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/players/player_catalog.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/tuning/ability_tuning.dart';
import 'package:walkscape_runner/core/tuning/resource_tuning.dart';

import '../test_tunings.dart';

void main() {
  test('melee: attack spawns hitbox for active ticks', () {
    const abilityTuning = AbilityTuning();
    const resourceTuning = ResourceTuning(
      playerStaminaMax: 100,
      playerStaminaRegenPerSecond: 0,
      playerManaRegenPerSecond: 0,
      playerHpRegenPerSecond: 0,
    );
    final abilityDerived = AbilityTuningDerived.from(
      abilityTuning,
      tickHz: 60,
    );
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: 60,
      playerCatalog: const PlayerCatalog(
        bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
      ),
      cameraTuning: noAutoscrollCameraTuning,
      resourceTuning: resourceTuning,
      abilityTuning: abilityTuning,
    );

    final playerX = core.playerPosX;
    final playerY = core.playerPosY;

    core.applyCommands(const [AttackPressedCommand(tick: 1)]);
    core.stepOneTick();

    var snapshot = core.buildSnapshot();
    var hitboxes = snapshot.entities
        .where((e) => e.kind == EntityKind.trigger)
        .toList();
    expect(hitboxes.length, 1);
    expect(hitboxes.single.pos.x, closeTo(playerX + 20.0, 1e-9));
    expect(hitboxes.single.pos.y, closeTo(playerY, 1e-9));
    expect(
      snapshot.hud.stamina,
      closeTo(
        resourceTuning.playerStaminaMax - abilityTuning.meleeStaminaCost,
        1e-9,
      ),
    );
    expect(core.playerMeleeCooldownTicksLeft, abilityDerived.meleeCooldownTicks);

    // Hitbox should exist for 6 ticks total (including the spawn tick).
    for (var t = 2; t <= 5; t += 1) {
      core.applyCommands(<Command>[]);
      core.stepOneTick();
      snapshot = core.buildSnapshot();
      hitboxes = snapshot.entities
          .where((e) => e.kind == EntityKind.trigger)
          .toList();
      expect(hitboxes.length, 1, reason: 'tick=$t');
    }

    core.applyCommands(<Command>[]);
    core.stepOneTick(); // tick 6
    snapshot = core.buildSnapshot();
    hitboxes = snapshot.entities
        .where((e) => e.kind == EntityKind.trigger)
        .toList();
    expect(hitboxes, isEmpty);
  });

  test('melee: uses aim direction when provided', () {
    const abilityTuning = AbilityTuning();
    const resourceTuning = ResourceTuning(
      playerStaminaMax: 100,
      playerStaminaRegenPerSecond: 0,
      playerManaRegenPerSecond: 0,
      playerHpRegenPerSecond: 0,
    );
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: 60,
      playerCatalog: const PlayerCatalog(
        bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
      ),
      cameraTuning: noAutoscrollCameraTuning,
      resourceTuning: resourceTuning,
      abilityTuning: abilityTuning,
    );

    final playerX = core.playerPosX;
    final playerY = core.playerPosY;

    core.applyCommands(const [
      MeleeAimDirCommand(tick: 1, x: 0, y: -1),
      AttackPressedCommand(tick: 1),
    ]);
    core.stepOneTick();

    final snapshot = core.buildSnapshot();
    final hitboxes = snapshot.entities
        .where((e) => e.kind == EntityKind.trigger)
        .toList();
    expect(hitboxes.length, 1);
    expect(hitboxes.single.pos.x, closeTo(playerX, 1e-9));
    expect(hitboxes.single.pos.y, closeTo(playerY - 20.0, 1e-9));
  });
}
