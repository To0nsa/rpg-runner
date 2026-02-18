import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/commands/command.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/game_core.dart';
import '../support/test_level.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
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
    final ability = AbilityCatalog.shared.resolve(abilityId)!;
    return scaledAbilityTicks(ability.windupTicks, tickHz);
  }

  test('cast: insufficient mana => no projectile', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      seed: 1,
      tickHz: 20,
      playerCharacter: base.copyWith(
        catalog: testPlayerCatalog(
          bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
          projectileId: ProjectileId.iceBolt,
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
        projectileId: ProjectileId.iceBolt,
        abilityProjectileId: 'eloise.charged_shot',
      );
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
        seed: 1,
        tickHz: 20,
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
      final expectedOffset = const ProjectileCatalog()
          .get(catalog.projectileId)
          .originOffset;
      expect(p.pos.x, closeTo(playerPosX + expectedOffset, 1e-9));
      expect(p.pos.y, closeTo(playerPosY, 1e-9));

      final ability = AbilityCatalog.shared.resolve('eloise.charged_shot')!;
      final spellCost = ability.resolveCostForWeaponType(
        WeaponType.projectileSpell,
      );
      expect(
        snapshot.hud.mana,
        closeTo(20.0 - fixed100ToDouble(spellCost.manaCost100), 1e-9),
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
      projectileId: ProjectileId.throwingKnife,
      projectileSlotSpellId: ProjectileId.fireBolt,
      abilityProjectileId: 'eloise.charged_shot',
    );
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      seed: 1,
      tickHz: 20,
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

    final ability = AbilityCatalog.shared.resolve('eloise.charged_shot')!;
    final spellCost = ability.resolveCostForWeaponType(
      WeaponType.projectileSpell,
    );
    expect(
      snapshot.hud.mana,
      closeTo(20.0 - fixed100ToDouble(spellCost.manaCost100), 1e-9),
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
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      seed: 1,
      tickHz: 20,
      playerCharacter: base.copyWith(
        catalog: testPlayerCatalog(
          bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
          projectileId: ProjectileId.iceBolt,
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

    final ability = AbilityCatalog.shared.resolve('eloise.charged_shot')!;
    final spellCost = ability.resolveCostForWeaponType(
      WeaponType.projectileSpell,
    );
    var snapshot = core.buildSnapshot();
    expect(
      snapshot.hud.mana,
      closeTo(30.0 - fixed100ToDouble(spellCost.manaCost100), 1e-9),
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
      closeTo(30.0 - fixed100ToDouble(spellCost.manaCost100 * 2), 1e-9),
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
        levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
        seed: 1,
        tickHz: 20,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
            projectileId: ProjectileId.throwingKnife,
            projectileSlotSpellId: ProjectileId.fireBolt,
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
      final ability = AbilityCatalog.shared.resolve('eloise.quick_shot')!;
      final spellCost = ability.resolveCostForWeaponType(
        WeaponType.projectileSpell,
      );
      expect(
        snapshot.hud.mana,
        closeTo(10.0 - fixed100ToDouble(spellCost.manaCost100), 1e-9),
      );
    },
  );

  test('spell-slot self spell restores mana without spawning projectiles', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      seed: 1,
      tickHz: 20,
      playerCharacter: base.copyWith(
        catalog: testPlayerCatalog(
          bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
          abilityProjectileId: 'eloise.charged_shot',
          abilitySpellId: 'eloise.restore_mana',
          spellBookId: SpellBookId.epicSpellBook,
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
    final shotAbility = AbilityCatalog.shared.resolve('eloise.charged_shot')!;
    final shotSpellCost = shotAbility.resolveCostForWeaponType(
      WeaponType.projectileSpell,
    );
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
      closeTo(20.0 - fixed100ToDouble(shotSpellCost.manaCost100), 1e-9),
    );

    core.applyCommands(const [SpellPressedCommand(tick: 2)]);
    core.stepOneTick();

    final afterBonus = core.buildSnapshot();
    final projectilesAfterBonus = afterBonus.entities
        .where((e) => e.kind == EntityKind.projectile)
        .toList();
    expect(projectilesAfterBonus.length, 1);

    final restore = AbilityCatalog.shared.resolve('eloise.restore_mana')!;
    final restoreProfile = const StatusProfileCatalog().get(
      restore.selfStatusProfileId,
    );
    final restoreAmountBp = restoreProfile.applications
        .where(
          (app) =>
              app.type == StatusEffectType.resourceOverTime &&
              app.resourceType == StatusResourceType.mana,
        )
        .first
        .magnitude;
    final expectedMana =
        (beforeBonus.hud.mana + (20.0 * restoreAmountBp / 10000.0)).clamp(
          0.0,
          20.0,
        );
    expect(afterBonus.hud.mana, closeTo(expectedMana, 1e-9));
  });

  test(
    'projectile and spell cooldown groups stay independent (projectile + self spell)',
    () {
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
        seed: 1,
        tickHz: 20,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
            projectileId: ProjectileId.throwingKnife,
            abilityProjectileId: 'eloise.quick_shot',
            abilitySpellId: 'eloise.arcane_haste',
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

      final projectileAbility = AbilityCatalog.shared.resolve(
        'eloise.quick_shot',
      )!;
      final activeTicks = scaledAbilityTicks(
        projectileAbility.activeTicks,
        core.tickHz,
      );
      final recoveryTicks = scaledAbilityTicks(
        projectileAbility.recoveryTicks,
        core.tickHz,
      );
      final bonusAbility = AbilityCatalog.shared.resolve(
        'eloise.arcane_haste',
      )!;
      final bonusCooldownTicks = scaledAbilityTicks(
        bonusAbility.cooldownTicks,
        core.tickHz,
      );
      for (var i = 0; i < activeTicks + recoveryTicks; i += 1) {
        core.applyCommands(const <Command>[]);
        core.stepOneTick();
      }

      final beforeBonus = core.buildSnapshot();
      expect(beforeBonus.hud.cooldownTicksLeft[CooldownGroup.spell0], 0);
      final projectileCooldownBeforeBonus =
          beforeBonus.hud.cooldownTicksLeft[CooldownGroup.projectile];

      core.applyCommands(const [SpellPressedCommand(tick: 2)]);
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
        afterBonusPressed.hud.cooldownTicksLeft[CooldownGroup.spell0],
        bonusCooldownTicks,
      );
    },
  );

  test('auto-aim shot uses tap input mode for projectile slot', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      seed: 1,
      tickHz: 20,
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
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      seed: 1,
      tickHz: 20,
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
