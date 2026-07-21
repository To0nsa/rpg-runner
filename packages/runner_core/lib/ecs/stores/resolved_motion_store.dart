import '../../collision/terrain/terrain_motion_request.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Per-tick quantized request and actual displacement produced by world motion.
///
/// [supportedTravelTicks] measures signed distance along eligible support and
/// intentionally excludes overlap recovery, snap, and vertical step legs.
class ResolvedMotionStore extends SparseSet {
  final List<int> startCapsuleCenterXTicks = <int>[];
  final List<int> startCapsuleCenterYTicks = <int>[];
  final List<int> requestedXTicks = <int>[];
  final List<int> requestedYTicks = <int>[];
  final List<int> gravityXTicks = <int>[];
  final List<int> gravityYTicks = <int>[];
  final List<int> resolvedXTicks = <int>[];
  final List<int> resolvedYTicks = <int>[];
  final List<int> supportedTravelTicks = <int>[];
  final List<int> appliedGravityVelocityDeltaYTicks = <int>[];
  final List<int> locomotionReferenceSpeedTicksPerSecond = <int>[];
  final List<TerrainMotionMode> mode = <TerrainMotionMode>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  /// Clears the prior result and records the immutable request for this tick.
  void beginTick(
    EntityId entity, {
    required int capsuleCenterXTicks,
    required int capsuleCenterYTicks,
    required TerrainMotionRequest request,
  }) {
    final index = indexOf(entity);
    startCapsuleCenterXTicks[index] = capsuleCenterXTicks;
    startCapsuleCenterYTicks[index] = capsuleCenterYTicks;
    requestedXTicks[index] = request.displacementXTicks;
    requestedYTicks[index] = request.displacementYTicks;
    gravityXTicks[index] = request.gravityXTicks;
    gravityYTicks[index] = request.gravityYTicks;
    resolvedXTicks[index] = 0;
    resolvedYTicks[index] = 0;
    supportedTravelTicks[index] = 0;
    mode[index] = request.mode;
  }

  /// Records the flat-ground speed used to normalize locomotion playback.
  void setLocomotionReferenceSpeed(
    EntityId entity, {
    required int ticksPerSecond,
  }) {
    if (ticksPerSecond < 0) {
      throw ArgumentError.value(
        ticksPerSecond,
        'ticksPerSecond',
        'Must be non-negative.',
      );
    }
    locomotionReferenceSpeedTicksPerSecond[indexOf(entity)] = ticksPerSecond;
  }

  /// Commits the final displacement after all contact policy has run.
  void setResolved(
    EntityId entity, {
    required int displacementXTicks,
    required int displacementYTicks,
    required int travelAlongSupportTicks,
  }) {
    final index = indexOf(entity);
    resolvedXTicks[index] = displacementXTicks;
    resolvedYTicks[index] = displacementYTicks;
    supportedTravelTicks[index] = travelAlongSupportTicks;
  }

  @override
  void onDenseAdded(int denseIndex) {
    startCapsuleCenterXTicks.add(0);
    startCapsuleCenterYTicks.add(0);
    requestedXTicks.add(0);
    requestedYTicks.add(0);
    gravityXTicks.add(0);
    gravityYTicks.add(0);
    resolvedXTicks.add(0);
    resolvedYTicks.add(0);
    supportedTravelTicks.add(0);
    appliedGravityVelocityDeltaYTicks.add(0);
    locomotionReferenceSpeedTicksPerSecond.add(0);
    mode.add(TerrainMotionMode.worldSpace);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    startCapsuleCenterXTicks[removeIndex] = startCapsuleCenterXTicks[lastIndex];
    startCapsuleCenterYTicks[removeIndex] = startCapsuleCenterYTicks[lastIndex];
    requestedXTicks[removeIndex] = requestedXTicks[lastIndex];
    requestedYTicks[removeIndex] = requestedYTicks[lastIndex];
    gravityXTicks[removeIndex] = gravityXTicks[lastIndex];
    gravityYTicks[removeIndex] = gravityYTicks[lastIndex];
    resolvedXTicks[removeIndex] = resolvedXTicks[lastIndex];
    resolvedYTicks[removeIndex] = resolvedYTicks[lastIndex];
    supportedTravelTicks[removeIndex] = supportedTravelTicks[lastIndex];
    appliedGravityVelocityDeltaYTicks[removeIndex] =
        appliedGravityVelocityDeltaYTicks[lastIndex];
    locomotionReferenceSpeedTicksPerSecond[removeIndex] =
        locomotionReferenceSpeedTicksPerSecond[lastIndex];
    mode[removeIndex] = mode[lastIndex];

    startCapsuleCenterXTicks.removeLast();
    startCapsuleCenterYTicks.removeLast();
    requestedXTicks.removeLast();
    requestedYTicks.removeLast();
    gravityXTicks.removeLast();
    gravityYTicks.removeLast();
    resolvedXTicks.removeLast();
    resolvedYTicks.removeLast();
    supportedTravelTicks.removeLast();
    appliedGravityVelocityDeltaYTicks.removeLast();
    locomotionReferenceSpeedTicksPerSecond.removeLast();
    mode.removeLast();
  }
}
