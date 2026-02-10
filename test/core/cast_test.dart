import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/commands/command.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/game_core.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/util/tick_math.dart';

import '../support/test_player.dart';
import '../test_tunings.dart';

void main() {
  int scaledAbilityTicks(int ticksAt60Hz, int tickHz) {
    if (tickHz == 60) return ticksAt60Hz;
    final seconds = ticksAt60Hz / 60.0;
    return ticksFromSecondsCeil(seconds, tickHz);
  }

  double fixed100ToDouble(int value) => value / 100.0;

  int scaledWindupTicks(String abilityId, int tickHz) {
    final ability = AbilityCatalog.tryGet(abilityId)!;
    return scaledAbilityTicks(ability.windupTicks, tickHz);
  }

  test('cast: insufficient mana => no projectile', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 20,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: testPlayerCatalog(
          bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
          projectileItemId: ProjectileItemId.iceBolt,
          abilityProjectileId: 'eloise.charged_shot',
        ),
        tuning: base.tuning.copyWith(
          resource: const ResourceTuning(
            playerManaMax: 0,
            playerManaRegenPerSecond: 0,
          ),
        ),
      ),
    );

    core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
    core.stepOneTick();
    final windupTicks = scaledWindupTicks('eloise.charged_shot', core.tickHz);
    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }

    final snapshot = core.buildSnapshot();
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile),
      isEmpty,
    );
    expect(snapshot.hud.mana, closeTo(0.0, 1e-9));
    expect(core.playerProjectileCooldownTicksLeft, 0);
  });

  test(
    'cast: sufficient mana => projectile spawns + mana spent + cooldown set',
    () {
      final catalog = testPlayerCatalog(
        bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
        projectileItemId: ProjectileItemId.iceBolt,
        abilityProjectileId: 'eloise.charged_shot',
      );
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        seed: 1,
        tickHz: 20,
        tuning: noAutoscrollTuning,
        playerCharacter: base.copyWith(
          catalog: catalog,
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerManaMax: 20,
              playerManaRegenPerSecond: 0,
            ),
          ),
        ),
      );

      final playerPosX = core.playerPosX;
      final playerPosY = core.playerPosY;

      core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
      core.stepOneTick();
      final windupTicks = scaledWindupTicks('eloise.charged_shot', core.tickHz);
      for (var i = 0; i < windupTicks; i += 1) {
        core.applyCommands(const <Command>[]);
        core.stepOneTick();
      }

      final snapshot = core.buildSnapshot();
      final projectiles = snapshot.entities
          .where((e) => e.kind == EntityKind.projectile)
          .toList();
      expect(projectiles.length, 1);

      final p = projectiles.single;
      final expectedOffset = catalog.colliderMaxHalfExtent * 0.5;
      expect(p.pos.x, closeTo(playerPosX + expectedOffset, 1e-9));
      expect(p.pos.y, closeTo(playerPosY, 1e-9));

      final ability = AbilityCatalog.tryGet('eloise.charged_shot')!;
      expect(
        snapshot.hud.mana,
        closeTo(20.0 - fixed100ToDouble(ability.manaCost), 1e-9),
      );
      final cooldownTicks = scaledAbilityTicks(
        ability.cooldownTicks,
        core.tickHz,
      );
      expect(
        core.playerProjectileCooldownTicksLeft,
        cooldownTicks - windupTicks,
      ); // Cooldown already ticked during windup
    },
  );

  test('cast: selected projectile-slot spell overrides throwing item', () {
    final catalog = testPlayerCatalog(
      bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
      projectileItemId: ProjectileItemId.throwingKnife,
      projectileSlotSpellId: ProjectileItemId.fireBolt,
      abilityProjectileId: 'eloise.charged_shot',
    );
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 20,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: catalog,
        tuning: base.tuning.copyWith(
          resource: const ResourceTuning(
            playerManaMax: 20,
            playerManaRegenPerSecond: 0,
          ),
        ),
      ),
    );

    core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
    core.stepOneTick();
    final windupTicks = scaledWindupTicks('eloise.charged_shot', core.tickHz);
    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }

    final snapshot = core.buildSnapshot();
    final projectiles = snapshot.entities
        .where((e) => e.kind == EntityKind.projectile)
        .toList();
    expect(projectiles.length, 1);
    expect(projectiles.single.projectileId, ProjectileId.fireBolt);

    final ability = AbilityCatalog.tryGet('eloise.charged_shot')!;
    expect(
      snapshot.hud.mana,
      closeTo(20.0 - fixed100ToDouble(ability.manaCost), 1e-9),
    );
    final cooldownTicks = scaledAbilityTicks(
      ability.cooldownTicks,
      core.tickHz,
    );
    expect(
      core.playerProjectileCooldownTicksLeft,
      cooldownTicks - windupTicks,
    ); // Cooldown already ticked during windup
  });

  test('cast: cooldown blocks recast until it expires', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 20,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: testPlayerCatalog(
          bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
          projectileItemId: ProjectileItemId.iceBolt,
          abilityProjectileId: 'eloise.charged_shot',
        ),
        tuning: base.tuning.copyWith(
          resource: const ResourceTuning(
            playerManaMax: 30,
            playerManaRegenPerSecond: 0,
          ),
        ),
      ),
    );

    core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
    core.stepOneTick();
    final windupTicks = scaledWindupTicks('eloise.charged_shot', core.tickHz);
    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }

    core.applyCommands(const [ProjectilePressedCommand(tick: 2)]);
    core.stepOneTick();
    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }

    final ability = AbilityCatalog.tryGet('eloise.charged_shot')!;
    var snapshot = core.buildSnapshot();
    expect(
      snapshot.hud.mana,
      closeTo(30.0 - fixed100ToDouble(ability.manaCost), 1e-9),
    );
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile).length,
      1,
    );

    // Wait until cooldown should be 0, then cast again.
    while (core.playerProjectileCooldownTicksLeft > 0) {
      core.applyCommands(<Command>[]);
      core.stepOneTick();
    }

    core.applyCommands(const [ProjectilePressedCommand(tick: 9)]);
    core.stepOneTick();
    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }

    snapshot = core.buildSnapshot();
    expect(
      snapshot.hud.mana,
      closeTo(30.0 - fixed100ToDouble(ability.manaCost * 2), 1e-9),
    );
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile).length,
      2,
    );
  });

  test(
    'quick throw: projectile slot can launch selected spell from spellbook',
    () {
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        seed: 1,
        tickHz: 20,
        tuning: noAutoscrollTuning,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
            projectileItemId: ProjectileItemId.throwingKnife,
            projectileSlotSpellId: ProjectileItemId.fireBolt,
            abilityProjectileId: 'eloise.quick_shot',
          ),
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerManaMax: 10,
              playerManaRegenPerSecond: 0,
              playerStaminaMax: 0,
              playerStaminaRegenPerSecond: 0,
            ),
          ),
        ),
      );

      core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
      core.stepOneTick();
      final windupTicks = scaledWindupTicks('eloise.quick_shot', core.tickHz);
      for (var i = 0; i < windupTicks; i += 1) {
        core.applyCommands(const <Command>[]);
        core.stepOneTick();
      }

      final snapshot = core.buildSnapshot();
      final projectiles = snapshot.entities
          .where((e) => e.kind == EntityKind.projectile)
          .toList();
      expect(projectiles.length, 1);
      expect(projectiles.single.projectileId, ProjectileId.fireBolt);
      final ability = AbilityCatalog.tryGet('eloise.quick_shot')!;
      expect(
        snapshot.hud.mana,
        closeTo(10.0 - fixed100ToDouble(ability.manaCost), 1e-9),
      );
    },
  );

  test('bonus self spell restores mana without spawning projectiles', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 20,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: testPlayerCatalog(
          bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
          abilityProjectileId: 'eloise.charged_shot',
          abilityBonusId: 'eloise.restore_mana',
        ),
        tuning: base.tuning.copyWith(
          resource: const ResourceTuning(
            playerManaMax: 20,
            playerManaRegenPerSecond: 0,
            playerStaminaMax: 20,
            playerStaminaRegenPerSecond: 0,
          ),
        ),
      ),
    );

    core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
    core.stepOneTick();
    final windupTicks = scaledWindupTicks('eloise.charged_shot', core.tickHz);
    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }
    final shotAbility = AbilityCatalog.tryGet('eloise.charged_shot')!;
    final shotActiveTicks = scaledAbilityTicks(
      shotAbility.activeTicks,
      core.tickHz,
    );
    final shotRecoveryTicks = scaledAbilityTicks(
      shotAbility.recoveryTicks,
      core.tickHz,
    );
    for (var i = 0; i < shotActiveTicks + shotRecoveryTicks; i += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }

    final beforeBonus = core.buildSnapshot();
    final projectilesBeforeBonus = beforeBonus.entities
        .where((e) => e.kind == EntityKind.projectile)
        .toList();
    expect(projectilesBeforeBonus.length, 1);
    expect(
      beforeBonus.hud.mana,
      closeTo(20.0 - fixed100ToDouble(shotAbility.manaCost), 1e-9),
    );

    core.applyCommands(const [BonusPressedCommand(tick: 2)]);
    core.stepOneTick();

    final afterBonus = core.buildSnapshot();
    final projectilesAfterBonus = afterBonus.entities
        .where((e) => e.kind == EntityKind.projectile)
        .toList();
    expect(projectilesAfterBonus.length, 1);

    final restore = AbilityCatalog.tryGet('eloise.restore_mana')!;
    final expectedMana =
        (beforeBonus.hud.mana + (20.0 * restore.selfRestoreManaBp / 10000.0))
            .clamp(0.0, 20.0);
    expect(afterBonus.hud.mana, closeTo(expectedMana, 1e-9));
  });

  test(
    'projectile and bonus cooldown groups stay independent (projectile + self spell)',
    () {
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        seed: 1,
        tickHz: 20,
        tuning: noAutoscrollTuning,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
            projectileItemId: ProjectileItemId.throwingKnife,
            abilityProjectileId: 'eloise.quick_shot',
            abilityBonusId: 'eloise.arcane_haste',
          ),
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerManaMax: 20,
              playerManaRegenPerSecond: 0,
              playerStaminaMax: 20,
              playerStaminaRegenPerSecond: 0,
            ),
          ),
        ),
      );

      core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
      core.stepOneTick();
      final windupTicks = scaledWindupTicks('eloise.quick_shot', core.tickHz);
      for (var i = 0; i < windupTicks; i += 1) {
        core.applyCommands(const <Command>[]);
        core.stepOneTick();
      }

      final projectileAbility = AbilityCatalog.tryGet('eloise.quick_shot')!;
      final activeTicks = scaledAbilityTicks(
        projectileAbility.activeTicks,
        core.tickHz,
      );
      final recoveryTicks = scaledAbilityTicks(
        projectileAbility.recoveryTicks,
        core.tickHz,
      );
      final bonusAbility = AbilityCatalog.tryGet('eloise.arcane_haste')!;
      final bonusCooldownTicks = scaledAbilityTicks(
        bonusAbility.cooldownTicks,
        core.tickHz,
      );
      for (var i = 0; i < activeTicks + recoveryTicks; i += 1) {
        core.applyCommands(const <Command>[]);
        core.stepOneTick();
      }

      final beforeBonus = core.buildSnapshot();
      expect(beforeBonus.hud.cooldownTicksLeft[CooldownGroup.bonus0], 0);
      final projectileCooldownBeforeBonus =
          beforeBonus.hud.cooldownTicksLeft[CooldownGroup.projectile];

      core.applyCommands(const [BonusPressedCommand(tick: 2)]);
      core.stepOneTick();
      final afterBonusPressed = core.buildSnapshot();
      final expectedProjectileAfterOneTick = projectileCooldownBeforeBonus > 0
          ? projectileCooldownBeforeBonus - 1
          : 0;
      expect(
        afterBonusPressed.hud.cooldownTicksLeft[CooldownGroup.projectile],
        expectedProjectileAfterOneTick,
      );
      expect(
        afterBonusPressed.hud.cooldownTicksLeft[CooldownGroup.bonus0],
        bonusCooldownTicks,
      );
    },
  );

  test('auto-aim shot uses tap input mode for projectile slot', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 20,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: testPlayerCatalog(
          bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
          abilityProjectileId: 'eloise.auto_aim_shot',
        ),
      ),
    );

    final hud = core.buildSnapshot().hud;
    expect(hud.projectileInputMode, AbilityInputMode.tap);
  });

  test('quick shot keeps hold-aim-release input mode', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 20,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: testPlayerCatalog(
          bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
          abilityProjectileId: 'eloise.quick_shot',
        ),
      ),
    );

    final hud = core.buildSnapshot().hud;
    expect(hud.projectileInputMode, AbilityInputMode.holdAimRelease);
  });
}
