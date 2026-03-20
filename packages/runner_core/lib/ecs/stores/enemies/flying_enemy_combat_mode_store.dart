import '../../entity_id.dart';
import '../../sparse_set.dart';

/// High-level combat mode for flying enemies.
///
/// - [projectile]: keep spacing to cast ranged attacks.
/// - [meleeFallback]: close distance and commit melee fallback attacks.
enum FlyingEnemyCombatMode { projectile, meleeFallback }

class FlyingEnemyCombatModeDef {
  const FlyingEnemyCombatModeDef({
    this.mode = FlyingEnemyCombatMode.projectile,
    this.requiresFallbackStrike = false,
  });

  final FlyingEnemyCombatMode mode;

  /// When true, planner must keep [FlyingEnemyCombatMode.meleeFallback]
  /// until one fallback melee strike has been committed.
  final bool requiresFallbackStrike;
}

/// Per flying-enemy combat mode selected by planner systems.
class FlyingEnemyCombatModeStore extends SparseSet {
  final List<FlyingEnemyCombatMode> mode = <FlyingEnemyCombatMode>[];
  final List<bool> requiresFallbackStrike = <bool>[];

  void add(
    EntityId entity, [
    FlyingEnemyCombatModeDef def = const FlyingEnemyCombatModeDef(),
  ]) {
    final i = addEntity(entity);
    mode[i] = def.mode;
    requiresFallbackStrike[i] = def.requiresFallbackStrike;
  }

  @override
  void onDenseAdded(int denseIndex) {
    mode.add(FlyingEnemyCombatMode.projectile);
    requiresFallbackStrike.add(false);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    mode[removeIndex] = mode[lastIndex];
    requiresFallbackStrike[removeIndex] = requiresFallbackStrike[lastIndex];
    mode.removeLast();
    requiresFallbackStrike.removeLast();
  }
}
