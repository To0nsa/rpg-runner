import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
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
          options.any((o) => o.spellId == ProjectileItemId.iceBolt),
          isTrue,
        );
        expect(
          options.any((o) => o.spellId == ProjectileItemId.fireBolt),
          isTrue,
        );
        expect(
          options.any((o) => o.spellId == ProjectileItemId.thunderBolt),
          isTrue,
        );
      },
    );

    test('projectile slot exposes all enabled projectile abilities', () {
      const loadout = EquippedLoadoutDef(
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
          bonusSlotSpellId: ProjectileItemId.fireBolt,
        );

        final next = setProjectileSourceForSlot(
          loadout,
          slot: AbilitySlot.projectile,
          selectedSpellId: ProjectileItemId.thunderBolt,
        );

        expect(next.projectileSlotSpellId, ProjectileItemId.thunderBolt);
        expect(next.bonusSlotSpellId, ProjectileItemId.fireBolt);
      },
    );
  });
}
