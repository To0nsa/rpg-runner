import '../../../abilities/ability_def.dart';
import '../../../snapshots/enums.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Movement state for platformer-style motion (dash timers + facing).
///
/// Contains transient movement state counters:
/// - Active dash state (duration, direction)
///
/// **Note**: Dash *cooldown* is now managed by [CooldownStore] using
/// [CooldownGroup.mobility]. Follow-ups never reset that shared cooldown.
class MovementStore extends SparseSet {
  /// Ticks remaining in active dash. 0 = not dashing.
  final List<int> dashTicksLeft = <int>[];

  /// Direction of current dash (-1.0 or 1.0).
  final List<double> dashDirX = <double>[];
  final List<double> dashDirY = <double>[];

  /// Dash speed multiplier sampled at commit-time.
  final List<double> dashSpeedScale = <double>[];
  final List<double> mobilitySpeedX = <double>[];

  final List<AbilityKey?> recastAbilityId = <AbilityKey?>[];
  final List<int> recastOpensAtTick = <int>[];
  final List<int> recastExpiresAtTick = <int>[];

  /// Arms one follow-up in the half-open runtime-tick interval [opens, expires).
  /// The caller bounds expiry by the first burst's cooldown expiry.
  void armRecast(EntityId entity, AbilityKey ability, int opens, int expires) {
    final i = indexOf(entity);
    recastAbilityId[i] = ability;
    recastOpensAtTick[i] = opens;
    recastExpiresAtTick[i] = expires;
  }

  /// Consumes or cancels a follow-up without changing the shared cooldown.
  void clearRecast(EntityId entity) {
    final i = tryIndexOf(entity);
    if (i == null) return;
    recastAbilityId[i] = null;
    recastOpensAtTick[i] = 0;
    recastExpiresAtTick[i] = 0;
  }

  /// Checks follow-up identity and time, independently of resources and locks.
  /// Activation precedes movement's timer decrement, so a remaining count of
  /// one is the first tick on which the previous burst no longer moves.
  bool canRecast(EntityId entity, AbilityKey ability, int tick) {
    final i = tryIndexOf(entity);
    return i != null &&
        recastAbilityId[i] == ability &&
        tick >= recastOpensAtTick[i] &&
        tick < recastExpiresAtTick[i] &&
        dashTicksLeft[i] <= 1;
  }

  final List<Facing> facing = <Facing>[];
  final List<Facing> artFacing = <Facing>[];
  final List<int> facingLockTicksLeft = <int>[];

  void add(EntityId entity, {required Facing facing, Facing? artFacing}) {
    final i = addEntity(entity);
    this.facing[i] = facing;
    this.artFacing[i] = artFacing ?? facing;
  }

  bool isDashing(EntityId entity) => dashTicksLeft[indexOf(entity)] > 0;

  @override
  void onDenseAdded(int denseIndex) {
    dashTicksLeft.add(0);
    dashDirX.add(1);
    dashDirY.add(0);
    dashSpeedScale.add(1.0);
    mobilitySpeedX.add(0.0);
    recastAbilityId.add(null);
    recastOpensAtTick.add(0);
    recastExpiresAtTick.add(0);
    facing.add(Facing.right);
    artFacing.add(Facing.right);
    facingLockTicksLeft.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    dashTicksLeft[removeIndex] = dashTicksLeft[lastIndex];
    dashDirX[removeIndex] = dashDirX[lastIndex];
    dashDirY[removeIndex] = dashDirY[lastIndex];
    dashSpeedScale[removeIndex] = dashSpeedScale[lastIndex];
    mobilitySpeedX[removeIndex] = mobilitySpeedX[lastIndex];
    recastAbilityId[removeIndex] = recastAbilityId[lastIndex];
    recastOpensAtTick[removeIndex] = recastOpensAtTick[lastIndex];
    recastExpiresAtTick[removeIndex] = recastExpiresAtTick[lastIndex];
    facing[removeIndex] = facing[lastIndex];
    artFacing[removeIndex] = artFacing[lastIndex];
    facingLockTicksLeft[removeIndex] = facingLockTicksLeft[lastIndex];

    dashTicksLeft.removeLast();
    dashDirX.removeLast();
    dashDirY.removeLast();
    dashSpeedScale.removeLast();
    mobilitySpeedX.removeLast();
    recastAbilityId.removeLast();
    recastOpensAtTick.removeLast();
    recastExpiresAtTick.removeLast();
    facing.removeLast();
    artFacing.removeLast();
    facingLockTicksLeft.removeLast();
  }
}
