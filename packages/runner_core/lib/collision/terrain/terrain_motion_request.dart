import 'terrain_numeric.dart';

/// Actor-neutral interpretation of one requested terrain displacement.
enum TerrainMotionMode {
  /// Ordinary supported locomotion preserves its tuned world-X displacement.
  groundedHorizontal,

  /// Supported mobility preserves scalar distance along eligible surfaces.
  groundedSurface,

  /// Airborne, launch, knockback, and landing motion remains world-space.
  worldSpace,
}

/// Immutable quantized displacement request consumed by terrain motion.
///
/// Gravity remains separate so retained support can consume it as contact bias
/// without turning it into passive downhill speed. Allocation-sensitive
/// authorities use the controller's primitive-value entry point instead of
/// weakening this immutable public contract.
class TerrainMotionRequest {
  factory TerrainMotionRequest({
    required int displacementXTicks,
    required int displacementYTicks,
    int gravityXTicks = 0,
    int gravityYTicks = 0,
    int surfaceDirectionSign = 1,
    required TerrainMotionMode mode,
  }) {
    _validateTicks(displacementXTicks, 'displacementXTicks');
    _validateTicks(displacementYTicks, 'displacementYTicks');
    _validateTicks(gravityXTicks, 'gravityXTicks');
    _validateTicks(gravityYTicks, 'gravityYTicks');
    if (surfaceDirectionSign != -1 && surfaceDirectionSign != 1) {
      throw ArgumentError.value(
        surfaceDirectionSign,
        'surfaceDirectionSign',
        'Must be -1 or 1.',
      );
    }
    return TerrainMotionRequest._(
      displacementXTicks: displacementXTicks,
      displacementYTicks: displacementYTicks,
      gravityXTicks: gravityXTicks,
      gravityYTicks: gravityYTicks,
      surfaceDirectionSign: surfaceDirectionSign,
      mode: mode,
    );
  }

  const TerrainMotionRequest._({
    required this.displacementXTicks,
    required this.displacementYTicks,
    required this.gravityXTicks,
    required this.gravityYTicks,
    required this.surfaceDirectionSign,
    required this.mode,
  });

  /// Authored/control displacement in physics ticks.
  final int displacementXTicks;
  final int displacementYTicks;

  /// Gravity contribution in physics ticks, kept separate from control motion.
  final int gravityXTicks;
  final int gravityYTicks;

  /// Committed horizontal/facing sign for supported surface-distance motion.
  final int surfaceDirectionSign;

  /// Constraint semantics used if support or blockers are encountered.
  final TerrainMotionMode mode;

  /// Full world-space X displacement before support handling.
  int get composedXTicks => displacementXTicks + gravityXTicks;

  /// Full world-space Y displacement before support handling.
  int get composedYTicks => displacementYTicks + gravityYTicks;
}

void _validateTicks(int value, String name) {
  if (value.abs() > terrainMaxAbsPhysicsTicks) {
    throw RangeError.range(
      value,
      -terrainMaxAbsPhysicsTicks,
      terrainMaxAbsPhysicsTicks,
      name,
    );
  }
}
