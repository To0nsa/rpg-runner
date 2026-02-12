import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
import 'package:rpg_runner/core/spells/spell_book_id.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/ability/ability_picker_presenter.dart';

void main() {
  group('ability picker presenter', () {
    test(
      'projectile source options include equipped throw + spellbook spells',
      () {
        const loadout = EquippedLoadoutDef(
          projectileItemId: ProjectileItemId.throwingKnife,
        );

        final options = projectileSourceOptions(loadout);

        expect(options, isNotEmpty);
        expect(options.first.spellId, isNull);
        expect(options.first.isSpell, isFalse);
        expect(
          options.any((o) => o.spellId == ProjectileItemId.fireBolt),
          isTrue,
        );
        expect(
          options.any((o) => o.spellId == ProjectileItemId.iceBolt),
          isFalse,
        );
        expect(
          options.any((o) => o.spellId == ProjectileItemId.thunderBolt),
          isFalse,
        );
      },
    );

    test(
      'projectile source panel model separates throw and spellbook groups',
      () {
        const loadout = EquippedLoadoutDef(
          projectileItemId: ProjectileItemId.throwingKnife,
          spellBookId: SpellBookId.basicSpellBook,
        );

        final model = projectileSourcePanelModel(loadout);

        expect(model.throwingWeaponId, ProjectileItemId.throwingKnife);
        expect(model.spellBookId, SpellBookId.basicSpellBook);
        expect(model.spellOptions, isNotEmpty);
        expect(
          model.spellOptions.any(
            (spell) => spell.spellId == ProjectileItemId.fireBolt,
          ),
          isTrue,
        );
        expect(
          model.spellOptions.any(
            (spell) => spell.spellId == ProjectileItemId.iceBolt,
          ),
          isFalse,
        );
        expect(
          model.spellOptions.any(
            (spell) => spell.spellId == ProjectileItemId.thunderBolt,
          ),
          isFalse,
        );
      },
    );

    test('projectile slot exposes all enabled projectile abilities', () {
      const loadout = EquippedLoadoutDef(
        spellBookId: SpellBookId.solidSpellBook,
        abilityProjectileId: 'eloise.quick_shot',
        projectileSlotSpellId: ProjectileItemId.iceBolt,
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.projectile,
        loadout: loadout,
        selectedSourceSpellId: ProjectileItemId.iceBolt,
        overrideSelectedSource: true,
      );

      final autoAim = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.auto_aim_shot',
      );
      final quickShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.quick_shot',
      );
      final piercingShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.piercing_shot',
      );
      final chargedShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.charged_shot',
      );
      expect(autoAim.isEnabled, isTrue);
      expect(quickShot.isEnabled, isTrue);
      expect(piercingShot.isEnabled, isTrue);
      expect(chargedShot.isEnabled, isTrue);
    });

    test('bonus slot exposes only self spell abilities', () {
      const loadout = EquippedLoadoutDef(abilityBonusId: 'eloise.arcane_haste');

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.bonus,
        loadout: loadout,
      );

      expect(
        candidates.any((candidate) => candidate.id == 'eloise.arcane_haste'),
        isTrue,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.restore_mana'),
        isTrue,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.restore_health'),
        isTrue,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.quick_shot'),
        isFalse,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.charged_shot'),
        isFalse,
      );

      final arcaneHaste = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.arcane_haste',
      );
      final restoreMana = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.restore_mana',
      );
      final restoreHealth = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.restore_health',
      );
      expect(arcaneHaste.isEnabled, isTrue);
      expect(restoreMana.isEnabled, isFalse);
      expect(restoreHealth.isEnabled, isFalse);
    });

    test('primary and secondary slots expose melee auto-aim variants', () {
      const loadout = EquippedLoadoutDef(
        abilityPrimaryId: 'eloise.sword_strike',
        abilitySecondaryId: 'eloise.shield_bash',
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
        (candidate) => candidate.id == 'eloise.sword_strike_auto_aim',
      );
      final shieldAutoAim = secondaryCandidates.firstWhere(
        (candidate) => candidate.id == 'eloise.shield_bash_auto_aim',
      );
      expect(swordAutoAim.isEnabled, isTrue);
      expect(shieldAutoAim.isEnabled, isTrue);
    });

    test(
      'secondary slot uses character-authored mask (legacy mask normalized)',
      () {
        const legacyLoadout = EquippedLoadoutDef(
          mask: LoadoutSlotMask.defaultMask,
          abilitySecondaryId: 'eloise.shield_block',
        );

        final candidates = abilityCandidatesForSlot(
          characterId: PlayerCharacterId.eloise,
          slot: AbilitySlot.secondary,
          loadout: legacyLoadout,
        );

        final shieldBlock = candidates.firstWhere(
          (candidate) => candidate.id == 'eloise.shield_block',
        );
        expect(shieldBlock.isEnabled, isTrue);
      },
    );

    test('invalid source disables projectile abilities through validator', () {
      const loadout = EquippedLoadoutDef(
        abilityProjectileId: 'eloise.quick_shot',
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.projectile,
        loadout: loadout,
        selectedSourceSpellId: ProjectileItemId.throwingAxe,
        overrideSelectedSource: true,
      );

      final autoAim = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.auto_aim_shot',
      );
      final quickShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.quick_shot',
      );
      final piercingShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.piercing_shot',
      );
      final chargedShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.charged_shot',
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
          projectileSlotSpellId: ProjectileItemId.iceBolt,
          abilityBonusId: 'eloise.arcane_haste',
        );

        final next = setProjectileSourceForSlot(
          loadout,
          slot: AbilitySlot.projectile,
          selectedSpellId: ProjectileItemId.thunderBolt,
        );

        expect(next.projectileSlotSpellId, ProjectileItemId.thunderBolt);
        expect(next.abilityBonusId, 'eloise.arcane_haste');
      },
    );
  });
}
