import 'dart:math' as math;

import '../../combat/faction.dart';
import '../../combat/hit_target_policy.dart';
import '../entity_id.dart';
import '../spatial/broadphase_grid.dart';
import 'aabb_hit_utils.dart';
import 'capsule_hit_utils.dart';
import 'capsule_sweep.dart';
import 'capsule_pose_sweep.dart';

/// Shared capsule narrow phase and deterministic hit candidate ordering.
///
/// The spatial grid supplies conservative AABB candidates. This resolver owns
/// exact attack-capsule versus target-capsule confirmation, owner/faction
/// filtering, and stable entity-ID order. It never mutates the ECS world.
class HitResolver {
  final List<int> _candidates = <int>[];
  final List<({int index, double fraction})> _sweptContacts = [];

  /// Piercing travel contacts ordered by arrival, then stable entity ID.
  void collectOrderedSweptCapsuleOverlaps({
    required BroadphaseGrid broadphase,
    required double ax,
    required double ay,
    required double bx,
    required double by,
    required double radius,
    required double deltaX,
    required double deltaY,
    required EntityId owner,
    required Faction sourceFaction,
    required List<int> outTargetIndices,
    HitTargetPolicy targetPolicy = HitTargetPolicy.hostile,
  }) {
    outTargetIndices.clear();
    _sweptContacts.clear();
    if (!_prepareCandidates(
      broadphase: broadphase,
      minX: math.min(ax, bx) + math.min(0, deltaX) - radius,
      minY: math.min(ay, by) + math.min(0, deltaY) - radius,
      maxX: math.max(ax, bx) + math.max(0, deltaX) + radius,
      maxY: math.max(ay, by) + math.max(0, deltaY) + radius,
    )) {
      return;
    }
    final targets = broadphase.targets;
    for (final i in _candidates) {
      if (!_isValidTarget(i, broadphase, owner, sourceFaction, targetPolicy)) {
        continue;
      }
      final fraction = capsuleSweepFirstContact(
        ax: ax,
        ay: ay,
        bx: bx,
        by: by,
        radius: radius,
        deltaX: deltaX,
        deltaY: deltaY,
        targetAx: targets.capsuleAx[i],
        targetAy: targets.capsuleAy[i],
        targetBx: targets.capsuleBx[i],
        targetBy: targets.capsuleBy[i],
        targetRadius: targets.capsuleRadius[i],
      );
      if (fraction != null) _sweptContacts.add((index: i, fraction: fraction));
    }
    _sweptContacts.sort((a, b) {
      final order = a.fraction.compareTo(b.fraction);
      return order != 0
          ? order
          : targets.entities[a.index].compareTo(targets.entities[b.index]);
    });
    outTargetIndices.addAll(_sweptContacts.map((contact) => contact.index));
  }

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
    HitTargetPolicy targetPolicy = HitTargetPolicy.hostile,
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
      if (!_isValidTarget(
            targetIndex,
            broadphase,
            owner,
            sourceFaction,
            targetPolicy,
          ) ||
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
    HitTargetPolicy targetPolicy = HitTargetPolicy.hostile,
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
      if (!_isValidTarget(
            targetIndex,
            broadphase,
            owner,
            sourceFaction,
            targetPolicy,
          ) ||
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

  /// Nearest contact along a capsule's translation; entity ID breaks ties.
  /// Returns the contact fraction as well as the cached target index so impact
  /// effects can be placed at contact rather than at the end of a fast step.
  ({int targetIndex, double fraction})? firstSweptCapsuleContact({
    required BroadphaseGrid broadphase,
    required double ax,
    required double ay,
    required double bx,
    required double by,
    required double radius,
    required double deltaX,
    required double deltaY,
    required EntityId owner,
    required Faction sourceFaction,
    HitTargetPolicy targetPolicy = HitTargetPolicy.hostile,
  }) {
    if (!_prepareCandidates(
      broadphase: broadphase,
      minX: math.min(ax, bx) + math.min(0, deltaX) - radius,
      minY: math.min(ay, by) + math.min(0, deltaY) - radius,
      maxX: math.max(ax, bx) + math.max(0, deltaX) + radius,
      maxY: math.max(ay, by) + math.max(0, deltaY) + radius,
    )) {
      return null;
    }
    int? firstIndex;
    var firstFraction = double.infinity;
    final targets = broadphase.targets;
    for (final index in _candidates) {
      if (!_isValidTarget(
        index,
        broadphase,
        owner,
        sourceFaction,
        targetPolicy,
      )) {
        continue;
      }
      final fraction = capsuleSweepFirstContact(
        ax: ax,
        ay: ay,
        bx: bx,
        by: by,
        radius: radius,
        deltaX: deltaX,
        deltaY: deltaY,
        targetAx: targets.capsuleAx[index],
        targetAy: targets.capsuleAy[index],
        targetBx: targets.capsuleBx[index],
        targetBy: targets.capsuleBy[index],
        targetRadius: targets.capsuleRadius[index],
      );
      if (fraction != null && fraction < firstFraction) {
        firstIndex = index;
        firstFraction = fraction;
      }
    }
    return firstIndex == null
        ? null
        : (targetIndex: firstIndex, fraction: firstFraction);
  }

  /// All contacts in a changing capsule pose's conservative swept envelope.
  /// A zero-radius pair of horizontal spines also represents a trigger rect.
  void collectOrderedPoseSweepOverlaps({
    required BroadphaseGrid broadphase,
    required double ax,
    required double ay,
    required double bx,
    required double by,
    required double previousAx,
    required double previousAy,
    required double previousBx,
    required double previousBy,
    required double radius,
    required EntityId owner,
    required Faction sourceFaction,
    required List<int> outTargetIndices,
    HitTargetPolicy targetPolicy = HitTargetPolicy.hostile,
  }) {
    outTargetIndices.clear();
    if (!_prepareCandidates(
      broadphase: broadphase,
      minX:
          math.min(math.min(ax, bx), math.min(previousAx, previousBx)) - radius,
      minY:
          math.min(math.min(ay, by), math.min(previousAy, previousBy)) - radius,
      maxX:
          math.max(math.max(ax, bx), math.max(previousAx, previousBx)) + radius,
      maxY:
          math.max(math.max(ay, by), math.max(previousAy, previousBy)) + radius,
    )) {
      return;
    }
    final targets = broadphase.targets;
    for (final i in _candidates) {
      if (!_isValidTarget(i, broadphase, owner, sourceFaction, targetPolicy)) {
        continue;
      }
      if (capsulePoseSweepOverlaps(
        ax: ax,
        ay: ay,
        bx: bx,
        by: by,
        previousAx: previousAx,
        previousAy: previousAy,
        previousBx: previousBx,
        previousBy: previousBy,
        radius: radius,
        targetAx: targets.capsuleAx[i],
        targetAy: targets.capsuleAy[i],
        targetBx: targets.capsuleBx[i],
        targetBy: targets.capsuleBy[i],
        targetRadius: targets.capsuleRadius[i],
      )) {
        outTargetIndices.add(i);
      }
    }
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
    HitTargetPolicy targetPolicy,
  ) {
    final target = broadphase.targets.entities[targetIndex];
    return targetPolicy == HitTargetPolicy.allActors ||
        (target != owner &&
            !areAllies(
              sourceFaction,
              broadphase.targets.factions[targetIndex],
            ));
  }
}
