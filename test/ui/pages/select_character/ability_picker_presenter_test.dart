import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/meta/ability_ownership_state.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/ability/ability_picker_presenter.dart';

const AbilityOwnershipState _defaultAbilityOwnership = AbilityOwnershipState(
  learnedProjectileSpellIds: <ProjectileId>{ProjectileId.fireBolt},
  learnedAbilityIdsBySlot: <AbilitySlot, Set<AbilityKey>>{
    AbilitySlot.primary: <AbilityKey>{'eloise.seeker_slash'},
    AbilitySlot.secondary: <AbilityKey>{'eloise.shield_block'},
    AbilitySlot.projectile: <AbilityKey>{'eloise.snap_shot'},
    AbilitySlot.mobility: <AbilityKey>{'eloise.dash'},
    AbilitySlot.jump: <AbilityKey>{'eloise.jump'},
    AbilitySlot.spell: <AbilityKey>{'eloise.arcane_haste'},
  },
);

void main() {
  group('ability picker presenter', () {
    test('projectile source options include learned projectile spells', () {
      const loadout = EquippedLoadoutDef(
        projectileSlotSpellId: ProjectileId.fireBolt,
      );
      const abilityOwnership = AbilityOwnershipState(
        learnedProjectileSpellIds: <ProjectileId>{
          ProjectileId.fireBolt,
          ProjectileId.iceBolt,
        },
        learnedAbilityIdsBySlot: <AbilitySlot, Set<AbilityKey>>{
          AbilitySlot.spell: <AbilityKey>{'eloise.arcane_haste'},
        },
      );

      final options = projectileSourceOptions(loadout, abilityOwnership);

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
      const abilityOwnership = AbilityOwnershipState(
        learnedProjectileSpellIds: <ProjectileId>{
          ProjectileId.fireBolt,
          ProjectileId.iceBolt,
        },
        learnedAbilityIdsBySlot: <AbilitySlot, Set<AbilityKey>>{
          AbilitySlot.spell: <AbilityKey>{'eloise.arcane_haste'},
        },
      );

      final model = projectileSourcePanelModel(loadout, abilityOwnership);

      expect(model.abilityOwnershipDisplayName, 'Spell List');
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

    test('projectile slot exposes owned and locked projectile abilities', () {
      const loadout = EquippedLoadoutDef(
        abilityProjectileId: 'eloise.quick_shot',
        projectileSlotSpellId: ProjectileId.iceBolt,
      );
      const abilityOwnership = AbilityOwnershipState(
        learnedProjectileSpellIds: <ProjectileId>{ProjectileId.iceBolt},
        learnedAbilityIdsBySlot: <AbilitySlot, Set<AbilityKey>>{
          AbilitySlot.projectile: <AbilityKey>{'eloise.snap_shot'},
          AbilitySlot.spell: <AbilityKey>{'eloise.arcane_haste'},
        },
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.projectile,
        loadout: loadout,
        abilityOwnership: abilityOwnership,
        selectedSourceSpellId: ProjectileId.iceBolt,
        overrideSelectedSource: true,
      );

      final autoAim = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.snap_shot',
      );
      final quickShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.quick_shot',
      );
      final skewerShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.skewer_shot',
      );
      final overchargeShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.overcharge_shot',
      );
      expect(autoAim.isOwned, isTrue);
      expect(autoAim.isEnabled, isTrue);
      expect(quickShot.isOwned, isFalse);
      expect(skewerShot.isOwned, isFalse);
      expect(overchargeShot.isOwned, isFalse);
    });

    test('spell slot exposes learned and locked spell abilities', () {
      const loadout = EquippedLoadoutDef(abilitySpellId: 'eloise.arcane_haste');
      const abilityOwnership = AbilityOwnershipState(
        learnedProjectileSpellIds: <ProjectileId>{ProjectileId.fireBolt},
        learnedAbilityIdsBySlot: <AbilitySlot, Set<AbilityKey>>{
          AbilitySlot.spell: <AbilityKey>{
            'eloise.arcane_haste',
            'eloise.mana_infusion',
            'eloise.cleanse',
            'eloise.vital_surge',
          },
        },
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.spell,
        loadout: loadout,
        abilityOwnership: abilityOwnership,
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
        candidates.any((candidate) => candidate.id == 'eloise.focus'),
        isTrue,
      );
      expect(
        candidates.any((candidate) => candidate.id == 'eloise.quick_shot'),
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
      final focus = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.focus',
      );
      expect(arcaneHaste.isOwned, isTrue);
      expect(restoreMana.isOwned, isTrue);
      expect(cleanse.isOwned, isTrue);
      expect(restoreHealth.isOwned, isTrue);
      expect(arcaneHaste.isEnabled, isTrue);
      expect(restoreMana.isEnabled, isTrue);
      expect(cleanse.isEnabled, isTrue);
      expect(restoreHealth.isEnabled, isTrue);
      expect(focus.isOwned, isFalse);
    });

    test('primary and secondary expose owned and locked options', () {
      const loadout = EquippedLoadoutDef(
        abilityPrimaryId: 'eloise.bloodletter_slash',
        abilitySecondaryId: 'eloise.aegis_riposte',
      );

      final primaryCandidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.primary,
        loadout: loadout,
        abilityOwnership: _defaultAbilityOwnership,
      );
      final secondaryCandidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.secondary,
        loadout: loadout,
        abilityOwnership: _defaultAbilityOwnership,
      );

      final swordAutoAim = primaryCandidates.firstWhere(
        (candidate) => candidate.id == 'eloise.seeker_slash',
      );
      final shieldBlock = secondaryCandidates.firstWhere(
        (candidate) => candidate.id == 'eloise.shield_block',
      );
      final bloodletterSlash = primaryCandidates.firstWhere(
        (candidate) => candidate.id == 'eloise.bloodletter_slash',
      );
      final aegisRiposte = secondaryCandidates.firstWhere(
        (candidate) => candidate.id == 'eloise.aegis_riposte',
      );
      expect(swordAutoAim.isOwned, isTrue);
      expect(shieldBlock.isOwned, isTrue);
      expect(swordAutoAim.isEnabled, isTrue);
      expect(shieldBlock.isEnabled, isTrue);
      expect(bloodletterSlash.isOwned, isFalse);
      expect(aegisRiposte.isOwned, isFalse);
    });

    test('jump slot exposes owned and locked jump options', () {
      const loadout = EquippedLoadoutDef(abilityJumpId: 'eloise.jump');

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.jump,
        loadout: loadout,
        abilityOwnership: _defaultAbilityOwnership,
      );

      final jump = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.jump',
      );
      final doubleJump = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.double_jump',
      );
      expect(jump.isOwned, isTrue);
      expect(jump.isEnabled, isTrue);
      expect(doubleJump.isOwned, isFalse);
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
        abilityOwnership: _defaultAbilityOwnership,
      );

      final shieldBlock = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.shield_block',
      );
      expect(shieldBlock.isEnabled, isTrue);
    });

    test('catalog-valid source keeps owned projectile option legal', () {
      const loadout = EquippedLoadoutDef(
        abilityProjectileId: 'eloise.quick_shot',
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.projectile,
        loadout: loadout,
        abilityOwnership: _defaultAbilityOwnership,
        selectedSourceSpellId: ProjectileId.iceBolt,
        overrideSelectedSource: true,
      );

      final autoAim = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.snap_shot',
      );
      final quickShot = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.quick_shot',
      );
      expect(autoAim.isOwned, isTrue);
      expect(autoAim.isEnabled, isTrue);
      expect(quickShot.isOwned, isFalse);
    });

    test('candidate model separates ownership from legality', () {
      const loadout = EquippedLoadoutDef(
        abilityProjectileId: 'eloise.snap_shot',
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.projectile,
        loadout: loadout,
        abilityOwnership: _defaultAbilityOwnership,
        selectedSourceSpellId: ProjectileId.unknown,
        overrideSelectedSource: true,
      );

      final ownedProjectile = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.snap_shot',
      );
      final lockedProjectile = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.quick_shot',
      );
      expect(ownedProjectile.isOwned, isTrue);
      expect(ownedProjectile.isEnabled, isFalse);
      expect(lockedProjectile.isOwned, isFalse);
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
