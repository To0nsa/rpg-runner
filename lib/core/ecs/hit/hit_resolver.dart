import '../../combat/faction.dart';
import '../entity_id.dart';
import '../spatial/broadphase_grid.dart';
import 'aabb_hit_utils.dart';

/// Shared narrowphase + deterministic hit candidate ordering.
///
/// Responsibilities:
/// - broadphase query
/// - filtering (owner exclusion + friendly-fire)
/// - AABB overlap test
/// - deterministic ordering (EntityId ascending)
///
/// Non-responsibilities:
/// - world mutation (damage, despawns, HitOnce marking)
class HitResolver {
  final List<int> _candidates = <int>[];

  /// Returns an ordered list of target indices (into `broadphase.targets`) that
  /// overlap the query AABB and pass filtering rules.
  ///
  /// Determinism: targets are always returned in `EntityId` ascending order.
  void collectOrderedOverlapsCenters({
    required BroadphaseGrid broadphase,
    required double centerX,
    required double centerY,
    required double halfX,
    required double halfY,
    required EntityId owner,
    required Faction sourceFaction,
    required List<int> outTargetIndices,
  }) {
    broadphase.queryAabbMinMax(
      minX: centerX - halfX,
      minY: centerY - halfY,
      maxX: centerX + halfX,
      maxY: centerY + halfY,
      outTargetIndices: _candidates,
    );

    outTargetIndices.clear();
    if (_candidates.isEmpty) return;

    _sortCandidatesByEntityId(broadphase);

    for (var i = 0; i < _candidates.length; i += 1) {
      final targetIndex = _candidates[i];
      final target = broadphase.targets.entities[targetIndex];
      if (target == owner) continue;

      if (isFriendlyFire(sourceFaction, broadphase.targets.factions[targetIndex])) {
        continue;
      }

      if (!aabbOverlapsCenters(
        aCenterX: centerX,
        aCenterY: centerY,
        aHalfX: halfX,
        aHalfY: halfY,
        bCenterX: broadphase.targets.centerX[targetIndex],
        bCenterY: broadphase.targets.centerY[targetIndex],
        bHalfX: broadphase.targets.halfX[targetIndex],
        bHalfY: broadphase.targets.halfY[targetIndex],
      )) {
        continue;
      }

      outTargetIndices.add(targetIndex);
    }
  }

  /// Returns the first overlapping target index (into `broadphase.targets`) in
  /// deterministic order, or null if there is no hit.
  int? firstOrderedOverlapCenters({
    required BroadphaseGrid broadphase,
    required double centerX,
    required double centerY,
    required double halfX,
    required double halfY,
    required EntityId owner,
    required Faction sourceFaction,
  }) {
    broadphase.queryAabbMinMax(
      minX: centerX - halfX,
      minY: centerY - halfY,
      maxX: centerX + halfX,
      maxY: centerY + halfY,
      outTargetIndices: _candidates,
    );
    if (_candidates.isEmpty) return null;

    _sortCandidatesByEntityId(broadphase);

    for (var i = 0; i < _candidates.length; i += 1) {
      final targetIndex = _candidates[i];
      final target = broadphase.targets.entities[targetIndex];
      if (target == owner) continue;

      if (isFriendlyFire(sourceFaction, broadphase.targets.factions[targetIndex])) {
        continue;
      }

      if (!aabbOverlapsCenters(
        aCenterX: centerX,
        aCenterY: centerY,
        aHalfX: halfX,
        aHalfY: halfY,
        bCenterX: broadphase.targets.centerX[targetIndex],
        bCenterY: broadphase.targets.centerY[targetIndex],
        bHalfX: broadphase.targets.halfX[targetIndex],
        bHalfY: broadphase.targets.halfY[targetIndex],
      )) {
        continue;
      }

      return targetIndex;
    }

    return null;
  }

  void _sortCandidatesByEntityId(BroadphaseGrid broadphase) {
    _candidates.sort(
      (a, b) => broadphase.targets.entities[a].compareTo(
        broadphase.targets.entities[b],
      ),
    );
  }
}
