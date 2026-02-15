/// Unified stat contribution payload emitted by all gear domains.
///
/// All values are fixed-point compatible and deterministic:
/// - basis points (bp): `100 = 1%`
/// - fixed-100 values: `100 = 1.0` (legacy aliases still accepted)
class GearStatBonuses {
  const GearStatBonuses({
    int healthBonusBp = 0,
    int? hpBonus100,
    int manaBonusBp = 0,
    int? manaBonus100,
    int staminaBonusBp = 0,
    int? staminaBonus100,
    this.defenseBonusBp = 0,
    this.globalPowerBonusBp = 0,
    this.globalCritChanceBonusBp = 0,
    this.powerBonusBp = 0,
    this.moveSpeedBonusBp = 0,
    this.cooldownReductionBp = 0,
    this.critChanceBonusBp = 0,
    this.physicalResistanceBp = 0,
    this.fireResistanceBp = 0,
    this.iceResistanceBp = 0,
    this.thunderResistanceBp = 0,
    this.acidResistanceBp = 0,
    this.darkResistanceBp = 0,
    this.bleedResistanceBp = 0,
    this.earthResistanceBp = 0,
    // Legacy/non-V1 fields kept for compatibility during migration.
    this.critDamageBonusBp = 0,
    this.rangeScalarPercent = 100,
  }) : healthBonusBp = hpBonus100 ?? healthBonusBp,
       manaBonusBp = manaBonus100 ?? manaBonusBp,
       staminaBonusBp = staminaBonus100 ?? staminaBonusBp,
       assert(rangeScalarPercent > 0, 'rangeScalarPercent must be > 0');

  static const GearStatBonuses zero = GearStatBonuses();

  /// Basis points (100 = 1%).
  final int healthBonusBp;

  /// Basis points (100 = 1%).
  final int manaBonusBp;

  /// Basis points (100 = 1%).
  final int staminaBonusBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values reduce incoming damage globally.
  final int defenseBonusBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values increase outgoing damage for all payload sources.
  final int globalPowerBonusBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values increase crit chance for all payload sources.
  final int globalCritChanceBonusBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values increase outgoing damage for the selected payload source.
  final int powerBonusBp;

  /// Basis points (100 = 1%).
  final int moveSpeedBonusBp;

  /// Basis points (100 = 1%).
  final int cooldownReductionBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values increase crit chance for the selected payload source.
  final int critChanceBonusBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values reduce physical damage taken.
  final int physicalResistanceBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values reduce fire damage taken.
  final int fireResistanceBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values reduce ice damage taken.
  final int iceResistanceBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values reduce thunder damage taken.
  final int thunderResistanceBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values reduce acid damage taken.
  final int acidResistanceBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values reduce dark damage taken.
  final int darkResistanceBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values reduce bleed damage taken.
  final int bleedResistanceBp;

  /// Basis points (100 = 1%).
  ///
  /// Positive values reduce earth damage taken.
  final int earthResistanceBp;

  /// Legacy field (not part of V1 core stat set).
  final int critDamageBonusBp;

  /// Legacy field (not part of V1 core stat set), `100 = unchanged`.
  final int rangeScalarPercent;

  /// Legacy alias retained to minimize migration surface.
  int get hpBonus100 => healthBonusBp;

  /// Legacy alias retained to minimize migration surface.
  int get manaBonus100 => manaBonusBp;

  /// Legacy alias retained to minimize migration surface.
  int get staminaBonus100 => staminaBonusBp;

  bool get isZero =>
      healthBonusBp == 0 &&
      manaBonusBp == 0 &&
      staminaBonusBp == 0 &&
      defenseBonusBp == 0 &&
      globalPowerBonusBp == 0 &&
      globalCritChanceBonusBp == 0 &&
      powerBonusBp == 0 &&
      moveSpeedBonusBp == 0 &&
      cooldownReductionBp == 0 &&
      critChanceBonusBp == 0 &&
      physicalResistanceBp == 0 &&
      fireResistanceBp == 0 &&
      iceResistanceBp == 0 &&
      thunderResistanceBp == 0 &&
      acidResistanceBp == 0 &&
      darkResistanceBp == 0 &&
      bleedResistanceBp == 0 &&
      earthResistanceBp == 0 &&
      critDamageBonusBp == 0 &&
      rangeScalarPercent == 100;

  GearStatBonuses operator +(GearStatBonuses other) {
    return GearStatBonuses(
      healthBonusBp: healthBonusBp + other.healthBonusBp,
      manaBonusBp: manaBonusBp + other.manaBonusBp,
      staminaBonusBp: staminaBonusBp + other.staminaBonusBp,
      defenseBonusBp: defenseBonusBp + other.defenseBonusBp,
      globalPowerBonusBp: globalPowerBonusBp + other.globalPowerBonusBp,
      globalCritChanceBonusBp:
          globalCritChanceBonusBp + other.globalCritChanceBonusBp,
      powerBonusBp: powerBonusBp + other.powerBonusBp,
      moveSpeedBonusBp: moveSpeedBonusBp + other.moveSpeedBonusBp,
      cooldownReductionBp: cooldownReductionBp + other.cooldownReductionBp,
      critChanceBonusBp: critChanceBonusBp + other.critChanceBonusBp,
      physicalResistanceBp: physicalResistanceBp + other.physicalResistanceBp,
      fireResistanceBp: fireResistanceBp + other.fireResistanceBp,
      iceResistanceBp: iceResistanceBp + other.iceResistanceBp,
      thunderResistanceBp: thunderResistanceBp + other.thunderResistanceBp,
      acidResistanceBp: acidResistanceBp + other.acidResistanceBp,
      darkResistanceBp: darkResistanceBp + other.darkResistanceBp,
      bleedResistanceBp: bleedResistanceBp + other.bleedResistanceBp,
      earthResistanceBp: earthResistanceBp + other.earthResistanceBp,
      critDamageBonusBp: critDamageBonusBp + other.critDamageBonusBp,
      rangeScalarPercent:
          (rangeScalarPercent * other.rangeScalarPercent) ~/ 100,
    );
  }
}
