import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:rpg_runner/ui/controls/control_button_visuals.dart';
import 'package:rpg_runner/ui/controls/control_resource_usage.dart';
import 'package:rpg_runner/ui/theme/ui_action_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_resource_colors.dart';

void main() {
  test('free-to-start shield holds still identify stamina', () {
    final ability = AbilityCatalog.shared.resolve('eloise.shield_block')!;
    final usage = ControlResourceUsage.fromAbility(
      ability: ability,
      cost: AbilityResourceCost.zero,
    );
    expect(usage.stamina, isTrue);
    expect(usage.mana, isFalse);
    expect(usage.health, isFalse);
  });

  test('jump preview includes air cost while runtime follows current cost', () {
    final ability = AbilityCatalog.shared.resolve('eloise.double_jump')!;
    final preview = ControlResourceUsage.forPreview(
      ability: ability,
      cost: ability.defaultCost,
    );
    final airborne = ControlResourceUsage.fromAbility(
      ability: ability,
      cost: ability.airJumpCost,
    );
    expect(preview.stamina, isTrue);
    expect(preview.mana, isTrue);
    expect(airborne.stamina, isFalse);
    expect(airborne.mana, isTrue);
  });

  test('free, single-resource and mixed-resource buttons stay muted', () {
    final theme = UiActionButtonTheme.standard;
    ControlButtonVisualState visual(ControlResourceUsage usage) =>
        ControlButtonVisualState.resolve(
          affordable: true,
          cooldownTicksLeft: 0,
          backgroundColor: theme.run.backgroundColor,
          foregroundColor: theme.run.foregroundColor,
          resources: usage,
          theme: theme,
        );
    expect(
      visual(ControlResourceUsage.none).backgroundColor,
      theme.run.backgroundColor,
    );
    final mana = visual(const ControlResourceUsage(mana: true));
    expect(mana.backgroundGradient, isNull);
    expect(mana.backgroundColor.a, closeTo(0.58, 0.01));
    expect(
      mana.backgroundColor.computeLuminance(),
      lessThan(UiResourceColors.mana.computeLuminance() * 0.3),
    );
    final mixed = visual(
      const ControlResourceUsage(health: true, stamina: true),
    );
    final gradient = mixed.backgroundGradient! as LinearGradient;
    expect(gradient.colors, hasLength(2));
    expect(
      gradient.colors.map((color) => color.a),
      everyElement(closeTo(0.58, 0.01)),
    );
    expect(gradient.colors.first.r, greaterThan(gradient.colors.first.g));
    expect(gradient.colors.last.g, greaterThan(gradient.colors.last.r));
  });
}
