/// Navigation tuning for surface-graph based AI.
///
/// This is intentionally separate from movement/combat tunings:
/// - movement tuning controls the player's physical feel
/// - enemy tuning controls per-enemy locomotion abilities
/// - navigation tuning controls pathfinding + graph build tradeoffs
library;
import '../navigation/types/nav_tolerances.dart';

class NavigationTuning {
  const NavigationTuning({
    this.repathCooldownTicks = 12,
    this.maxExpandedNodes = 128,
    this.edgePenaltySeconds = 0.05,
    this.surfaceEps = navSpatialEps,
    this.takeoffEpsMin = 4.0,
    this.takeoffSampleMaxStep = 64.0,
  }) : assert(repathCooldownTicks >= 0),
       assert(maxExpandedNodes > 0),
       assert(edgePenaltySeconds >= 0.0),
       assert(surfaceEps > 0.0),
       assert(takeoffEpsMin >= 0.0),
       assert(takeoffSampleMaxStep > 0.0);

  /// Throttle replans per entity to avoid per-tick A* on mobile.
  ///
  /// Default `12` ticks is ~200 ms at 60 Hz: responsive enough for pursuit
  /// changes while still avoiding per-frame replanning churn.
  final int repathCooldownTicks;

  /// Hard cap on A* node expansions (fail fast deterministically).
  final int maxExpandedNodes;

  /// Small per-edge penalty that biases toward fewer hops when costs tie.
  final double edgePenaltySeconds;

  /// Vertical tolerance when locating the current/target surface (world units).
  final double surfaceEps;

  /// Minimum horizontal tolerance for "close enough to takeoff" (world units).
  ///
  /// The actual takeoff epsilon can be increased by the locomotion controller
  /// (e.g. tied to an enemy's stop distance) to avoid "stops too early to jump".
  /// Default `4` units gives stable jump/drop triggering for slower movers
  /// that do not override this with a larger stop distance.
  final double takeoffEpsMin;

  /// Maximum step between takeoff samples on long surfaces (world units).
  final double takeoffSampleMaxStep;
}
