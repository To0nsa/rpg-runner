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

  /// Presentation-only deficits against a snapshot's resolved commit cost.
  /// Callers must still use Core slot validity/affordability to gate controls.
  /// Health costs must leave at least one fixed-point unit alive.
  factory ControlResourceUsage.shortfall({
    required AbilityResourceCost cost,
    required double health,
    required double mana,
    required double stamina,
  }) => ControlResourceUsage(
    health:
        cost.healthCost100 > 0 && (health * 100).round() <= cost.healthCost100,
    mana: (mana * 100).round() < cost.manaCost100,
    stamina: (stamina * 100).round() < cost.staminaCost100,
  );

  bool get isEmpty => !health && !mana && !stamina;

  final bool health;
  final bool mana;
  final bool stamina;
}
