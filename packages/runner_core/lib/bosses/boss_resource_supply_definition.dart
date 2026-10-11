/// One adaptive mana/stamina pickup earned by a living boss's health milestone.
/// Attach this to any boss catalog entry; arena occurrence owns consumption.
final class BossResourceSupplyDefinition {
  const BossResourceSupplyDefinition({required this.healthThresholdBp})
    : assert(healthThresholdBp > 0 && healthThresholdBp < 10000);

  /// Remaining boss health in basis points of maximum (5000 = 50%).
  final int healthThresholdBp;
}
