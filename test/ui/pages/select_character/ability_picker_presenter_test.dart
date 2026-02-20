import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/ability/ability_picker_presenter.dart';

void main() {
  group('ability picker presenter', () {
    test(
      'projectile source options include equipped throw + spellbook spells',
      () {
        const loadout = EquippedLoadoutDef(
          projectileId: ProjectileId.throwingKnife,
        );

        final options = projectileSourceOptions(loadout);

        expect(options, isNotEmpty);
        expect(options.first.spellId, isNull);
        expect(options.first.isSpell, isFalse);
        expect(options.any((o) => o.spellId == ProjectileId.fireBolt), isTrue);
        expect(options.any((o) => o.spellId == ProjectileId.iceBolt), isFalse);
        expect(
          options.any((o) => o.spellId == ProjectileId.thunderBolt),
          isFalse,
        );
      },
    );

    test(
      'projectile source panel model separates throw and spellbook groups',
      () {
        const loadout = EquippedLoadoutDef(
          projectileId: ProjectileId.throwingKnife,
          spellBookId: SpellBookId.basicSpellBook,
        );

        final model = projectileSourcePanelModel(loadout);

        expect(model.throwingWeaponId, ProjectileId.throwingKnife);
        expect(model.spellBookId, SpellBookId.basicSpellBook);
        expect(model.spellOptions, isNotEmpty);
        expect(
          model.spellOptions.any(
            (spell) => spell.spellId == ProjectileId.fireBolt,
          ),
          isTrue,
        );
        expect(
          model.spellOptions.any(
            (spell) => spell.spellId == ProjectileId.iceBolt,
          ),
          isFalse,
        );
        expect(
          model.spellOptions.any(
            (spell) => spell.spellId == ProjectileId.thunderBolt,
          ),
          isFalse,
        );
      },
    );

    test('projectile slot exposes all enabled projectile abilities', () {
      const loadout = EquippedLoadoutDef(
        spellBookId: SpellBookId.solidSpellBook,
        abilityProjectileId: 'eloise.snap_shot',
        projectileSlotSpellId: ProjectileId.iceBolt,
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.projectile,
        loadout: loadout,
        selectedSourceSpellId: ProjectileId.iceBolt,
        overrideSelectedSource: true,
      );

      final autoAim = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.homing_bolt',
      );
      final quickShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.snap_shot',
      );
      final piercingShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.skewer_shot',
      );
      final chargedShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.overcharge_shot',
      );
      expect(autoAim.isEnabled, isTrue);
      expect(quickShot.isEnabled, isTrue);
      expect(piercingShot.isEnabled, isTrue);
      expect(chargedShot.isEnabled, isTrue);
    });

    test('spell slot exposes only self spell abilities', () {
      const loadout = EquippedLoadoutDef(abilitySpellId: 'eloise.arcane_haste');

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.spell,
        loadout: loadout,
      );

      expect(
        candidates.any((candidate) => candidate.id == 'eloise.arcane_haste'),
        isTrue,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.mana_infusion'),
        isTrue,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.vital_surge'),
        isTrue,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.snap_shot'),
        isFalse,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.overcharge_shot'),
        isFalse,
      );

      final arcaneHaste = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.arcane_haste',
      );
      final restoreMana = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.mana_infusion',
      );
      final restoreHealth = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.vital_surge',
      );
      expect(arcaneHaste.isEnabled, isTrue);
      expect(restoreMana.isEnabled, isFalse);
      expect(restoreHealth.isEnabled, isFalse);
    });

    test('primary and secondary slots expose melee auto-aim variants', () {
      const loadout = EquippedLoadoutDef(
        abilityPrimaryId: 'eloise.bloodletter_slash',
        abilitySecondaryId: 'eloise.concussive_bash',
      );

      final primaryCandidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.primary,
        loadout: loadout,
      );
      final secondaryCandidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.secondary,
        loadout: loadout,
      );

      final swordAutoAim = primaryCandidates.firstWhere(
        (candidate) => candidate.id == 'eloise.seeker_slash',
      );
      final shieldAutoAim = secondaryCandidates.firstWhere(
        (candidate) => candidate.id == 'eloise.seeker_bash',
      );
      expect(swordAutoAim.isEnabled, isTrue);
      expect(shieldAutoAim.isEnabled, isTrue);
    });

    test('jump slot exposes jump and double jump as enabled options', () {
      const loadout = EquippedLoadoutDef(abilityJumpId: 'eloise.jump');

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.jump,
        loadout: loadout,
      );

      final jump = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.jump',
      );
      final doubleJump = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.double_jump',
      );
      expect(jump.isEnabled, isTrue);
      expect(doubleJump.isEnabled, isTrue);
    });

    test(
      'secondary slot uses character-authored mask (legacy mask normalized)',
      () {
        const legacyLoadout = EquippedLoadoutDef(
          mask: LoadoutSlotMask.defaultMask,
          abilitySecondaryId: 'eloise.aegis_riposte',
        );

        final candidates = abilityCandidatesForSlot(
          characterId: PlayerCharacterId.eloise,
          slot: AbilitySlot.secondary,
          loadout: legacyLoadout,
        );

        final shieldBlock = candidates.firstWhere(
          (candidate) => candidate.id == 'eloise.aegis_riposte',
        );
        expect(shieldBlock.isEnabled, isTrue);
      },
    );

    test('invalid source disables projectile abilities through validator', () {
      const loadout = EquippedLoadoutDef(
        abilityProjectileId: 'eloise.snap_shot',
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.projectile,
        loadout: loadout,
        selectedSourceSpellId: ProjectileId.throwingAxe,
        overrideSelectedSource: true,
      );

      final autoAim = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.homing_bolt',
      );
      final quickShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.snap_shot',
      );
      final piercingShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.skewer_shot',
      );
      final chargedShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.overcharge_shot',
      );
      expect(autoAim.isEnabled, isFalse);
      expect(quickShot.isEnabled, isFalse);
      expect(piercingShot.isEnabled, isFalse);
      expect(chargedShot.isEnabled, isFalse);
    });

    test(
      'setProjectileSourceForSlot updates only the requested slot source',
      () {
        const loadout = EquippedLoadoutDef(
          projectileSlotSpellId: ProjectileId.iceBolt,
          abilitySpellId: 'eloise.arcane_haste',
        );

        final next = setProjectileSourceForSlot(
          loadout,
          slot: AbilitySlot.projectile,
          selectedSpellId: ProjectileId.thunderBolt,
        );

        expect(next.projectileSlotSpellId, ProjectileId.thunderBolt);
        expect(next.abilitySpellId, 'eloise.arcane_haste');
      },
    );
  });
}
