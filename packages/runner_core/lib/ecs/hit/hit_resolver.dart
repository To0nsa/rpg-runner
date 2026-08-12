import 'dart:math' as math;

import '../../combat/faction.dart';
import '../entity_id.dart';
import '../spatial/broadphase_grid.dart';
import 'aabb_hit_utils.dart';
import 'capsule_hit_utils.dart';

/// Shared capsule narrow phase and deterministic hit candidate ordering.
///
/// The spatial grid supplies conservative AABB candidates. This resolver owns
/// exact attack-capsule versus target-capsule confirmation, owner/faction
/// filtering, and stable entity-ID order. It never mutates the ECS world.
class HitResolver {
  final List<int> _candidates = <int>[];

  /// Collects all target capsules intersecting the supplied attack capsule.
  ///
  /// Results exclude the owner and allies and are ordered by stable entity ID.
  void collectOrderedOverlapsCapsule({
    required BroadphaseGrid broadphase,
    required double ax,
    required double ay,
    required double bx,
    required double by,
    required double radius,
    required EntityId owner,
    required Faction sourceFaction,
    required List<int> outTargetIndices,
  }) {
    outTargetIndices.clear();

    final hasCandidates = _prepareCandidates(
      broadphase: broadphase,
      minX: math.min(ax, bx) - radius,
      minY: math.min(ay, by) - radius,
      maxX: math.max(ax, bx) + radius,
      maxY: math.max(ay, by) + radius,
    );
    if (!hasCandidates) return;

    for (var i = 0; i < _candidates.length; i += 1) {
      final targetIndex = _candidates[i];
      if (!_isValidTarget(targetIndex, broadphase, owner, sourceFaction) ||
          !_attackOverlapsTarget(
            broadphase: broadphase,
            targetIndex: targetIndex,
            ax: ax,
            ay: ay,
            bx: bx,
            by: by,
            radius: radius,
          )) {
        continue;
      }
      outTargetIndices.add(targetIndex);
    }
  }

  /// Returns the lowest-ID target capsule intersecting the attack capsule.
  int? firstOrderedOverlapCapsule({
    required BroadphaseGrid broadphase,
    required double ax,
    required double ay,
    required double bx,
    required double by,
    required double radius,
    required EntityId owner,
    required Faction sourceFaction,
  }) {
    final hasCandidates = _prepareCandidates(
      broadphase: broadphase,
      minX: math.min(ax, bx) - radius,
      minY: math.min(ay, by) - radius,
      maxX: math.max(ax, bx) + radius,
      maxY: math.max(ay, by) + radius,
    );
    if (!hasCandidates) return null;

    for (var i = 0; i < _candidates.length; i += 1) {
      final targetIndex = _candidates[i];
      if (!_isValidTarget(targetIndex, broadphase, owner, sourceFaction) ||
          !_attackOverlapsTarget(
            broadphase: broadphase,
            targetIndex: targetIndex,
            ax: ax,
            ay: ay,
            bx: bx,
            by: by,
            radius: radius,
          )) {
        continue;
      }
      return targetIndex;
    }

    return null;
  }

  bool _attackOverlapsTarget({
    required BroadphaseGrid broadphase,
    required int targetIndex,
    required double ax,
    required double ay,
    required double bx,
    required double by,
    required double radius,
  }) => capsulesOverlap(
    firstAx: ax,
    firstAy: ay,
    firstBx: bx,
    firstBy: by,
    firstRadius: radius,
    secondAx: broadphase.targets.capsuleAx[targetIndex],
    secondAy: broadphase.targets.capsuleAy[targetIndex],
    secondBx: broadphase.targets.capsuleBx[targetIndex],
    secondBy: broadphase.targets.capsuleBy[targetIndex],
    secondRadius: broadphase.targets.capsuleRadius[targetIndex],
  );

  bool _prepareCandidates({
    required BroadphaseGrid broadphase,
    required double minX,
    required double minY,
    required double maxX,
    required double maxY,
  }) {
    broadphase.queryAabbMinMax(
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      outTargetIndices: _candidates,
    );
    if (_candidates.isEmpty) return false;

    // Candidate cell order is not authoritative; entity identity is.
    _candidates.sort(
      (a, b) => broadphase.targets.entities[a].compareTo(
        broadphase.targets.entities[b],
      ),
    );
    return true;
  }

  bool _isValidTarget(
    int targetIndex,
    BroadphaseGrid broadphase,
    EntityId owner,
    Faction sourceFaction,
  ) {
    final target = broadphase.targets.entities[targetIndex];
    return target != owner &&
        !areAllies(sourceFaction, broadphase.targets.factions[targetIndex]);
  }
}
