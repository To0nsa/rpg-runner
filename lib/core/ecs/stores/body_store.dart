import '../entity_id.dart';
import '../sparse_set.dart';

/// Configuration for how an entity participates in physics.
///
/// This is intentionally "config-like" and reusable across players/enemies:
/// - `Transform` holds state (pos/vel)
/// - `Movement` holds controller-specific timers/state (coyote, dash, etc.)
/// - `Body` holds physics participation and constraints (gravity, clamps, kinematic)
class BodyDef {
  const BodyDef({
    this.enabled = true,
    this.isKinematic = false,
    this.useGravity = true,
    this.topOnlyGround = true,
    this.gravityScale = 1.0,
    this.maxVelX = 3000,
    this.maxVelY = 3000,
    this.sideMask = sideLeft | sideRight,
  });

  /// Master on/off switch for physics on this entity.
  final bool enabled;

  /// If true, physics does not integrate position/velocity (gameplay code drives it).
  final bool isKinematic;

  /// Whether gravity affects this body.
  final bool useGravity;

  /// If true, collision should resolve only top contacts (platformer-style).
  /// Used by `CollisionSystem` (later milestone).
  final bool topOnlyGround;

  /// Scale applied to global/tuning gravity (1.0 = normal gravity).
  final double gravityScale;

  /// Per-axis velocity clamps (safety caps).
  final double maxVelX;
  final double maxVelY;

  /// Horizontal collision sides bitmask (used by `CollisionSystem` later).
  final int sideMask;

  static const int sideNone = 0;
  static const int sideLeft = 1 << 0;
  static const int sideRight = 1 << 1;
}

/// SoA store for `Body` configuration.
class BodyStore extends SparseSet {
  final List<bool> enabled = <bool>[];
  final List<bool> isKinematic = <bool>[];
  final List<bool> useGravity = <bool>[];
  final List<bool> topOnlyGround = <bool>[];

  final List<double> gravityScale = <double>[];
  final List<double> maxVelX = <double>[];
  final List<double> maxVelY = <double>[];

  final List<int> sideMask = <int>[];

  void add(EntityId entity, BodyDef def) {
    final i = addEntity(entity);
    enabled[i] = def.enabled;
    isKinematic[i] = def.isKinematic;
    useGravity[i] = def.useGravity;
    topOnlyGround[i] = def.topOnlyGround;
    gravityScale[i] = def.gravityScale;
    maxVelX[i] = def.maxVelX;
    maxVelY[i] = def.maxVelY;
    sideMask[i] = def.sideMask;
  }

  @override
  void onDenseAdded(int denseIndex) {
    enabled.add(true);
    isKinematic.add(false);
    useGravity.add(true);
    topOnlyGround.add(true);
    gravityScale.add(1);
    maxVelX.add(3000);
    maxVelY.add(3000);
    sideMask.add(BodyDef.sideNone);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    enabled[removeIndex] = enabled[lastIndex];
    isKinematic[removeIndex] = isKinematic[lastIndex];
    useGravity[removeIndex] = useGravity[lastIndex];
    topOnlyGround[removeIndex] = topOnlyGround[lastIndex];
    gravityScale[removeIndex] = gravityScale[lastIndex];
    maxVelX[removeIndex] = maxVelX[lastIndex];
    maxVelY[removeIndex] = maxVelY[lastIndex];
    sideMask[removeIndex] = sideMask[lastIndex];

    enabled.removeLast();
    isKinematic.removeLast();
    useGravity.removeLast();
    topOnlyGround.removeLast();
    gravityScale.removeLast();
    maxVelX.removeLast();
    maxVelY.removeLast();
    sideMask.removeLast();
  }
}
