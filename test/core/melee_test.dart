import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/commands/command.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/game_core.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/players/player_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';

import '../test_tunings.dart';

void main() {
  test('melee: attack spawns hitbox for active ticks', () {
    const catalog = PlayerCatalog(
      bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
    );
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
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 60,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: catalog,
        tuning: base.tuning.copyWith(
          resource: resourceTuning,
          ability: abilityTuning,
        ),
      ),
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
    final hitboxHalfX = abilityTuning.meleeHitboxSizeX * 0.5;
    final hitboxHalfY = abilityTuning.meleeHitboxSizeY * 0.5;
    final forward = (catalog.colliderMaxHalfExtent * 0.5) + max(hitboxHalfX, hitboxHalfY);
    expect(hitboxes.single.pos.x, closeTo(playerX + forward, 1e-9));
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
    const catalog = PlayerCatalog(
      bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
    );
    const abilityTuning = AbilityTuning();
    const resourceTuning = ResourceTuning(
      playerStaminaMax: 100,
      playerStaminaRegenPerSecond: 0,
      playerManaRegenPerSecond: 0,
      playerHpRegenPerSecond: 0,
    );
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 60,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: catalog,
        tuning: base.tuning.copyWith(
          resource: resourceTuning,
          ability: abilityTuning,
        ),
      ),
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
    final hitboxHalfX = abilityTuning.meleeHitboxSizeX * 0.5;
    final hitboxHalfY = abilityTuning.meleeHitboxSizeY * 0.5;
    final forward = (catalog.colliderMaxHalfExtent * 0.5) + max(hitboxHalfX, hitboxHalfY);
    expect(hitboxes.single.pos.y, closeTo(playerY - forward, 1e-9));
  });
}
