import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/middleware/parry_middleware.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:rpg_runner/ui/text/ability_tag_resolver.dart';
import 'package:rpg_runner/ui/text/ability_tooltip_builder.dart';

void main() {
  final resolver = AbilityTagResolver();
  final tooltipBuilder = DefaultAbilityTooltipBuilder.forLocale(null);
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

    test('derives defense tags for shield guard abilities', () {
      final tags = resolver.resolve(ability('eloise.aegis_riposte'));

      expect(tags, contains(AbilityUiTag.defense));
      expect(tags, contains(AbilityUiTag.hold));
    });

    test('derives utility role from restorative self status', () {
      final tags = resolver.resolve(ability('eloise.vital_surge'));

      expect(tags, contains(AbilityUiTag.utility));
    });

    test('derives auto-target from homing targeting model', () {
      final tags = resolver.resolve(ability('eloise.snap_shot'));

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
      final shieldBlockTags = resolver.resolve(ability('eloise.shield_block'));
      final aegisRiposteTags = resolver.resolve(
        ability('eloise.aegis_riposte'),
      );

      expect(shieldBlockTags, contains(AbilityUiTag.hold));
      expect(aegisRiposteTags, contains(AbilityUiTag.hold));
    });
  });

  group('ability tooltip builder', () {
    test(
      'shows optional immediate restoration separately from its duration',
      () {
        final def = AbilityDef(
          id: 'test.restore',
          category: AbilityCategory.utility,
          allowedSlots: {AbilitySlot.spell},
          windupTicks: 0,
          activeTicks: 0,
          recoveryTicks: 0,
          cooldownTicks: 0,
          animKey: AnimKey.cast,
          selfStatusProfileId: StatusProfileId.restoreHealth,
          selfStatusTuning: const StatusProfileTuning(
            resourceOverTime: StatusApplicationTuning(
              magnitude: 1000,
              durationSeconds: 2,
              applyOnApply: true,
            ),
          ),
        );
        expect(
          tooltipBuilder.build(def).description,
          'Restore 10% of max Health immediately and another 10% over 2.0 seconds.',
        );
      },
    );

    test('shows self effect tuning without changing default descriptions', () {
      final def = AbilityDef(
        id: 'test.focus',
        category: AbilityCategory.utility,
        allowedSlots: {AbilitySlot.spell},
        windupTicks: 0,
        activeTicks: 0,
        recoveryTicks: 0,
        cooldownTicks: 0,
        animKey: AnimKey.cast,
        selfStatusProfileId: StatusProfileId.focus,
        selfStatusTuning: const StatusProfileTuning(
          offenseBuff: StatusApplicationTuning(
            magnitude: 1000,
            critBonusBp: 500,
            durationSeconds: 2,
          ),
        ),
      );
      expect(
        tooltipBuilder.build(def).description,
        'Increase power by 10% and critical chance by 5% for 2.0 seconds.',
      );
      expect(
        tooltipBuilder.build(ability('eloise.focus')).description,
        'Increase power by 25% and critical chance by 15% for 4.0 seconds.',
      );
    });

    test('uses display-name overrides and includes charge badge', () {
      final tooltip = tooltipBuilder.build(ability('eloise.overcharge_shot'));

      expect(tooltip.title, 'Overcharge Bolt');
      expect(tooltip.badges, contains('CHARGED'));
    });

    test('builds guard description from defensive mechanics', () {
      final def = ability('eloise.shield_block');
      final tooltip = tooltipBuilder.build(def);
      final expectedReduction = formatDecimal(def.damageIgnoredBp / 100.0);

      expect(tooltip.description, contains('guard'));
      expect(tooltip.description, contains('$expectedReduction%'));
      expect(tooltip.description, isNot(contains('Riposte')));
      expect(tooltip.dynamicDescriptionValues, contains(expectedReduction));
    });

    test('builds aegis riposte description from authored mechanics', () {
      final def = ability('eloise.aegis_riposte');
      final tooltip = tooltipBuilder.build(def);
      final expectedReduction = formatDecimal(def.damageIgnoredBp / 100.0);
      final expectedRiposteBonus = formatDecimal(
        ParryMiddleware.defaultRiposteBonusBp / 100.0,
      );

      expect(
        tooltip.description,
        contains(
          'reduce direct-hit damage by $expectedReduction% from any direction while held.',
        ),
      );
      expect(
        tooltip.description,
        contains(
          'The first guarded hit grants Riposte, empowering your next landed melee hit by +$expectedRiposteBonus% damage.',
        ),
      );
      expect(tooltip.dynamicDescriptionValues, contains(expectedReduction));
      expect(tooltip.dynamicDescriptionValues, contains('Riposte'));
      expect(tooltip.dynamicDescriptionValues, contains(expectedRiposteBonus));
    });

    test('builds self-status descriptions with exact effect details', () {
      final expectedDescriptionByAbility = <String, String>{
        'eloise.arcane_haste': 'Increase move speed by 40% for 3.0 seconds.',
        'eloise.arcane_ward': 'Reduce direct-hit damage by 40% and cancel damage-over-time effects for 3.0 seconds.',
        'eloise.vital_surge': 'Restore 25% of max Health over 5.0 seconds.',
        'eloise.mana_infusion': 'Restore 35% of max Mana over 5.0 seconds.',
        'eloise.second_wind': 'Restore 25% of max Stamina over 5.0 seconds.',
      };

      for (final entry in expectedDescriptionByAbility.entries) {
        final tooltip = tooltipBuilder.build(ability(entry.key));
        expect(tooltip.description, equals(entry.value));
      }
    });

    test('builds self-status description without id-specific branching', () {
      final def = AbilityDef(
        id: 'test.mana_regen',
        category: AbilityCategory.utility,
        allowedSlots: {AbilitySlot.spell},
        inputLifecycle: AbilityInputLifecycle.tap,
        windupTicks: 0,
        activeTicks: 0,
        recoveryTicks: 0,
        cooldownTicks: 0,
        selfStatusProfileId: StatusProfileId.restoreMana,
        animKey: AnimKey.cast,
      );
      final tooltip = tooltipBuilder.build(def);

      expect(
        tooltip.description,
        equals('Restore 35% of max Mana over 5.0 seconds.'),
      );
      expect(tooltip.dynamicDescriptionValues, contains('35'));
      expect(tooltip.dynamicDescriptionValues, contains('max Mana'));
      expect(tooltip.dynamicDescriptionValues, contains('5.0'));
    });

    test('builds cleanse description with explicit debuff list', () {
      final tooltip = tooltipBuilder.build(ability('eloise.cleanse'));

      expect(
        tooltip.description,
        contains('including stun, silence, slow, vulnerability'),
      );
      expect(tooltip.description, contains('damage-over-time effects'));
      expect(tooltip.dynamicDescriptionValues, contains('stun'));
      expect(tooltip.dynamicDescriptionValues, contains('silence'));
      expect(tooltip.dynamicDescriptionValues, contains('damage-over-time'));
    });

    test('builds seeker slash values from authored profile data', () {
      final def = ability('eloise.seeker_slash');
      final tooltip = tooltipBuilder.build(def);

      expect(
        tooltip.description,
        contains('deals ${formatFixed100(def.baseDamage)} damage'),
      );
      expect(tooltip.description, isNot(contains('Bleed')));
      final highlightedValues = tooltip.dynamicDescriptionValues;
      expect(highlightedValues, contains(formatFixed100(def.baseDamage)));
      expect(highlightedValues, isNot(contains('Bleed')));
    });

    test('builds dash description without speed or duration details', () {
      final tooltip = tooltipBuilder.build(ability('eloise.dash'));

      expect(
        tooltip.description,
        equals('Dash forward quickly. Does not grant invulnerability.'),
      );
      expect(tooltip.dynamicDescriptionValues, isEmpty);
    });

    test('builds concussive roll description without speed or duration', () {
      final def = ability('eloise.roll');
      final tooltip = tooltipBuilder.build(def);

      expect(
        tooltip.description,
        equals(
          'Perform a concussive roll. Enemies hit are affected by Stun. Does not grant invulnerability.',
        ),
      );
      expect(tooltip.dynamicDescriptionValues, contains('Stun'));
    });

    test('builds bloodletter slash values from authored data', () {
      final def = ability('eloise.bloodletter_slash');
      final tooltip = tooltipBuilder.build(def);

      expect(
        tooltip.description,
        contains(
          'deals ${formatFixed100(def.baseDamage)} damage to enemies in aiming direction and in the attack reach.',
        ),
      );
      expect(tooltip.description, isNot(contains('Bleed')));
      final highlightedValues = tooltip.dynamicDescriptionValues;
      expect(highlightedValues, contains(formatFixed100(def.baseDamage)));
      expect(highlightedValues, isNot(contains('Bleed')));
    });

    test('Cleave explains tap damage and full-charge-only bleed', () {
      final tooltip = tooltipBuilder.build(
        ability('eloise.bloodletter_cleave'),
      );
      expect(tooltip.description, contains('release for 14.4 damage'));
      expect(tooltip.description, contains('20.8 damage'));
      expect(
        tooltip.description,
        contains('Only full charge grants this bleed'),
      );
      expect(
        tooltip.description,
        contains('3 damage per second for 5 seconds'),
      );
      expect(
        tooltip.dynamicDescriptionValues,
        containsAll(['14.4', '20.8', 'Bleed']),
      );
    });

    test('resolves templated descriptions without placeholders', () {
      final slashTooltip = tooltipBuilder.build(
        ability('eloise.bloodletter_slash'),
      );
      final seekerTooltip = tooltipBuilder.build(
        ability('eloise.seeker_slash'),
      );
      final cleaveTooltip = tooltipBuilder.build(
        ability('eloise.bloodletter_cleave'),
      );
      final snapShotTooltip = tooltipBuilder.build(ability('eloise.snap_shot'));
      final dashTooltip = tooltipBuilder.build(ability('eloise.dash'));
      final rollTooltip = tooltipBuilder.build(ability('eloise.roll'));

      expect(slashTooltip.description, isNot(contains('{')));
      expect(slashTooltip.description, isNot(contains('}')));
      expect(seekerTooltip.description, isNot(contains('{')));
      expect(seekerTooltip.description, isNot(contains('}')));
      expect(cleaveTooltip.description, isNot(contains('{')));
      expect(cleaveTooltip.description, isNot(contains('}')));
      expect(snapShotTooltip.description, isNot(contains('{')));
      expect(snapShotTooltip.description, isNot(contains('}')));
      expect(dashTooltip.description, isNot(contains('{')));
      expect(dashTooltip.description, isNot(contains('}')));
      expect(rollTooltip.description, isNot(contains('{')));
      expect(rollTooltip.description, isNot(contains('}')));
    });

    test('builds snap shot description from authored values and context', () {
      final def = ability('eloise.snap_shot');
      final defaultTooltip = tooltipBuilder.build(def);
      final selectedTooltip = tooltipBuilder.build(
        def,
        ctx: const AbilityTooltipContext(
          activeProjectileId: ProjectileId.fireBolt,
          payloadWeaponType: WeaponType.spell,
        ),
      );
      final expectedDamage = formatFixed100(def.baseDamage);

      expect(
        defaultTooltip.description,
        equals(
          'Fire your equipped projectile, it deals $expectedDamage damage to the closest enemy.',
        ),
      );
      expect(
        selectedTooltip.description,
        contains('Fire the selected spell projectile (Fire Bolt),'),
      );
      expect(defaultTooltip.dynamicDescriptionValues, contains(expectedDamage));
      expect(
        selectedTooltip.dynamicDescriptionValues,
        contains(expectedDamage),
      );
    });

    test('builds quick shot description with projectile source and damage', () {
      final tooltip = tooltipBuilder.build(
        ability('eloise.quick_shot'),
        ctx: const AbilityTooltipContext(
          activeProjectileId: ProjectileId.fireBolt,
          payloadWeaponType: WeaponType.spell,
        ),
      );

      expect(
        tooltip.description,
        equals(
          'Aim and fire the selected spell projectile (Fire Bolt). '
          'It deals 9 damage to a single target.',
        ),
      );
      expect(tooltip.dynamicDescriptionValues, contains(' (Fire Bolt)'));
      expect(tooltip.dynamicDescriptionValues, contains('9'));
    });

    test('builds overcharge shot description with charge bonuses and interruptible', () {
      final def = ability('eloise.overcharge_shot');
      final tooltip = tooltipBuilder.build(
        def,
        ctx: const AbilityTooltipContext(
          activeProjectileId: ProjectileId.fireBolt,
          payloadWeaponType: WeaponType.spell,
        ),
      );
      final expectedDamage = formatFixed100(def.baseDamage);

      expect(
        tooltip.description,
        equals(
          'Charge and release the selected spell projectile (Fire Bolt). '
          'It deals $expectedDamage damage to a single target. '
          'Charging increases damage (up to +22.5%) '
          'and critical chance (up to +10%). '
          'Full charge takes 0.4 seconds. '
          'This attack can be interrupted by taking damage.',
        ),
      );
      expect(tooltip.dynamicDescriptionValues, contains(' (Fire Bolt)'));
      expect(tooltip.dynamicDescriptionValues, contains(expectedDamage));
      expect(tooltip.dynamicDescriptionValues, contains('22.5'));
      expect(tooltip.dynamicDescriptionValues, contains('10'));
    });

    test('builds skewer shot description with pierce count', () {
      final def = ability('eloise.skewer_shot');
      final tooltip = tooltipBuilder.build(
        def,
        ctx: const AbilityTooltipContext(
          activeProjectileId: ProjectileId.iceBolt,
          payloadWeaponType: WeaponType.spell,
        ),
      );
      final expectedDamage = formatFixed100(def.baseDamage);

      expect(
        tooltip.description,
        equals(
          'Fire the selected spell projectile (Ice Bolt), piercing through enemies in its path. '
          'It deals $expectedDamage damage and can hit up to 3 enemies.',
        ),
      );
      expect(tooltip.dynamicDescriptionValues, contains(' (Ice Bolt)'));
      expect(tooltip.dynamicDescriptionValues, contains(expectedDamage));
      expect(tooltip.dynamicDescriptionValues, contains('3'));
    });

    test('maps authored cooldown ticks to seconds', () {
      final tooltip = tooltipBuilder.build(ability('eloise.vital_surge'));

      expect(tooltip.cooldownSeconds, 12);
    });

    test('keeps cooldown null when authored cooldown is zero', () {
      final tooltip = tooltipBuilder.build(ability('eloise.jump'));

      expect(tooltip.cooldownSeconds, isNull);
    });

    test('maps hold ability active ticks to max duration seconds', () {
      final aegisRiposte = tooltipBuilder.build(
        ability('eloise.aegis_riposte'),
      );
      final shieldBlock = tooltipBuilder.build(ability('eloise.shield_block'));

      expect(aegisRiposte.maxDurationSeconds, 3);
      expect(shieldBlock.maxDurationSeconds, 3);
    });

    test('keeps max duration null for non-hold abilities', () {
      final tooltip = tooltipBuilder.build(ability('eloise.bloodletter_slash'));

      expect(tooltip.maxDurationSeconds, isNull);
    });

    test('maps authored resource cost to one cost line', () {
      final tooltip = tooltipBuilder.build(ability('eloise.vital_surge'));

      expect(tooltip.costLines, hasLength(1));
      expect(tooltip.costLines.single.label, equals('Cost: '));
      expect(tooltip.costLines.single.value, equals('20 Mana'));
    });

    test('resolves cost line from payload weapon context', () {
      final def = ability('eloise.quick_shot');

      final spellTooltip = tooltipBuilder.build(
        def,
        ctx: const AbilityTooltipContext(payloadWeaponType: WeaponType.spell),
      );

      expect(spellTooltip.costLines.single.value, equals('6 Mana'));
    });

    test('keeps cost lines empty when authored cost is zero', () {
      final tooltip = tooltipBuilder.build(ability('grojib.strike'));

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
