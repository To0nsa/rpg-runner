import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/game_core.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/util/tick_math.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';

import 'support/test_player.dart';
import 'test_tunings.dart';

void main() {
  test('move axis release overwrites buffered future ticks', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 60,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: testPlayerCatalog(
          bodyTemplate: BodyDef(useGravity: false),
          projectileId: ProjectileId.iceBolt,
          abilityProjectileId: 'eloise.charged_shot',
        ),
        tuning: base.tuning.copyWith(
          movement: const MovementTuning(
            maxSpeedX: 100,
            accelerationX: 100000,
            decelerationX: 100000,
            minMoveSpeed: 0,
          ),
        ),
      ),
    );
    final controller = GameController(core: core);
    final input = RunnerInputRouter(controller: controller);

    final dt = 1.0 / controller.tickHz;

    input.setMoveAxis(1);
    input.pumpHeldInputs();
    controller.advanceFrame(dt);
    expect(core.tick, 1);
    expect(core.playerVelX, greaterThan(0));

    input.setMoveAxis(0);
    input.pumpHeldInputs();
    controller.advanceFrame(dt);
    expect(core.tick, 2);

    // With a huge deceleration, releasing move input should stop immediately.
    expect(core.playerVelX, closeTo(0.0, 1e-9));
  });

  test(
    'primary hold uses edge commands and stays latched until explicit release',
    () {
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        seed: 1,
        tickHz: 60,
        tuning: noAutoscrollTuning,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(useGravity: false),
            abilityPrimaryId: 'eloise.sword_riposte_guard',
            projectileId: ProjectileId.iceBolt,
            abilityProjectileId: 'eloise.charged_shot',
          ),
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerStaminaMax: 50,
              playerStaminaRegenPerSecond: 0,
            ),
          ),
        ),
      );
      final controller = GameController(core: core);
      final input = RunnerInputRouter(controller: controller);

      final dt = 1.0 / controller.tickHz;

      // Emit a single hold-start edge. No per-frame hold commands follow.
      input.startPrimaryHold();
      input.pumpHeldInputs();
      controller.advanceFrame(dt);

      for (var i = 0; i < 20; i += 1) {
        input.pumpHeldInputs();
        controller.advanceFrame(dt);
      }

      // If hold state were reset each tick, cooldown would have started already.
      expect(core.playerMeleeCooldownTicksLeft, equals(0));

      // Release with a single hold-end edge and verify cooldown starts.
      input.endPrimaryHold();
      input.pumpHeldInputs();
      controller.advanceFrame(dt);

      expect(core.playerMeleeCooldownTicksLeft, greaterThan(0));
    },
  );

  test(
    'projectile aim clear overwrites buffered future ticks (affects projectile direction)',
    () {
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        seed: 1,
        tickHz: 60,
        tuning: noAutoscrollTuning,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(useGravity: false),
            projectileId: ProjectileId.iceBolt,
            abilityProjectileId: 'eloise.charged_shot',
          ),
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerManaMax: 20,
              playerManaRegenPerSecond: 0,
            ),
          ),
        ),
      );
      final controller = GameController(core: core);
      final input = RunnerInputRouter(controller: controller);

      final dt = 1.0 / controller.tickHz;
      final windupTicks = ticksFromSecondsCeil(
        AbilityCatalog.shared.resolve('eloise.charged_shot')!.windupTicks /
            60.0,
        controller.tickHz,
      );

      // Hold aim straight down for a frame; this will pre-buffer projectile aim
      // direction for upcoming ticks.
      input.setAimDir(0, 1);
      input.pumpHeldInputs();
      controller.advanceFrame(dt);
      expect(core.tick, 1);

      // Release aim and cast without setting a new aim direction. Cast should
      // fall back to facing (right), not the previously buffered aim.
      input.clearAimDir();
      input.pressProjectile();
      for (var i = 0; i < windupTicks + 2; i += 1) {
        input.pumpHeldInputs();
        controller.advanceFrame(dt);
      }

      final snapshot = core.buildSnapshot();
      final projectiles = snapshot.entities
          .where((e) => e.kind == EntityKind.projectile)
          .toList();
      expect(projectiles.length, 1);
      final projectile = projectiles.single;

      expect(projectile.vel, isNotNull);
      expect(projectile.vel!.x, greaterThan(0));
      expect(projectile.vel!.y.abs(), lessThan(1e-9));
    },
  );

  test('release-to-cast keeps aimed dir for the cast tick', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 60,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: testPlayerCatalog(
          bodyTemplate: BodyDef(useGravity: false),
          projectileId: ProjectileId.iceBolt,
          abilityProjectileId: 'eloise.charged_shot',
        ),
        tuning: base.tuning.copyWith(
          resource: const ResourceTuning(
            playerManaMax: 20,
            playerManaRegenPerSecond: 0,
          ),
        ),
      ),
    );
    final controller = GameController(core: core);
    final input = RunnerInputRouter(controller: controller);

    final dt = 1.0 / controller.tickHz;
    final windupTicks = ticksFromSecondsCeil(
      AbilityCatalog.shared.resolve('eloise.charged_shot')!.windupTicks / 60.0,
      controller.tickHz,
    );

    input.setAimDir(0, -1);
    input.commitProjectileWithAim(clearAim: true);

    for (var i = 0; i < windupTicks + 2; i += 1) {
      input.pumpHeldInputs();
      controller.advanceFrame(dt);
    }

    final snapshot = core.buildSnapshot();
    final projectiles = snapshot.entities
        .where((e) => e.kind == EntityKind.projectile)
        .toList();
    expect(projectiles.length, 1);
    final projectile = projectiles.single;

    expect(projectile.vel, isNotNull);
    expect(projectile.vel!.y, lessThan(0));
    expect(projectile.vel!.x.abs(), lessThan(1e-6));
  });

  test(
    'release-to-cast without slot hold remains at tap tier regardless of aim hold duration',
    () {
      double launchSpeedForAimHoldTicks(int aimHoldTicks) {
        final base = PlayerCharacterRegistry.eloise;
        final core = GameCore(
          seed: 1,
          tickHz: 60,
          tuning: noAutoscrollTuning,
          playerCharacter: base.copyWith(
            catalog: testPlayerCatalog(
              bodyTemplate: BodyDef(useGravity: false),
              projectileId: ProjectileId.throwingKnife,
              projectileSlotSpellId: null,
              abilityProjectileId: 'eloise.charged_shot',
            ),
            tuning: base.tuning.copyWith(
              resource: const ResourceTuning(
                playerManaMax: 20,
                playerManaRegenPerSecond: 0,
              ),
            ),
          ),
        );
        final controller = GameController(core: core);
        final input = RunnerInputRouter(controller: controller);

        final dt = 1.0 / controller.tickHz;
        final windupTicks = ticksFromSecondsCeil(
          AbilityCatalog.shared.resolve('eloise.charged_shot')!.windupTicks /
              60.0,
          controller.tickHz,
        );

        input.setAimDir(1, 0);
        for (var i = 0; i < aimHoldTicks; i += 1) {
          input.pumpHeldInputs();
          controller.advanceFrame(dt);
        }

        input.commitProjectileWithAim(clearAim: true);

        for (var i = 0; i < windupTicks + 2; i += 1) {
          input.pumpHeldInputs();
          controller.advanceFrame(dt);
        }

        final snapshot = core.buildSnapshot();
        final projectile = snapshot.entities.firstWhere(
          (e) => e.kind == EntityKind.projectile,
        );
        return projectile.vel!.x.abs();
      }

      final tapSpeed = launchSpeedForAimHoldTicks(0);
      final longAimHoldSpeed = launchSpeedForAimHoldTicks(24);

      expect(longAimHoldSpeed, closeTo(tapSpeed, 1e-9));
    },
  );

  test(
    'release-to-cast derives charged-shot tier from authoritative slot holds',
    () {
      double launchSpeedForHeldTicks(int heldTicks) {
        final base = PlayerCharacterRegistry.eloise;
        final core = GameCore(
          seed: 1,
          tickHz: 60,
          tuning: noAutoscrollTuning,
          playerCharacter: base.copyWith(
            catalog: testPlayerCatalog(
              bodyTemplate: BodyDef(useGravity: false),
              projectileId: ProjectileId.throwingKnife,
              projectileSlotSpellId: null,
              abilityProjectileId: 'eloise.charged_shot',
            ),
            tuning: base.tuning.copyWith(
              resource: const ResourceTuning(
                playerManaMax: 20,
                playerManaRegenPerSecond: 0,
              ),
            ),
          ),
        );
        final controller = GameController(core: core);
        final input = RunnerInputRouter(controller: controller);

        final dt = 1.0 / controller.tickHz;
        final windupTicks = ticksFromSecondsCeil(
          AbilityCatalog.shared.resolve('eloise.charged_shot')!.windupTicks /
              60.0,
          controller.tickHz,
        );

        input.setAimDir(1, 0);
        input.startAbilitySlotHold(AbilitySlot.projectile);
        input.pumpHeldInputs();
        controller.advanceFrame(dt);

        for (var i = 0; i < heldTicks; i += 1) {
          input.pumpHeldInputs();
          controller.advanceFrame(dt);
        }

        input.endAbilitySlotHold(AbilitySlot.projectile);
        input.commitProjectileWithAim(clearAim: true);

        for (var i = 0; i < windupTicks + 2; i += 1) {
          input.pumpHeldInputs();
          controller.advanceFrame(dt);
        }

        final snapshot = core.buildSnapshot();
        final projectile = snapshot.entities.firstWhere(
          (e) => e.kind == EntityKind.projectile,
        );
        return projectile.vel!.x.abs();
      }

      final shortHoldSpeed = launchSpeedForHeldTicks(0);
      final longHoldSpeed = launchSpeedForHeldTicks(20);

      expect(longHoldSpeed, greaterThan(shortHoldSpeed));
    },
  );

  test(
    'secondary release commit keeps melee aim and consumes secondary slot input',
    () {
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        seed: 1,
        tickHz: 60,
        tuning: noAutoscrollTuning,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(useGravity: false),
            loadoutSlotMask: LoadoutSlotMask.all,
            abilitySecondaryId: 'eloise.charged_shield_bash',
            projectileId: ProjectileId.iceBolt,
            abilityProjectileId: 'eloise.charged_shot',
          ),
        ),
      );
      final controller = GameController(core: core);
      final input = RunnerInputRouter(controller: controller);

      final dt = 1.0 / controller.tickHz;
      final windupTicks = ticksFromSecondsCeil(
        AbilityCatalog.shared
                .resolve('eloise.charged_shield_bash')!
                .windupTicks /
            60.0,
        controller.tickHz,
      );

      input.setAimDir(0, -1);
      input.startAbilitySlotHold(AbilitySlot.secondary);
      input.pumpHeldInputs();
      controller.advanceFrame(dt);
      input.endAbilitySlotHold(AbilitySlot.secondary);
      input.commitSecondaryStrike();

      for (var i = 0; i < windupTicks + 2; i += 1) {
        input.pumpHeldInputs();
        controller.advanceFrame(dt);
      }

      final snapshot = core.buildSnapshot();
      final triggers = snapshot.entities
          .where((e) => e.kind == EntityKind.trigger)
          .toList();
      expect(triggers, isNotEmpty);

      final rotation = triggers.first.rotationRad;
      expect(math.cos(rotation), closeTo(0, 0.2));
      expect(math.sin(rotation), lessThan(-0.8));
      expect(
        snapshot.hud.cooldownTicksLeft[CooldownGroup.secondary],
        greaterThan(0),
      );
      expect(snapshot.hud.cooldownTicksLeft[CooldownGroup.primary], equals(0));
    },
  );

  test(
    'secondary charged melee keeps stable hitbox size across hold tiers',
    () {
      double hitboxWidthForHeldTicks(int heldTicks) {
        final base = PlayerCharacterRegistry.eloise;
        final core = GameCore(
          seed: 1,
          tickHz: 60,
          tuning: noAutoscrollTuning,
          playerCharacter: base.copyWith(
            catalog: testPlayerCatalog(
              bodyTemplate: BodyDef(useGravity: false),
              loadoutSlotMask: LoadoutSlotMask.all,
              abilitySecondaryId: 'eloise.charged_shield_bash',
              projectileId: ProjectileId.iceBolt,
              abilityProjectileId: 'eloise.charged_shot',
            ),
          ),
        );
        final controller = GameController(core: core);
        final input = RunnerInputRouter(controller: controller);

        final dt = 1.0 / controller.tickHz;
        final windupTicks = ticksFromSecondsCeil(
          AbilityCatalog.shared
                  .resolve('eloise.charged_shield_bash')!
                  .windupTicks /
              60.0,
          controller.tickHz,
        );

        input.setAimDir(1, 0);
        input.startAbilitySlotHold(AbilitySlot.secondary);
        input.pumpHeldInputs();
        controller.advanceFrame(dt);

        for (var i = 0; i < heldTicks; i += 1) {
          input.pumpHeldInputs();
          controller.advanceFrame(dt);
        }

        input.endAbilitySlotHold(AbilitySlot.secondary);
        input.commitSecondaryStrike();

        for (var i = 0; i < windupTicks + 2; i += 1) {
          input.pumpHeldInputs();
          controller.advanceFrame(dt);
        }

        final snapshot = core.buildSnapshot();
        final trigger = snapshot.entities.firstWhere(
          (e) => e.kind == EntityKind.trigger,
        );
        return trigger.size!.x;
      }

      final shortHoldWidth = hitboxWidthForHeldTicks(0);
      final longHoldWidth = hitboxWidthForHeldTicks(20);

      expect(longHoldWidth, closeTo(shortHoldWidth, 1e-9));
    },
  );

  test(
    'hud charge preview is shared across projectile and charged melee slots',
    () {
      void expectSharedPreview({
        required AbilitySlot slot,
        AbilityKey? abilityPrimaryId,
        AbilityKey? abilitySecondaryId,
        AbilityKey? abilityProjectileId,
        AbilityKey? abilityMobilityId,
        int? loadoutSlotMask,
        required void Function(RunnerInputRouter input) seedAim,
      }) {
        final base = PlayerCharacterRegistry.eloise;
        final core = GameCore(
          seed: 1,
          tickHz: 60,
          tuning: noAutoscrollTuning,
          playerCharacter: base.copyWith(
            catalog: testPlayerCatalog(
              bodyTemplate: BodyDef(useGravity: false),
              loadoutSlotMask: loadoutSlotMask,
              abilityPrimaryId: abilityPrimaryId,
              abilitySecondaryId: abilitySecondaryId,
              abilityProjectileId: abilityProjectileId,
              abilityMobilityId: abilityMobilityId,
              projectileId: ProjectileId.throwingKnife,
              projectileSlotSpellId: null,
            ),
          ),
        );
        final controller = GameController(core: core);
        final input = RunnerInputRouter(controller: controller);
        final dt = 1.0 / controller.tickHz;

        seedAim(input);
        input.startAbilitySlotHold(slot);
        input.pumpHeldInputs();
        controller.advanceFrame(dt);

        for (var i = 0; i < 8; i += 1) {
          input.pumpHeldInputs();
          controller.advanceFrame(dt);
        }

        final hud = core.buildSnapshot().hud;
        expect(hud.chargeEnabled, isTrue);
        expect(hud.chargeActive, isTrue);
        expect(hud.chargeFullTicks, greaterThan(0));
        expect(hud.chargeTicks, greaterThan(0));
        expect(hud.chargeTier, greaterThanOrEqualTo(1));
      }

      expectSharedPreview(
        slot: AbilitySlot.projectile,
        abilityProjectileId: 'eloise.charged_shot',
        seedAim: (input) => input.setAimDir(1, 0),
      );

      expectSharedPreview(
        slot: AbilitySlot.primary,
        abilityPrimaryId: 'eloise.charged_sword_strike',
        seedAim: (input) => input.setAimDir(1, 0),
      );

      expectSharedPreview(
        slot: AbilitySlot.secondary,
        abilitySecondaryId: 'eloise.charged_shield_bash',
        loadoutSlotMask: LoadoutSlotMask.all,
        seedAim: (input) => input.setAimDir(1, 0),
      );
    },
  );

  test(
    'mobility tap ability does not scale with held ticks on release commit',
    () {
      double dashSpeedForHeldTicks(int heldTicks) {
        final base = PlayerCharacterRegistry.eloise;
        final core = GameCore(
          seed: 1,
          tickHz: 60,
          tuning: noAutoscrollTuning,
          playerCharacter: base.copyWith(
            catalog: testPlayerCatalog(
              bodyTemplate: BodyDef(useGravity: false),
              abilityMobilityId: 'eloise.dash',
            ),
          ),
        );
        final controller = GameController(core: core);
        final input = RunnerInputRouter(controller: controller);
        final dt = 1.0 / controller.tickHz;

        input.setAimDir(0, -1);
        input.startAbilitySlotHold(AbilitySlot.mobility);
        input.pumpHeldInputs();
        controller.advanceFrame(dt);

        for (var i = 0; i < heldTicks; i += 1) {
          input.pumpHeldInputs();
          controller.advanceFrame(dt);
        }

        input.endAbilitySlotHold(AbilitySlot.mobility);
        input.commitMobilityWithAim(clearAim: true);
        input.pumpHeldInputs();
        controller.advanceFrame(dt);

        return core.playerVelY.abs();
      }

      final shortHoldSpeed = dashSpeedForHeldTicks(0);
      final longHoldSpeed = dashSpeedForHeldTicks(20);

      expect(longHoldSpeed, closeTo(shortHoldSpeed, 1e-9));
    },
  );

  test(
    'multiple aim updates write into one shared aim channel (last write wins)',
    () {
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        seed: 1,
        tickHz: 60,
        tuning: noAutoscrollTuning,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(useGravity: false),
            projectileId: ProjectileId.throwingKnife,
            abilityProjectileId: 'eloise.quick_shot',
          ),
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerManaMax: 20,
              playerManaRegenPerSecond: 0,
            ),
          ),
        ),
      );
      final controller = GameController(core: core);
      final input = RunnerInputRouter(controller: controller);
      final dt = 1.0 / controller.tickHz;
      final windupTicks = ticksFromSecondsCeil(
        AbilityCatalog.shared.resolve('eloise.quick_shot')!.windupTicks / 60.0,
        controller.tickHz,
      );

      input.setAimDir(1, 0);
      input.setAimDir(0, -1);
      input.commitProjectileWithAim(clearAim: true);

      for (var i = 0; i < windupTicks + 2; i += 1) {
        input.pumpHeldInputs();
        controller.advanceFrame(dt);
      }

      final snapshot = core.buildSnapshot();
      final projectile = snapshot.entities.firstWhere(
        (e) => e.kind == EntityKind.projectile,
      );
      expect(projectile.vel, isNotNull);
      expect(projectile.vel!.x.abs(), lessThan(1e-6));
      expect(projectile.vel!.y, lessThan(0));
    },
  );

  test('starting a new slot hold replaces the previous held slot', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 60,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: testPlayerCatalog(
          bodyTemplate: BodyDef(useGravity: false),
          loadoutSlotMask: LoadoutSlotMask.all,
          abilitySecondaryId: 'eloise.charged_shield_bash',
          abilityProjectileId: 'eloise.charged_shot',
          projectileId: ProjectileId.throwingKnife,
          projectileSlotSpellId: null,
        ),
      ),
    );
    final controller = GameController(core: core);
    final input = RunnerInputRouter(controller: controller);
    final dt = 1.0 / controller.tickHz;

    input.setAimDir(1, 0);
    input.startAbilitySlotHold(AbilitySlot.projectile);
    input.pumpHeldInputs();
    controller.advanceFrame(dt);

    expect(core.buildSnapshot().hud.chargeFullTicks, equals(10));

    input.setAimDir(1, 0);
    input.startAbilitySlotHold(AbilitySlot.secondary);
    input.pumpHeldInputs();
    controller.advanceFrame(dt);

    // Charged shield bash full threshold is 16 ticks at 60 Hz.
    expect(core.buildSnapshot().hud.chargeFullTicks, equals(16));
  });

  test('same-tick slot hold replacement keeps latest hold winner', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 60,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: testPlayerCatalog(
          bodyTemplate: BodyDef(useGravity: false),
          loadoutSlotMask: LoadoutSlotMask.all,
          abilitySecondaryId: 'eloise.charged_shield_bash',
          abilityProjectileId: 'eloise.charged_shot',
          projectileId: ProjectileId.throwingKnife,
          projectileSlotSpellId: null,
        ),
      ),
    );
    final controller = GameController(core: core);
    final input = RunnerInputRouter(controller: controller);
    final dt = 1.0 / controller.tickHz;

    input.setAimDir(1, 0);
    input.startAbilitySlotHold(AbilitySlot.projectile);
    // Replacement on the same tick should keep secondary as the winner.
    input.startAbilitySlotHold(AbilitySlot.secondary);
    input.pumpHeldInputs();
    controller.advanceFrame(dt);

    // Charged shield bash full threshold is 16 ticks at 60 Hz.
    expect(core.buildSnapshot().hud.chargeFullTicks, equals(16));
  });

  test(
    'charge timeout cancels hold and blocks commit until a new hold starts',
    () {
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        seed: 1,
        tickHz: 60,
        tuning: noAutoscrollTuning,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(useGravity: false),
            projectileId: ProjectileId.throwingKnife,
            projectileSlotSpellId: null,
            abilityProjectileId: 'eloise.charged_shot',
          ),
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerManaMax: 100,
              playerManaRegenPerSecond: 0,
            ),
          ),
        ),
      );
      final controller = GameController(core: core);
      final input = RunnerInputRouter(controller: controller);
      final dt = 1.0 / controller.tickHz;
      final windupTicks = ticksFromSecondsCeil(
        AbilityCatalog.shared.resolve('eloise.charged_shot')!.windupTicks /
            60.0,
        controller.tickHz,
      );

      input.setAimDir(1, 0);
      input.startAbilitySlotHold(AbilitySlot.projectile);
      input.pumpHeldInputs();
      controller.advanceFrame(dt);

      // Timeout is authored at 3s -> 180 ticks at 60Hz.
      for (var i = 0; i < 181; i += 1) {
        input.pumpHeldInputs();
        controller.advanceFrame(dt);
      }

      // Simulate release; commit should be blocked by timeout cancellation.
      input.endAbilitySlotHold(AbilitySlot.projectile);
      input.commitProjectileWithAim(clearAim: true);
      for (var i = 0; i < windupTicks + 2; i += 1) {
        input.pumpHeldInputs();
        controller.advanceFrame(dt);
      }
      expect(
        core.buildSnapshot().entities.where(
          (e) => e.kind == EntityKind.projectile,
        ),
        isEmpty,
      );

      // Starting a new hold clears cancellation and allows commit again.
      input.setAimDir(1, 0);
      input.startAbilitySlotHold(AbilitySlot.projectile);
      input.pumpHeldInputs();
      controller.advanceFrame(dt);
      input.endAbilitySlotHold(AbilitySlot.projectile);
      input.commitProjectileWithAim(clearAim: true);
      for (var i = 0; i < windupTicks + 2; i += 1) {
        input.pumpHeldInputs();
        controller.advanceFrame(dt);
      }

      expect(
        core.buildSnapshot().entities.where(
          (e) => e.kind == EntityKind.projectile,
        ),
        isNotEmpty,
      );
    },
  );
}
