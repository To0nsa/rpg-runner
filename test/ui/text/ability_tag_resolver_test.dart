import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/text/ability_tag_resolver.dart';
import 'package:rpg_runner/ui/text/ability_tooltip_builder.dart';

void main() {
  final resolver = AbilityTagResolver();
  const tooltipBuilder = DefaultAbilityTooltipBuilder();

  AbilityDef ability(String id) {
    final def = AbilityCatalog.shared.resolve(id);
    expect(def, isNotNull, reason: 'Missing ability in catalog: $id');
    return def!;
  }

  group('ability tag resolver', () {
    test(
      'derives melee hold-release slash as offense multi-target dot aimed',
      () {
        final tags = resolver.resolve(ability('eloise.bloodletter_slash'));

        expect(tags, contains(AbilityUiTag.offense));
        expect(tags, contains(AbilityUiTag.multiTarget));
        expect(tags, contains(AbilityUiTag.dot));
        expect(tags, contains(AbilityUiTag.aimed));
        expect(tags, isNot(contains(AbilityUiTag.singleTarget)));
      },
    );

    test(
      'derives defense guard abilities as guard riposte channel stamina',
      () {
        final tags = resolver.resolve(ability('eloise.riposte_guard'));

        expect(tags, contains(AbilityUiTag.defense));
        expect(tags, contains(AbilityUiTag.guard));
        expect(tags, contains(AbilityUiTag.riposte));
        expect(tags, contains(AbilityUiTag.channel));
        expect(tags, contains(AbilityUiTag.staminaSpend));
      },
    );

    test('derives resource tags from context for projectile cost profiles', () {
      final def = ability('eloise.overcharge_shot');
      final allCosts = resolver.resolve(def);
      final spellCost = resolver.resolve(
        def,
        ctx: const AbilityTagContext(
          payloadWeaponType: WeaponType.projectileSpell,
          resolveResourceForContextOnly: true,
        ),
      );
      final throwCost = resolver.resolve(
        def,
        ctx: const AbilityTagContext(
          payloadWeaponType: WeaponType.throwingWeapon,
          resolveResourceForContextOnly: true,
        ),
      );

      expect(allCosts, contains(AbilityUiTag.manaSpend));
      expect(allCosts, contains(AbilityUiTag.staminaSpend));
      expect(spellCost, contains(AbilityUiTag.manaSpend));
      expect(spellCost, isNot(contains(AbilityUiTag.staminaSpend)));
      expect(throwCost, contains(AbilityUiTag.staminaSpend));
      expect(throwCost, isNot(contains(AbilityUiTag.manaSpend)));
    });

    test('derives sustain role from restorative self status', () {
      final tags = resolver.resolve(ability('eloise.vital_surge'));

      expect(tags, contains(AbilityUiTag.sustain));
      expect(tags, isNot(contains(AbilityUiTag.utility)));
      expect(tags, contains(AbilityUiTag.manaSpend));
    });

    test('derives auto-target from homing targeting model', () {
      final tags = resolver.resolve(ability('eloise.homing_bolt'));

      expect(tags, contains(AbilityUiTag.autoTarget));
      expect(tags, isNot(contains(AbilityUiTag.aimed)));
    });
  });

  group('ability tooltip builder', () {
    test('uses display-name overrides and includes charge badge', () {
      final tooltip = tooltipBuilder.build(ability('eloise.overcharge_shot'));

      expect(tooltip.title, 'Overcharge Bolt');
      expect(tooltip.badges, contains('Charge'));
      expect(tooltip.badges, contains('Burst'));
    });

    test('builds guard subtitle from defensive mechanics', () {
      final tooltip = tooltipBuilder.build(ability('eloise.shield_block'));

      expect(tooltip.subtitle, contains('guard'));
      expect(tooltip.subtitle, contains('100%'));
    });

    test('builds self-status subtitle from status profile metadata', () {
      final tooltip = tooltipBuilder.build(ability('eloise.vital_surge'));

      expect(tooltip.subtitle, equals('Tap to gain Health Regen for 5.0s.'));
    });

    test('uses projectile source context in ranged fallback subtitle', () {
      final tooltip = tooltipBuilder.build(
        ability('eloise.snap_shot'),
        ctx: const AbilityTooltipContext(
          selectedProjectileSpellId: ProjectileId.fireBolt,
          payloadWeaponType: WeaponType.projectileSpell,
        ),
      );

      expect(tooltip.subtitle, contains('selected spell projectile'));
    });
  });
}
