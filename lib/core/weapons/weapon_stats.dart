/// Passive stat modifiers provided by a weapon.
///
/// These are not consumed by runtime systems in Phase 2 but provide
/// the data foundation for future damage/crit scaling.
class WeaponStats {
  const WeaponStats({
    this.powerBonusBp = 0,
    this.critChanceBonusBp = 0,
    this.critDamageBonusBp = 0,
    this.rangeScalarPercent = 100,
  }) : assert(rangeScalarPercent > 0, 'rangeScalarPercent must be > 0');

  /// Additive power bonus in Basis Points (100 = 1%).
  final int powerBonusBp;

  /// Additive crit chance bonus in Basis Points (100 = 1%).
  final int critChanceBonusBp;

  /// Additive crit damage bonus in Basis Points (100 = 1%).
  final int critDamageBonusBp;

  /// Multiplicative range modifier relative to 100 (100 = unchanged).
  final int rangeScalarPercent;
}
