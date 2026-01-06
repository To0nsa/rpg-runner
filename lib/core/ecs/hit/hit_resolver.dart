import 'dart:math' as math;

import '../../combat/faction.dart';
import '../entity_id.dart';
import '../spatial/broadphase_grid.dart';
import 'aabb_hit_utils.dart';
import 'capsule_hit_utils.dart';

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
    outTargetIndices.clear();
    final hasCandidates = _prepareCandidates(
      broadphase: broadphase,
      minX: centerX - halfX,
      minY: centerY - halfY,
      maxX: centerX + halfX,
      maxY: centerY + halfY,
    );
    if (!hasCandidates) return;

    for (var i = 0; i < _candidates.length; i += 1) {
      final targetIndex = _candidates[i];
      if (!_isValidTarget(targetIndex, broadphase, owner, sourceFaction)) {
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
    final hasCandidates = _prepareCandidates(
      broadphase: broadphase,
      minX: centerX - halfX,
      minY: centerY - halfY,
      maxX: centerX + halfX,
      maxY: centerY + halfY,
    );
    if (!hasCandidates) return null;

    for (var i = 0; i < _candidates.length; i += 1) {
      final targetIndex = _candidates[i];
      if (!_isValidTarget(targetIndex, broadphase, owner, sourceFaction)) {
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

  /// Returns an ordered list of target indices (into `broadphase.targets`) that
  /// overlap the query capsule and pass filtering rules.
  ///
  /// Determinism: targets are always returned in `EntityId` ascending order.
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
      if (!_isValidTarget(targetIndex, broadphase, owner, sourceFaction)) {
        continue;
      }

      final targetCenterX = broadphase.targets.centerX[targetIndex];
      final targetCenterY = broadphase.targets.centerY[targetIndex];
      final targetHalfX = broadphase.targets.halfX[targetIndex];
      final targetHalfY = broadphase.targets.halfY[targetIndex];

      if (!capsuleIntersectsAabb(
        ax: ax,
        ay: ay,
        bx: bx,
        by: by,
        radius: radius,
        minX: targetCenterX - targetHalfX,
        minY: targetCenterY - targetHalfY,
        maxX: targetCenterX + targetHalfX,
        maxY: targetCenterY + targetHalfY,
      )) {
        continue;
      }

      outTargetIndices.add(targetIndex);
    }
  }

  /// Returns the first overlapping target index (into `broadphase.targets`) in
  /// deterministic order, or null if there is no hit.
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
      if (!_isValidTarget(targetIndex, broadphase, owner, sourceFaction)) {
        continue;
      }

      final targetCenterX = broadphase.targets.centerX[targetIndex];
      final targetCenterY = broadphase.targets.centerY[targetIndex];
      final targetHalfX = broadphase.targets.halfX[targetIndex];
      final targetHalfY = broadphase.targets.halfY[targetIndex];

      if (!capsuleIntersectsAabb(
        ax: ax,
        ay: ay,
        bx: bx,
        by: by,
        radius: radius,
        minX: targetCenterX - targetHalfX,
        minY: targetCenterY - targetHalfY,
        maxX: targetCenterX + targetHalfX,
        maxY: targetCenterY + targetHalfY,
      )) {
        continue;
      }

      return targetIndex;
    }

    return null;
  }

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

    _sortCandidatesByEntityId(broadphase);
    return true;
  }

  bool _isValidTarget(
    int targetIndex,
    BroadphaseGrid broadphase,
    EntityId owner,
    Faction sourceFaction,
  ) {
    // Only check owner and friendly fire.
    // Existence and component validity is guaranteed by DamageableTargetCache logic.
    final target = broadphase.targets.entities[targetIndex];
    if (target == owner) return false;

    return !areAllies(
      sourceFaction,
      broadphase.targets.factions[targetIndex],
    );
  }

  void _sortCandidatesByEntityId(BroadphaseGrid broadphase) {
    _candidates.sort(
      (a, b) => broadphase.targets.entities[a].compareTo(
        broadphase.targets.entities[b],
      ),
    );
  }
}
