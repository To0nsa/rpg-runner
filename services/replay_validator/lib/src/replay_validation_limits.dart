/// Hard resource ceilings applied before and during replay simulation.
///
/// Byte fields are raw byte counts; nesting and frame fields are collection
/// counts. Duration limits separate authored run length from worker wall time.
final class ReplayValidationLimits {
  const ReplayValidationLimits({
    this.maxCompressedBytes = 8 * 1024 * 1024,
    this.maxExpandedBytes = 32 * 1024 * 1024,
    this.maxJsonNestingDepth = 64,
    this.maxCommandFrames = 250000,
    this.maxRunDuration = const Duration(hours: 6),
    this.maxSimulationWallTime = const Duration(minutes: 2),
  });

  final int maxCompressedBytes;
  final int maxExpandedBytes;
  final int maxJsonNestingDepth;
  final int maxCommandFrames;
  final Duration maxRunDuration;
  final Duration maxSimulationWallTime;

  /// Rejects a configuration that cannot provide a finite validation budget.
  void validate() {
    if (maxCompressedBytes <= 0) {
      throw ArgumentError.value(
        maxCompressedBytes,
        'maxCompressedBytes',
        'must be positive',
      );
    }
    if (maxExpandedBytes < maxCompressedBytes) {
      throw ArgumentError.value(
        maxExpandedBytes,
        'maxExpandedBytes',
        'must be at least maxCompressedBytes',
      );
    }
    if (maxJsonNestingDepth <= 0) {
      throw ArgumentError.value(
        maxJsonNestingDepth,
        'maxJsonNestingDepth',
        'must be positive',
      );
    }
    if (maxCommandFrames <= 0) {
      throw ArgumentError.value(
        maxCommandFrames,
        'maxCommandFrames',
        'must be positive',
      );
    }
    if (maxRunDuration <= Duration.zero) {
      throw ArgumentError.value(
        maxRunDuration,
        'maxRunDuration',
        'must be positive',
      );
    }
    if (maxSimulationWallTime <= Duration.zero) {
      throw ArgumentError.value(
        maxSimulationWallTime,
        'maxSimulationWallTime',
        'must be positive',
      );
    }
  }
}
