import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/combat/middleware/parry_middleware.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
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
      final def = ability('eloise.shield_block');
      final tooltip = tooltipBuilder.build(def);
      final expectedReduction = formatDecimal(def.damageIgnoredBp / 100.0);

      expect(tooltip.description, contains('guard'));
      expect(tooltip.description, contains('$expectedReduction%'));
      expect(tooltip.description, isNot(contains('Riposte')));
      expect(tooltip.dynamicDescriptionValues, contains(expectedReduction));
    });

    test('builds riposte guard description from authored mechanics', () {
      final def = ability('eloise.riposte_guard');
      final tooltip = tooltipBuilder.build(def);
      final expectedReduction = formatDecimal(def.damageIgnoredBp / 100.0);
      final expectedRiposteBonus = formatDecimal(
        ParryMiddleware.defaultRiposteBonusBp / 100.0,
      );

      expect(
        tooltip.description,
        contains('reduce incoming damage by $expectedReduction% while held.'),
      );
      expect(
        tooltip.description,
        contains(
          'Guarded hits grant Riposte, empowering your next melee hit by +$expectedRiposteBonus% damage.',
        ),
      );
      expect(tooltip.dynamicDescriptionValues, contains(expectedReduction));
      expect(tooltip.dynamicDescriptionValues, contains('Riposte'));
      expect(tooltip.dynamicDescriptionValues, contains(expectedRiposteBonus));
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
        contains('reduce incoming damage by $expectedReduction% while held.'),
      );
      expect(
        tooltip.description,
        contains(
          'Guarded hits grant Riposte, empowering your next melee hit by +$expectedRiposteBonus% damage.',
        ),
      );
      expect(tooltip.dynamicDescriptionValues, contains(expectedReduction));
      expect(tooltip.dynamicDescriptionValues, contains('Riposte'));
      expect(tooltip.dynamicDescriptionValues, contains(expectedRiposteBonus));
    });

    test('builds self-status descriptions from profile metadata', () {
      final expectedStatusByAbility = <String, String>{
        'eloise.arcane_haste': 'Haste',
        'eloise.vital_surge': 'Health Regen',
        'eloise.mana_infusion': 'Mana Regen',
        'eloise.second_wind': 'Stamina Regen',
      };

      for (final entry in expectedStatusByAbility.entries) {
        final def = ability(entry.key);
        final profile = const StatusProfileCatalog().get(def.selfStatusProfileId);
        final duration = profile.applications.first.durationSeconds.toStringAsFixed(
          1,
        );
        final tooltip = tooltipBuilder.build(def);

        expect(
          tooltip.description,
          equals('Tap to gain ${entry.value} for ${duration}s.'),
        );
        expect(tooltip.dynamicDescriptionValues, contains(entry.value));
        expect(tooltip.dynamicDescriptionValues, contains(duration));
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

      expect(tooltip.description, equals('Tap to gain Mana Regen for 5.0s.'));
      expect(tooltip.dynamicDescriptionValues, contains('Mana Regen'));
      expect(tooltip.dynamicDescriptionValues, contains('5.0'));
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

    test('builds seeker bash control values from authored profile data', () {
      final def = ability('eloise.seeker_bash');
      final profile = const StatusProfileCatalog().get(
        StatusProfileId.stunOnHit,
      );
      final stun = profile.applications.firstWhere(
        (application) => application.type == StatusEffectType.stun,
      );
      final tooltip = tooltipBuilder.build(def);

      expect(
        tooltip.description,
        contains('deals ${formatFixed100(def.baseDamage)} damage'),
      );
      expect(
        tooltip.description,
        contains('Stun for ${formatDecimal(stun.durationSeconds)} seconds.'),
      );
      final highlightedValues = tooltip.dynamicDescriptionValues;
      expect(highlightedValues, contains(formatFixed100(def.baseDamage)));
      expect(highlightedValues, contains('Stun'));
      expect(highlightedValues, contains(formatDecimal(stun.durationSeconds)));
    });

    test(
      'builds concussive bash control values from authored profile data',
      () {
        final def = ability('eloise.concussive_bash');
        final profile = const StatusProfileCatalog().get(
          StatusProfileId.stunOnHit,
        );
        final stun = profile.applications.firstWhere(
          (application) => application.type == StatusEffectType.stun,
        );
        final tooltip = tooltipBuilder.build(def);

        expect(
          tooltip.description,
          contains('deals ${formatFixed100(def.baseDamage)} damage'),
        );
        expect(
          tooltip.description,
          contains('Stun for ${formatDecimal(stun.durationSeconds)} seconds.'),
        );
        final highlightedValues = tooltip.dynamicDescriptionValues;
        expect(highlightedValues, contains(formatFixed100(def.baseDamage)));
        expect(highlightedValues, contains('Stun'));
        expect(
          highlightedValues,
          contains(formatDecimal(stun.durationSeconds)),
        );
      },
    );

    test(
      'builds concussive breaker control and charge values from authored data',
      () {
        final def = ability('eloise.concussive_breaker');
        final profile = const StatusProfileCatalog().get(
          StatusProfileId.stunOnHit,
        );
        final stun = profile.applications.firstWhere(
          (application) => application.type == StatusEffectType.stun,
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
          contains('Stun for ${formatDecimal(stun.durationSeconds)} seconds.'),
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
        expect(
          tooltip.description,
          contains('This attack can be interrupted by taking damage.'),
        );
        final highlightedValues = tooltip.dynamicDescriptionValues;
        expect(highlightedValues, contains(formatFixed100(def.baseDamage)));
        expect(highlightedValues, contains('Stun'));
        expect(highlightedValues, contains(formatDecimal(stun.durationSeconds)));
        expect(highlightedValues, contains(formatDecimal(damageBonusBp / 100.0)));
        expect(
          highlightedValues,
          contains(formatDecimal(maxCritBonusBp / 100.0)),
        );
      },
    );

    test('builds dash description without speed or duration details', () {
      final tooltip = tooltipBuilder.build(ability('eloise.dash'));

      expect(tooltip.description, equals('Dash forward quickly.'));
      expect(tooltip.dynamicDescriptionValues, isEmpty);
    });

    test('builds concussive roll description without speed or duration', () {
      final def = ability('eloise.roll');
      final tooltip = tooltipBuilder.build(def);

      expect(
        tooltip.description,
        equals(
          'Perform a concussive roll. Enemies hit are affected by Stun.',
        ),
      );
      expect(tooltip.dynamicDescriptionValues, contains('Stun'));
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
      final breakerTooltip = tooltipBuilder.build(
        ability('eloise.concussive_breaker'),
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
      expect(breakerTooltip.description, isNot(contains('{')));
      expect(breakerTooltip.description, isNot(contains('}')));
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
          payloadWeaponType: WeaponType.projectileSpell,
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
      expect(selectedTooltip.dynamicDescriptionValues, contains(expectedDamage));
    });

    test('builds quick shot description with projectile source and damage', () {
      final tooltip = tooltipBuilder.build(
        ability('eloise.quick_shot'),
        ctx: const AbilityTooltipContext(
          activeProjectileId: ProjectileId.fireBolt,
          payloadWeaponType: WeaponType.projectileSpell,
        ),
      );

      expect(
        tooltip.description,
        equals(
          'Aim and fire the selected spell projectile (Fire Bolt). '
          'It deals 9 damage.',
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
          payloadWeaponType: WeaponType.projectileSpell,
        ),
      );
      final expectedDamage = formatFixed100(def.baseDamage);

      expect(
        tooltip.description,
        equals(
          'Charge and release the selected spell projectile (Fire Bolt). '
          'It deals $expectedDamage damage. '
          'Charging increases damage (up to +22.5%) '
          'and critical chance (up to +10%). '
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
          activeProjectileId: ProjectileId.throwingAxe,
          payloadWeaponType: WeaponType.throwingWeapon,
        ),
      );
      final expectedDamage = formatFixed100(def.baseDamage);

      expect(
        tooltip.description,
        equals(
          'Aim and fire a piercing your equipped projectile (Throwing Axe) in a line. '
          'It deals $expectedDamage damage and can hit up to 3 enemies.',
        ),
      );
      expect(
        tooltip.dynamicDescriptionValues,
        contains(' (Throwing Axe)'),
      );
      expect(tooltip.dynamicDescriptionValues, contains(expectedDamage));
      expect(tooltip.dynamicDescriptionValues, contains('3'));
    });

    test('maps authored cooldown ticks to seconds', () {
      final tooltip = tooltipBuilder.build(ability('eloise.vital_surge'));

      expect(tooltip.cooldownSeconds, 7);
    });

    test('keeps cooldown null when authored cooldown is zero', () {
      final tooltip = tooltipBuilder.build(ability('eloise.jump'));

      expect(tooltip.cooldownSeconds, isNull);
    });

    test('maps hold ability active ticks to max duration seconds', () {
      final riposteGuard = tooltipBuilder.build(
        ability('eloise.riposte_guard'),
      );
      final aegisRiposte = tooltipBuilder.build(
        ability('eloise.aegis_riposte'),
      );
      final shieldBlock = tooltipBuilder.build(ability('eloise.shield_block'));

      expect(riposteGuard.maxDurationSeconds, 3);
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
      expect(tooltip.costLines.single.value, equals('15 Mana'));
    });

    test('resolves cost line from payload weapon context', () {
      final def = ability('eloise.quick_shot');

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
