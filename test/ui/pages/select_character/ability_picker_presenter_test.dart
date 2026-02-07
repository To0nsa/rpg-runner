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

    test('projectile slot exposes enabled quick/heavy throw abilities', () {
      const loadout = EquippedLoadoutDef(
        abilityProjectileId: 'eloise.quick_throw',
        projectileSlotSpellId: ProjectileItemId.iceBolt,
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.projectile,
        loadout: loadout,
        selectedSourceSpellId: ProjectileItemId.iceBolt,
        overrideSelectedSource: true,
      );

      final quickThrow = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.quick_throw',
      );
      final heavyThrow = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.heavy_throw',
      );
      expect(quickThrow.isEnabled, isTrue);
      expect(heavyThrow.isEnabled, isTrue);
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
        abilityProjectileId: 'eloise.quick_throw',
      );

      final candidates = abilityCandidatesForSlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.projectile,
        loadout: loadout,
        selectedSourceSpellId: ProjectileItemId.throwingAxe,
        overrideSelectedSource: true,
      );

      final quickThrow = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.quick_throw',
      );
      final heavyThrow = candidates.firstWhere(
        (candidate) => candidate.id == 'eloise.heavy_throw',
      );
      expect(quickThrow.isEnabled, isFalse);
      expect(heavyThrow.isEnabled, isFalse);
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
