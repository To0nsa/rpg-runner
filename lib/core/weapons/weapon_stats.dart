/// Passive stat modifiers provided by a weapon.
///
/// These are not consumed by runtime systems in Phase 2 but provide
/// the data foundation for future damage/crit scaling.
class WeaponStats {
  const WeaponStats({
    this.powerBonus = 0.0,
    this.critChanceBonus = 0.0,
    this.critDamageBonus = 0.0,
    this.rangeScalar = 1.0,
  }) : assert(rangeScalar > 0.0, 'rangeScalar must be > 0');

  /// Additive power bonus (+% or scalar, interpretation in Phase 5).
  final double powerBonus;

  /// Additive crit chance bonus (+0.05 = +5%).
  final double critChanceBonus;

  /// Additive crit damage bonus (+0.50 = +50% extra crit damage).
  final double critDamageBonus;

  /// Multiplicative range modifier (1.0 = unchanged).
  final double rangeScalar;
}
