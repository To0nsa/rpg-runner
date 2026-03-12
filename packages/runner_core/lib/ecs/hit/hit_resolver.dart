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
  // Temporary list to hold candidates from the broadphase before processing.
  final List<int> _candidates = <int>[];

  /// Collects ALL entities intersecting the given AABB into [outTargetIndices].
  ///
  /// The results are filtered strictly (overlaps only) and loosely (owner/friendly fire),
  /// and are guaranteed to be sorted by [EntityId].
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

    // 1. Broadphase Query + deterministic sort.
    final hasCandidates = _prepareCandidates(
      broadphase: broadphase,
      minX: centerX - halfX,
      minY: centerY - halfY,
      maxX: centerX + halfX,
      maxY: centerY + halfY,
    );
    if (!hasCandidates) return;

    // 2. Narrowphase Check on processed candidates.
    for (var i = 0; i < _candidates.length; i += 1) {
      final targetIndex = _candidates[i];

      // 2a. Filter logic (Owner + Faction).
      if (!_isValidTarget(targetIndex, broadphase, owner, sourceFaction)) {
        continue;
      }

      // 2b. Exact AABB overlap test.
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

      // 3. Collect valid hit.
      outTargetIndices.add(targetIndex);
    }
  }

  /// Returns the FIRST entity intersecting the given AABB (lowest EntityId).
  int? firstOrderedOverlapCenters({
    required BroadphaseGrid broadphase,
    required double centerX,
    required double centerY,
    required double halfX,
    required double halfY,
    required EntityId owner,
    required Faction sourceFaction,
  }) {
    // 1. Broadphase Query.
    final hasCandidates = _prepareCandidates(
      broadphase: broadphase,
      minX: centerX - halfX,
      minY: centerY - halfY,
      maxX: centerX + halfX,
      maxY: centerY + halfY,
    );
    if (!hasCandidates) return null;

    // 2. Determine the first valid hit.
    for (var i = 0; i < _candidates.length; i += 1) {
      final targetIndex = _candidates[i];

      // 2a. Filter logic.
      if (!_isValidTarget(targetIndex, broadphase, owner, sourceFaction)) {
        continue;
      }

      // 2b. Exact AABB overlap test.
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

      // 3. Return immediately on first hit (Sorted by EntityId).
      return targetIndex;
    }

    return null;
  }

  /// Collects ALL entities intersecting the given capsule into [outTargetIndices].
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

    // 1. Broadphase Query using capsule AABB bounds.
    final hasCandidates = _prepareCandidates(
      broadphase: broadphase,
      minX: math.min(ax, bx) - radius,
      minY: math.min(ay, by) - radius,
      maxX: math.max(ax, bx) + radius,
      maxY: math.max(ay, by) + radius,
    );
    if (!hasCandidates) return;

    // 2. Narrowphase Check.
    for (var i = 0; i < _candidates.length; i += 1) {
      final targetIndex = _candidates[i];

      // 2a. Filter logic.
      if (!_isValidTarget(targetIndex, broadphase, owner, sourceFaction)) {
        continue;
      }

      final targetCenterX = broadphase.targets.centerX[targetIndex];
      final targetCenterY = broadphase.targets.centerY[targetIndex];
      final targetHalfX = broadphase.targets.halfX[targetIndex];
      final targetHalfY = broadphase.targets.halfY[targetIndex];

      // 2b. Capsule vs AABB intersection test.
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

      // 3. Collect valid hit.
      outTargetIndices.add(targetIndex);
    }
  }

  /// Returns the FIRST entity intersecting the given capsule (lowest EntityId).
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
    // 1. Broadphase Query.
    final hasCandidates = _prepareCandidates(
      broadphase: broadphase,
      minX: math.min(ax, bx) - radius,
      minY: math.min(ay, by) - radius,
      maxX: math.max(ax, bx) + radius,
      maxY: math.max(ay, by) + radius,
    );
    if (!hasCandidates) return null;

    // 2. Determine the first valid hit.
    for (var i = 0; i < _candidates.length; i += 1) {
      final targetIndex = _candidates[i];

      // 2a. Filter logic.
      if (!_isValidTarget(targetIndex, broadphase, owner, sourceFaction)) {
        continue;
      }

      final targetCenterX = broadphase.targets.centerX[targetIndex];
      final targetCenterY = broadphase.targets.centerY[targetIndex];
      final targetHalfX = broadphase.targets.halfX[targetIndex];
      final targetHalfY = broadphase.targets.halfY[targetIndex];

      // 2b. Capsule vs AABB intersection test.
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

      // 3. Return immediately on first hit.
      return targetIndex;
    }

    return null;
  }

  /// Helper: Runs broadphase query and sorts results by EntityId.
  ///
  /// Returns `false` if no candidates were found.
  bool _prepareCandidates({
    required BroadphaseGrid broadphase,
    required double minX,
    required double minY,
    required double maxX,
    required double maxY,
  }) {
    // 1. Get raw cell-based candidates (contains duplicates if spanning cells).
    broadphase.queryAabbMinMax(
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      outTargetIndices: _candidates,
    );
    if (_candidates.isEmpty) return false;

    // 2. Sort by EntityId to ensure deterministic order (1, 2, 3...)
    // regardless of cell iteration order.
    _sortCandidatesByEntityId(broadphase);
    return true;
  }

  /// Helper: Checks non-geometric filtering rules.
  ///
  /// - Excludes [owner] (can't hit self).
  /// - Excludes allies of [sourceFaction] (friendly fire).
  bool _isValidTarget(
    int targetIndex,
    BroadphaseGrid broadphase,
    EntityId owner,
    Faction sourceFaction,
  ) {
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
