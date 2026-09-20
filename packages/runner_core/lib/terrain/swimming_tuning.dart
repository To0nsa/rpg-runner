/// Shared swimming rules in world units and seconds; Core resolves tick timing.
abstract final class SwimmingTuning {
  /// Enter at 45% vertical immersion and leave below 25% to avoid surface flicker.
  static const int enterImmersion1000 = 450;
  static const int exitImmersion1000 = 250;

  /// Upward stroke speed in px/s, sufficient to clear a bank at surface height.
  static const double strokeSpeed = 260;

  /// Minimum time between strokes in seconds; limits input-spam acceleration.
  static const double strokeIntervalSeconds = 0.20;

  /// Buoyancy cancels 88% of gravity while immersed, leaving a gentle descent.
  static const double gravityMultiplier = 0.12;

  /// Downward terminal speed in px/s; upward strokes retain their launch speed.
  static const double maxSinkSpeed = 42;

  /// Water caps horizontal cruising speed at 80% of the dry-land target so
  /// swimming remains a meaningful traversal penalty.
  static const double maxSpeedMultiplier = 0.8;

  /// Water also makes changes in horizontal momentum feel heavier.
  static const double accelerationMultiplier = 0.5;
  static const double decelerationMultiplier = 0.45;

  /// Enemy depth tolerance in px, avoiding repeated strokes at chase depth.
  static const double enemyDepthSlack = 6;

  /// Maximum drop in px from a bank to water admitted by local entry steering.
  /// Deeper dry drops still require an ordinary terrain-navigation route.
  static const double enemyEntryMaxDrop = 64;
}
