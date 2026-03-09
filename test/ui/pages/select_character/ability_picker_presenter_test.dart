import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/meta/spell_list.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/ability/ability_picker_presenter.dart';

const SpellList _defaultSpellList = SpellList(
  learnedProjectileSpellIds: <ProjectileId>{ProjectileId.fireBolt},
  learnedSpellAbilityIds: <AbilityKey>{'eloise.arcane_haste'},
);

void main() {
  group('ability picker presenter', () {
    test('projectile source options include learned projectile spells', () {
      const loadout = EquippedLoadoutDef(
        projectileSlotSpellId: ProjectileId.fireBolt,
      );
      const spellList = SpellList(
        learnedProjectileSpellIds: <ProjectileId>{
          ProjectileId.fireBolt,
          ProjectileId.iceBolt,
        },
        learnedSpellAbilityIds: <AbilityKey>{'eloise.arcane_haste'},
      );

      final options = projectileSourceOptions(loadout, spellList);

      expect(options, isNotEmpty);
      expect(options.any((o) => o.spellId == ProjectileId.fireBolt), isTrue);
      expect(options.any((o) => o.spellId == ProjectileId.iceBolt), isTrue);
      expect(
        options.any((o) => o.spellId == ProjectileId.thunderBolt),
        isFalse,
      );
    });

    test('projectile source panel model exposes spell list options', () {
      const loadout = EquippedLoadoutDef(
        projectileSlotSpellId: ProjectileId.fireBolt,
      );
      const spellList = SpellList(
        learnedProjectileSpellIds: <ProjectileId>{
          ProjectileId.fireBolt,
          ProjectileId.iceBolt,
        },
        learnedSpellAbilityIds: <AbilityKey>{'eloise.arcane_haste'},
      );

      final model = projectileSourcePanelModel(loadout, spellList);

      expect(model.spellListDisplayName, 'Spell List');
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
        isTrue,
      );
      expect(
        model.spellOptions.any(
          (spell) => spell.spellId == ProjectileId.thunderBolt,
        ),
        isFalse,
      );
    });

    test('projectile slot exposes only owned starter ability', () {
      const loadout = EquippedLoadoutDef(
        abilityProjectileId: 'eloise.quick_shot',
        projectileSlotSpellId: ProjectileId.iceBolt,
      );
      const spellList = SpellList(
        learnedProjectileSpellIds: <ProjectileId>{ProjectileId.iceBolt},
        learnedSpellAbilityIds: <AbilityKey>{'eloise.arcane_haste'},
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.projectile,
        loadout: loadout,
        spellList: spellList,
        selectedSourceSpellId: ProjectileId.iceBolt,
        overrideSelectedSource: true,
      );

      final autoAim = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.snap_shot',
      );
      expect(autoAim.isEnabled, isTrue);
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.quick_shot'),
        isFalse,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.skewer_shot'),
        isFalse,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.overcharge_shot'),
        isFalse,
      );
    });

    test('spell slot exposes only learned spell abilities', () {
      const loadout = EquippedLoadoutDef(abilitySpellId: 'eloise.arcane_haste');
      const spellList = SpellList(
        learnedProjectileSpellIds: <ProjectileId>{ProjectileId.fireBolt},
        learnedSpellAbilityIds: <AbilityKey>{
          'eloise.arcane_haste',
          'eloise.mana_infusion',
          'eloise.cleanse',
          'eloise.vital_surge',
        },
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.spell,
        loadout: loadout,
        spellList: spellList,
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
        candidates.any((candidate) => candidate.id == 'eloise.cleanse'),
        isTrue,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.vital_surge'),
        isTrue,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.quick_shot'),
        isFalse,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.focus'),
        isFalse,
      );

      final arcaneHaste = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.arcane_haste',
      );
      final restoreMana = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.mana_infusion',
      );
      final cleanse = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.cleanse',
      );
      final restoreHealth = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.vital_surge',
      );
      expect(arcaneHaste.isEnabled, isTrue);
      expect(restoreMana.isEnabled, isTrue);
      expect(cleanse.isEnabled, isTrue);
      expect(restoreHealth.isEnabled, isTrue);
    });

    test('primary and secondary expose only owned starter options', () {
      const loadout = EquippedLoadoutDef(
        abilityPrimaryId: 'eloise.bloodletter_slash',
        abilitySecondaryId: 'eloise.aegis_riposte',
      );

      final primaryCandidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.primary,
        loadout: loadout,
        spellList: _defaultSpellList,
      );
      final secondaryCandidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.secondary,
        loadout: loadout,
        spellList: _defaultSpellList,
      );

      final swordAutoAim = primaryCandidates.firstWhere(
        (candidate) => candidate.id == 'eloise.seeker_slash',
      );
      final shieldBlock = secondaryCandidates.firstWhere(
        (candidate) => candidate.id == 'eloise.shield_block',
      );
      expect(swordAutoAim.isEnabled, isTrue);
      expect(shieldBlock.isEnabled, isTrue);
      expect(
        primaryCandidates.any(
          (candidate) => candidate.id == 'eloise.bloodletter_slash',
        ),
        isFalse,
      );
      expect(
        secondaryCandidates.any(
          (candidate) => candidate.id == 'eloise.aegis_riposte',
        ),
        isFalse,
      );
    });

    test('jump slot exposes only owned starter jump option', () {
      const loadout = EquippedLoadoutDef(abilityJumpId: 'eloise.jump');

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.jump,
        loadout: loadout,
        spellList: _defaultSpellList,
      );

      final jump = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.jump',
      );
      expect(jump.isEnabled, isTrue);
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.double_jump'),
        isFalse,
      );
    });

    test('secondary slot remains legal under current validator rules', () {
      const legacyLoadout = EquippedLoadoutDef(
        mask: LoadoutSlotMask.defaultMask,
        abilitySecondaryId: 'eloise.shield_block',
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.secondary,
        loadout: legacyLoadout,
        spellList: _defaultSpellList,
      );

      final shieldBlock = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.shield_block',
      );
      expect(shieldBlock.isEnabled, isTrue);
    });

    test('catalog-valid source keeps starter projectile option enabled', () {
      const loadout = EquippedLoadoutDef(
        abilityProjectileId: 'eloise.quick_shot',
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.projectile,
        loadout: loadout,
        spellList: _defaultSpellList,
        selectedSourceSpellId: ProjectileId.iceBolt,
        overrideSelectedSource: true,
      );

      final autoAim = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.snap_shot',
      );
      expect(autoAim.isEnabled, isTrue);
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.quick_shot'),
        isFalse,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.skewer_shot'),
        isFalse,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.overcharge_shot'),
        isFalse,
      );
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
