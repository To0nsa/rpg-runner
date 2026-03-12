import '../../abilities/ability_def.dart';
import '../entity_id.dart';

/// Tracks per-source mobility contact hit state for one active ability lifecycle.
///
/// This supports mobility impact hit policies without spawning synthetic hitboxes.
class MobilityImpactStateStore {
  final List<EntityId> denseEntities = <EntityId>[];
  final Map<EntityId, int> _sparse = <EntityId, int>{};

  /// Active ability startTick currently tracked for each source entity.
  final List<int> activationStartTick = <int>[];

  /// For [HitPolicy.once]: whether one contact has already been consumed.
  final List<bool> consumedOnce = <bool>[];

  /// For [HitPolicy.oncePerTarget]: compact tracked target set count.
  final List<int> hitCount = <int>[];
  final List<EntityId> hit0 = <EntityId>[];
  final List<EntityId> hit1 = <EntityId>[];
  final List<EntityId> hit2 = <EntityId>[];
  final List<EntityId> hit3 = <EntityId>[];
  final List<EntityId> hit4 = <EntityId>[];
  final List<EntityId> hit5 = <EntityId>[];
  final List<EntityId> hit6 = <EntityId>[];
  final List<EntityId> hit7 = <EntityId>[];

  int indexOfOrAdd(EntityId entity) {
    final existing = _sparse[entity];
    if (existing != null) return existing;
    final i = denseEntities.length;
    denseEntities.add(entity);
    _sparse[entity] = i;
    activationStartTick.add(-1);
    consumedOnce.add(false);
    hitCount.add(0);
    hit0.add(0);
    hit1.add(0);
    hit2.add(0);
    hit3.add(0);
    hit4.add(0);
    hit5.add(0);
    hit6.add(0);
    hit7.add(0);
    return i;
  }

  /// Returns true if the contact should apply according to [hitPolicy].
  bool registerImpact({
    required EntityId source,
    required EntityId target,
    required int activationTick,
    required HitPolicy hitPolicy,
  }) {
    final i = indexOfOrAdd(source);
    if (activationStartTick[i] != activationTick) {
      _resetActivation(i, activationTick);
    }

    switch (hitPolicy) {
      case HitPolicy.everyTick:
        return true;
      case HitPolicy.once:
        if (consumedOnce[i]) return false;
        consumedOnce[i] = true;
        return true;
      case HitPolicy.oncePerTarget:
        if (_hasHit(i, target)) return false;
        _markHit(i, target);
        return true;
    }
  }

  void _resetActivation(int index, int activationTick) {
    activationStartTick[index] = activationTick;
    consumedOnce[index] = false;
    hitCount[index] = 0;
  }

  bool _hasHit(int index, EntityId target) {
    final c = hitCount[index];
    if (c > _maxTrackedTargets) return true; // saturated
    if (c <= 0) return false;
    if (hit0[index] == target) return true;
    if (c <= 1) return false;
    if (hit1[index] == target) return true;
    if (c <= 2) return false;
    if (hit2[index] == target) return true;
    if (c <= 3) return false;
    if (hit3[index] == target) return true;
    if (c <= 4) return false;
    if (hit4[index] == target) return true;
    if (c <= 5) return false;
    if (hit5[index] == target) return true;
    if (c <= 6) return false;
    if (hit6[index] == target) return true;
    if (c <= 7) return false;
    return hit7[index] == target;
  }

  void _markHit(int index, EntityId target) {
    final c = hitCount[index];
    if (c > _maxTrackedTargets) return;
    if (c <= 0) {
      hit0[index] = target;
      hitCount[index] = 1;
      return;
    }
    if (c == 1) {
      hit1[index] = target;
      hitCount[index] = 2;
      return;
    }
    if (c == 2) {
      hit2[index] = target;
      hitCount[index] = 3;
      return;
    }
    if (c == 3) {
      hit3[index] = target;
      hitCount[index] = 4;
      return;
    }
    if (c == 4) {
      hit4[index] = target;
      hitCount[index] = 5;
      return;
    }
    if (c == 5) {
      hit5[index] = target;
      hitCount[index] = 6;
      return;
    }
    if (c == 6) {
      hit6[index] = target;
      hitCount[index] = 7;
      return;
    }
    if (c == 7) {
      hit7[index] = target;
      hitCount[index] = 8;
      return;
    }
    hitCount[index] = _maxTrackedTargets + 1;
  }

  void removeEntity(EntityId entity) {
    final i = _sparse.remove(entity);
    if (i == null) return;

    final last = denseEntities.length - 1;
    if (i != last) {
      final moved = denseEntities[last];
      denseEntities[i] = moved;
      _sparse[moved] = i;
      activationStartTick[i] = activationStartTick[last];
      consumedOnce[i] = consumedOnce[last];
      hitCount[i] = hitCount[last];
      hit0[i] = hit0[last];
      hit1[i] = hit1[last];
      hit2[i] = hit2[last];
      hit3[i] = hit3[last];
      hit4[i] = hit4[last];
      hit5[i] = hit5[last];
      hit6[i] = hit6[last];
      hit7[i] = hit7[last];
    }

    denseEntities.removeLast();
    activationStartTick.removeLast();
    consumedOnce.removeLast();
    hitCount.removeLast();
    hit0.removeLast();
    hit1.removeLast();
    hit2.removeLast();
    hit3.removeLast();
    hit4.removeLast();
    hit5.removeLast();
    hit6.removeLast();
    hit7.removeLast();
  }

  static const int _maxTrackedTargets = 8;
}
