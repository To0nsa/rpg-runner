import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/snapshots/enums.dart';

import 'package:rpg_runner/ui/text/ability_tooltip_builder.dart';

void main() {
  const builder = DefaultAbilityTooltipBuilder();

  test('Double Dash explains its follow-up window and per-burst cost', () {
    final tooltip = builder.build(
      const AbilityCatalog().resolve('eloise.double_dash')!,
    );
    expect(tooltip.title, 'Double Dash');
    expect(tooltip.description, contains('within 0.5 seconds'));
    expect(tooltip.description, contains('Each burst pays the listed cost'));
    expect(tooltip.cooldownSeconds, 2);
  });

  test('Scythe Sweep shows the physical and dark amounts', () {
    final tooltip = builder.build(
      const AbilityCatalog().resolve('bringer.scythe_sweep')!,
    );
    expect(
      tooltip.description,
      contains('Base damage: 8.8 Physical + 8.8 Dark.'),
    );
  });

  test('contact attacks show their own mixed damage amounts', () {
    final tooltip = builder.build(
      AbilityDef(
        id: 'test.mixed_dash',
        animKey: AnimKey.dash,
        category: AbilityCategory.mobility,
        windupTicks: 0,
        activeTicks: 1,
        recoveryTicks: 0,
        cooldownTicks: 0,
        mobilityImpact: const MobilityImpactDef(
          damage100: 1200,
          damageType: DamageTypeMix(fire: 1, ice: 2),
        ),
      ),
    );
    expect(tooltip.description, contains('Base damage: 4 Fire + 8 Ice.'));
  });

  test('single-type tooltips retain their existing descriptions', () {
    final tooltip = builder.build(
      const AbilityCatalog().resolve('eloise.seeker_slash')!,
    );
    expect(tooltip.description, isNot(contains('Base damage:')));
  });
}
