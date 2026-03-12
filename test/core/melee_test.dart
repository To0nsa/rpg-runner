import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/game_core.dart';
import '../support/test_level.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/stats/character_stats_resolver.dart';
import 'package:runner_core/util/tick_math.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';

import '../support/test_player.dart';
import '../test_tunings.dart';

void main() {
  test('melee: strike spawns hitbox for active ticks', () {
    final catalog = testPlayerCatalog(
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
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      seed: 1,
      tickHz: 60,
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
    final initialHud = core.buildSnapshot().hud;

    core.applyCommands(const [StrikePressedCommand(tick: 1)]);
    core.stepOneTick();

    final ability = const AbilityCatalog().resolve('eloise.bloodletter_slash');
    final windupTicks = ticksFromSecondsCeil(
      ability!.windupTicks / 60.0,
      core.tickHz,
    );
    final activeTicks = ticksFromSecondsCeil(
      ability.activeTicks / 60.0,
      core.tickHz,
    );
    final visibleTicks = activeTicks > 0 ? activeTicks - 1 : 0;

    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(<Command>[]);
      core.stepOneTick();
    }

    var snapshot = core.buildSnapshot();
    var hitboxes = snapshot.entities
        .where((e) => e.kind == EntityKind.trigger)
        .toList();
    expect(hitboxes.length, 1);
    final hitDelivery = ability.hitDelivery as MeleeHitDelivery;
    final hitboxHalfX = hitDelivery.sizeX * 0.5;
    final hitboxHalfY = hitDelivery.sizeY * 0.5;
    final forward =
        (catalog.colliderMaxHalfExtent * 0.5) +
        max(hitboxHalfX, hitboxHalfY) +
        hitDelivery.offsetX;
    expect(hitboxes.single.pos.x, closeTo(playerX + forward, 1e-9));
    expect(hitboxes.single.pos.y, closeTo(playerY, 1e-9));
    expect(
      snapshot.hud.stamina,
      closeTo(initialHud.stamina - abilityTuning.meleeStaminaCost, 1e-9),
    );
    final resolvedStats = const CharacterStatsResolver().resolveLoadout(
      EquippedLoadoutDef(
        mask: catalog.loadoutSlotMask,
        mainWeaponId: catalog.weaponId,
        offhandWeaponId: catalog.offhandWeaponId,
        spellBookId: catalog.spellBookId,
        projectileSlotSpellId: catalog.projectileSlotSpellId,
        abilityPrimaryId: catalog.abilityPrimaryId,
        abilitySecondaryId: catalog.abilitySecondaryId,
        abilityProjectileId: catalog.abilityProjectileId,
        abilitySpellId: catalog.abilitySpellId,
        abilityMobilityId: catalog.abilityMobilityId,
        abilityJumpId: catalog.abilityJumpId,
      ),
    );
    final expectedMeleeCooldownTicks = resolvedStats.applyCooldownReduction(
      ticksFromSecondsCeil(ability.cooldownTicks / 60.0, core.tickHz),
    );
    expect(
      core.playerMeleeCooldownTicksLeft,
      expectedMeleeCooldownTicks - windupTicks,
    );

    // Hitbox should exist for the active window (including the spawn tick).
    for (var t = 1; t < visibleTicks; t += 1) {
      core.applyCommands(<Command>[]);
      core.stepOneTick();
      snapshot = core.buildSnapshot();
      hitboxes = snapshot.entities
          .where((e) => e.kind == EntityKind.trigger)
          .toList();
      expect(hitboxes.length, 1, reason: 'tick=$t');
    }

    core.applyCommands(<Command>[]);
    core.stepOneTick(); // tick after active window
    snapshot = core.buildSnapshot();
    hitboxes = snapshot.entities
        .where((e) => e.kind == EntityKind.trigger)
        .toList();
    expect(hitboxes, isEmpty);
  });

  test('melee: uses aim direction when provided', () {
    final catalog = testPlayerCatalog(
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
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      seed: 1,
      tickHz: 60,
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
      AimDirCommand(tick: 1, x: 0, y: -1),
      StrikePressedCommand(tick: 1),
    ]);
    core.stepOneTick();

    final ability = const AbilityCatalog().resolve('eloise.bloodletter_slash')!;
    final windupTicks = ticksFromSecondsCeil(
      ability.windupTicks / 60.0,
      core.tickHz,
    );
    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(<Command>[]);
      core.stepOneTick();
    }

    final snapshot = core.buildSnapshot();
    final hitboxes = snapshot.entities
        .where((e) => e.kind == EntityKind.trigger)
        .toList();
    expect(hitboxes.length, 1);
    expect(hitboxes.single.pos.x, closeTo(playerX, 1e-9));
    final hitDelivery = ability.hitDelivery as MeleeHitDelivery;
    final hitboxHalfX = hitDelivery.sizeX * 0.5;
    final hitboxHalfY = hitDelivery.sizeY * 0.5;
    final forward =
        (catalog.colliderMaxHalfExtent * 0.5) +
        max(hitboxHalfX, hitboxHalfY) +
        hitDelivery.offsetX;
    expect(hitboxes.single.pos.y, closeTo(playerY - forward, 1e-9));
  });
}
