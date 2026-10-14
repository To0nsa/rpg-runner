import 'package:flutter/foundation.dart';
import 'package:runner_core/abilities/ability_def.dart';

/// Resources a control should identify, independently of current affordability.
/// Includes ongoing hold drain so a free-to-start guard still signals stamina.
@immutable
class ControlResourceUsage {
  const ControlResourceUsage({
    this.health = false,
    this.mana = false,
    this.stamina = false,
  });

  factory ControlResourceUsage.fromAbility({
    required AbilityDef? ability,
    required AbilityResourceCost cost,
  }) => ControlResourceUsage(
    health: cost.healthCost100 > 0,
    mana: cost.manaCost100 > 0,
    stamina:
        cost.staminaCost100 > 0 ||
        (ability?.holdStaminaDrainPerSecond100 ?? 0) > 0,
  );

  /// The menu shows both ground and air-jump resources before entering a run.
  factory ControlResourceUsage.forPreview({
    required AbilityDef? ability,
    required AbilityResourceCost cost,
  }) {
    final airCost = ability?.airJumpCost ?? AbilityResourceCost.zero;
    return ControlResourceUsage.fromAbility(
      ability: ability,
      cost: AbilityResourceCost(
        healthCost100: cost.healthCost100 + airCost.healthCost100,
        manaCost100: cost.manaCost100 + airCost.manaCost100,
        staminaCost100: cost.staminaCost100 + airCost.staminaCost100,
      ),
    );
  }

  static const none = ControlResourceUsage();

  final bool health;
  final bool mana;
  final bool stamina;
}
