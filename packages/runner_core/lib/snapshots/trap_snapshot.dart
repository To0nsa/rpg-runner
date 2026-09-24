import '../traps/trap_placement.dart';
import 'enums.dart';

enum TrapPhase { idle, warning, active, cooldown, waitingForClear }

/// Authoritative trap pose, independent of renderer animation clocks.
final class TrapSnapshot {
  const TrapSnapshot({
    required this.source,
    required this.x,
    required this.y,
    required this.facing,
    required this.phase,
    required this.frameIndex,
    required this.zIndex,
  });
  final TrapSourceRef source;
  final double x;
  final double y;
  final Facing facing;
  final TrapPhase phase;
  final int frameIndex;

  /// Immutable terrain-relative visual order, independent of attack phase.
  final int zIndex;
}
