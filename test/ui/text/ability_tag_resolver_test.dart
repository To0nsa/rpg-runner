import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/text/ability_tag_resolver.dart';
import 'package:rpg_runner/ui/text/ability_tooltip_builder.dart';

void main() {
  final resolver = AbilityTagResolver();
  const tooltipBuilder = DefaultAbilityTooltipBuilder();
  String formatFixed100(int value100) {
    final value = (value100 / 100.0).toStringAsFixed(2);
    return value.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String formatDecimal(double value) {
    final text = value.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  AbilityDef ability(String id) {
    final def = AbilityCatalog.shared.resolve(id);
    expect(def, isNotNull, reason: 'Missing ability in catalog: $id');
    return def!;
  }

  group('ability tag resolver', () {
    test('derives melee hold-release slash as damage aimed', () {
      final tags = resolver.resolve(ability('eloise.bloodletter_slash'));

      expect(tags, contains(AbilityUiTag.damage));
      expect(tags, contains(AbilityUiTag.aimed));
    });

    test('derives defense tags for guard abilities', () {
      final tags = resolver.resolve(ability('eloise.riposte_guard'));

      expect(tags, contains(AbilityUiTag.defense));
      expect(tags, contains(AbilityUiTag.hold));
    });

    test('derives utility role from restorative self status', () {
      final tags = resolver.resolve(ability('eloise.vital_surge'));

      expect(tags, contains(AbilityUiTag.utility));
    });

    test('derives auto-target from homing targeting model', () {
      final tags = resolver.resolve(ability('eloise.homing_bolt'));

      expect(tags, contains(AbilityUiTag.autoTarget));
      expect(tags, isNot(contains(AbilityUiTag.aimed)));
    });

    test('derives dash tag for roll and dash abilities', () {
      final rollTags = resolver.resolve(ability('eloise.roll'));
      final dashTags = resolver.resolve(ability('eloise.dash'));

      expect(rollTags, contains(AbilityUiTag.dash));
      expect(dashTags, contains(AbilityUiTag.dash));
      expect(rollTags, isNot(contains(AbilityUiTag.jump)));
      expect(dashTags, isNot(contains(AbilityUiTag.jump)));
    });

    test('derives jump tag for jump abilities', () {
      final jumpTags = resolver.resolve(ability('eloise.jump'));
      final doubleJumpTags = resolver.resolve(ability('eloise.double_jump'));

      expect(jumpTags, contains(AbilityUiTag.jump));
      expect(doubleJumpTags, contains(AbilityUiTag.jump));
      expect(jumpTags, isNot(contains(AbilityUiTag.dash)));
      expect(doubleJumpTags, isNot(contains(AbilityUiTag.dash)));
    });

    test('derives hold tag for guard hold abilities', () {
      final riposteGuardTags = resolver.resolve(
        ability('eloise.riposte_guard'),
      );
      final shieldBlockTags = resolver.resolve(ability('eloise.shield_block'));
      final aegisRiposteTags = resolver.resolve(
        ability('eloise.aegis_riposte'),
      );

      expect(riposteGuardTags, contains(AbilityUiTag.hold));
      expect(shieldBlockTags, contains(AbilityUiTag.hold));
      expect(aegisRiposteTags, contains(AbilityUiTag.hold));
    });
  });

  group('ability tooltip builder', () {
    test('uses display-name overrides and includes charge badge', () {
      final tooltip = tooltipBuilder.build(ability('eloise.overcharge_shot'));

      expect(tooltip.title, 'Overcharge Bolt');
      expect(tooltip.badges, contains('CHARGED'));
    });

    test('builds guard description from defensive mechanics', () {
      final tooltip = tooltipBuilder.build(ability('eloise.shield_block'));

      expect(tooltip.description, contains('guard'));
      expect(tooltip.description, contains('100%'));
    });

    test('builds self-status description from status profile metadata', () {
      final tooltip = tooltipBuilder.build(ability('eloise.vital_surge'));

      expect(tooltip.description, equals('Tap to gain Health Regen for 5.0s.'));
    });

    test('builds seeker slash DoT values from authored profile data', () {
      final def = ability('eloise.seeker_slash');
      final profile = const StatusProfileCatalog().get(
        StatusProfileId.meleeBleed,
      );
      final dot = profile.applications.firstWhere(
        (application) => application.type == StatusEffectType.dot,
      );
      final tooltip = tooltipBuilder.build(def);

      expect(
        tooltip.description,
        contains('deals ${formatFixed100(def.baseDamage)} damage'),
      );
      expect(
        tooltip.description,
        contains(
          'Bleed, dealing ${formatFixed100(dot.magnitude)} damage per second for ${formatDecimal(dot.durationSeconds)} seconds.',
        ),
      );
      final highlightedValues = tooltip.dynamicDescriptionValues;
      expect(highlightedValues, contains(formatFixed100(def.baseDamage)));
      expect(highlightedValues, contains('Bleed'));
      expect(highlightedValues, contains(formatFixed100(dot.magnitude)));
      expect(highlightedValues, contains(formatDecimal(dot.durationSeconds)));
    });

    test('builds bloodletter slash values from authored data', () {
      final def = ability('eloise.bloodletter_slash');
      final bleedProfileId = def.procs.first.statusProfileId;
      final profile = const StatusProfileCatalog().get(bleedProfileId);
      final dot = profile.applications.firstWhere(
        (application) => application.type == StatusEffectType.dot,
      );
      final tooltip = tooltipBuilder.build(def);

      expect(
        tooltip.description,
        contains(
          'deals ${formatFixed100(def.baseDamage)} damage to enemies in aiming direction and in the attack reach.',
        ),
      );
      expect(
        tooltip.description,
        contains(
          'Bleed, dealing ${formatFixed100(dot.magnitude)} damage per second for ${formatDecimal(dot.durationSeconds)} seconds.',
        ),
      );
      final highlightedValues = tooltip.dynamicDescriptionValues;
      expect(highlightedValues, contains(formatFixed100(def.baseDamage)));
      expect(highlightedValues, contains('Bleed'));
      expect(highlightedValues, contains(formatFixed100(dot.magnitude)));
      expect(highlightedValues, contains(formatDecimal(dot.durationSeconds)));
    });

    test('builds bloodletter cleave values from authored data', () {
      final def = ability('eloise.bloodletter_cleave');
      final bleedProfileId = def.procs.first.statusProfileId;
      final profile = const StatusProfileCatalog().get(bleedProfileId);
      final dot = profile.applications.firstWhere(
        (application) => application.type == StatusEffectType.dot,
      );
      final tiers = def.chargeProfile!.tiers;
      var maxDamageScaleBp = tiers.first.damageScaleBp;
      var maxCritBonusBp = tiers.first.critBonusBp;
      for (final tier in tiers.skip(1)) {
        if (tier.damageScaleBp > maxDamageScaleBp) {
          maxDamageScaleBp = tier.damageScaleBp;
        }
        if (tier.critBonusBp > maxCritBonusBp) {
          maxCritBonusBp = tier.critBonusBp;
        }
      }
      final damageBonusBp = maxDamageScaleBp > 10000
          ? maxDamageScaleBp - 10000
          : 0;
      final tooltip = tooltipBuilder.build(def);

      expect(
        tooltip.description,
        contains(
          'deals ${formatFixed100(def.baseDamage)} damage to enemies in aiming direction and in the attack reach.',
        ),
      );
      expect(
        tooltip.description,
        contains(
          'Bleed, dealing ${formatFixed100(dot.magnitude)} damage per second for ${formatDecimal(dot.durationSeconds)} seconds.',
        ),
      );
      expect(
        tooltip.description,
        contains('up to +${formatDecimal(damageBonusBp / 100.0)}%'),
      );
      expect(
        tooltip.description,
        contains(
          'critical chance (up to +${formatDecimal(maxCritBonusBp / 100.0)}%)',
        ),
      );
      final highlightedValues = tooltip.dynamicDescriptionValues;
      expect(highlightedValues, contains(formatFixed100(def.baseDamage)));
      expect(highlightedValues, contains('Bleed'));
      expect(highlightedValues, contains(formatFixed100(dot.magnitude)));
      expect(highlightedValues, contains(formatDecimal(dot.durationSeconds)));
      expect(highlightedValues, contains(formatDecimal(damageBonusBp / 100.0)));
      expect(
        highlightedValues,
        contains(formatDecimal(maxCritBonusBp / 100.0)),
      );
    });

    test('resolves templated melee descriptions without placeholders', () {
      final slashTooltip = tooltipBuilder.build(
        ability('eloise.bloodletter_slash'),
      );
      final seekerTooltip = tooltipBuilder.build(
        ability('eloise.seeker_slash'),
      );
      final cleaveTooltip = tooltipBuilder.build(
        ability('eloise.bloodletter_cleave'),
      );

      expect(slashTooltip.description, isNot(contains('{')));
      expect(slashTooltip.description, isNot(contains('}')));
      expect(seekerTooltip.description, isNot(contains('{')));
      expect(seekerTooltip.description, isNot(contains('}')));
      expect(cleaveTooltip.description, isNot(contains('{')));
      expect(cleaveTooltip.description, isNot(contains('}')));
    });

    test('uses projectile source context in ranged fallback description', () {
      final tooltip = tooltipBuilder.build(
        ability('eloise.snap_shot'),
        ctx: const AbilityTooltipContext(
          selectedProjectileSpellId: ProjectileId.fireBolt,
          payloadWeaponType: WeaponType.projectileSpell,
        ),
      );

      expect(tooltip.description, contains('selected spell projectile'));
    });

    test('maps authored cooldown ticks to seconds', () {
      final tooltip = tooltipBuilder.build(ability('eloise.vital_surge'));

      expect(tooltip.cooldownSeconds, 7);
    });

    test('keeps cooldown null when authored cooldown is zero', () {
      final tooltip = tooltipBuilder.build(ability('eloise.jump'));

      expect(tooltip.cooldownSeconds, isNull);
    });

    test('maps authored resource cost to one cost line', () {
      final tooltip = tooltipBuilder.build(ability('eloise.vital_surge'));

      expect(tooltip.costLines, hasLength(1));
      expect(tooltip.costLines.single.label, equals('Cost: '));
      expect(tooltip.costLines.single.value, equals('15 Mana'));
    });

    test('resolves cost line from payload weapon context', () {
      final def = ability('eloise.snap_shot');

      final spellTooltip = tooltipBuilder.build(
        def,
        ctx: const AbilityTooltipContext(
          payloadWeaponType: WeaponType.projectileSpell,
        ),
      );
      final throwTooltip = tooltipBuilder.build(
        def,
        ctx: const AbilityTooltipContext(
          payloadWeaponType: WeaponType.throwingWeapon,
        ),
      );

      expect(spellTooltip.costLines.single.value, equals('6 Mana'));
      expect(throwTooltip.costLines.single.value, equals('6 Stamina'));
    });

    test('keeps cost lines empty when authored cost is zero', () {
      final tooltip = tooltipBuilder.build(ability('common.enemy_strike'));

      expect(tooltip.costLines, isEmpty);
    });

    test('uses first and second jump cost lines for double jump', () {
      final tooltip = tooltipBuilder.build(ability('eloise.double_jump'));

      expect(tooltip.costLines, hasLength(2));
      expect(tooltip.costLines.first.label, equals('Cost for first jump: '));
      expect(tooltip.costLines.first.value, equals('2 Stamina'));
      expect(tooltip.costLines.last.label, equals('Cost for second jump: '));
      expect(tooltip.costLines.last.value, equals('2 Mana'));
    });

    test('uses cost per second line for hold abilities', () {
      final tooltip = tooltipBuilder.build(ability('eloise.shield_block'));

      expect(tooltip.costLines, hasLength(1));
      expect(tooltip.costLines.single.label, equals('Cost per second: '));
      expect(tooltip.costLines.single.value, equals('7 Stamina'));
    });
  });
}
