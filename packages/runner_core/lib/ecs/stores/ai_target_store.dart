import '../../combat/ai_target_policy.dart';
import '../../collision/terrain/terrain_edge_id.dart';
import '../../collision/terrain/terrain_traversal_profile.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Target rosters belong either to an active encounter or to local survivor combat.
enum AiTargetOwner { encounter, sectionGuard }

typedef AiTargetSupportEvidence = (
  TerrainEdgeId?,
  int,
  TerrainTraversalProfile?,
);
typedef AiTargetNavigationEvidence = (
  AiTargetSupportEvidence,
  AiTargetSupportEvidence,
  double,
  double,
);

/// Explicit AI membership and selection; absence means ordinary player pursuit.
///
/// Candidate IDs belong to one owner-provided roster. Destruction removes every
/// reference before the world can recycle an ID. An explicit null selection
/// means no target and must not fall through to ordinary player pursuit.
final class AiTargetStore extends SparseSet {
  final List<AiTargetPolicy> policy = [];
  final List<AiTargetOwner> owner = [];

  /// Frozen rosters; replace through [configure] or [refreshCandidates] so
  /// inbound reference counts remain consistent with entity-ID cleanup.
  final List<List<EntityId>> opponents = [];
  final List<bool> includePlayer = [];
  final List<double> perceptionSquared = [];
  final List<EntityId?> selected = [];
  final List<Map<EntityId, AiTargetNavigationEvidence>> unreachable = [];

  // Counts roster references, including candidates with no AI store of their own.
  final Map<EntityId, int> _rosterReferences = {};

  void configure(
    EntityId actor, {
    required AiTargetPolicy targetPolicy,
    required Iterable<EntityId> candidates,
    bool playerFallback = true,
    double perceptionRange = 800,
    AiTargetOwner rosterOwner = AiTargetOwner.encounter,
  }) {
    if (!perceptionRange.isFinite ||
        perceptionRange <= 0 ||
        !(perceptionRange * perceptionRange).isFinite) {
      throw ArgumentError.value(perceptionRange, 'perceptionRange');
    }
    final roster = List<EntityId>.unmodifiable(candidates);
    if (roster.toSet().length != roster.length || roster.contains(actor)) {
      throw ArgumentError('AI candidates must be distinct other actors.');
    }
    final index = addEntity(actor);
    _removeRosterReferences(opponents[index]);
    policy[index] = targetPolicy;
    owner[index] = rosterOwner;
    opponents[index] = roster;
    _addRosterReferences(roster);
    includePlayer[index] = playerFallback;
    perceptionSquared[index] = perceptionRange * perceptionRange;
    selected[index] = null;
    unreachable[index].clear();
  }

  /// Refreshes membership without resetting retained selection or blocked evidence.
  /// Callers supply stable, distinct IDs; removed candidates lose cached evidence.
  void refreshCandidates(EntityId actor, List<EntityId> candidates) {
    final i = indexOf(actor);
    final previous = opponents[i];
    if (previous.length == candidates.length) {
      var same = true;
      for (var c = 0; c < candidates.length; c++) {
        if (previous[c] != candidates[c]) {
          same = false;
          break;
        }
      }
      if (same) return;
    }
    if (candidates.toSet().length != candidates.length ||
        candidates.contains(actor)) {
      throw ArgumentError('AI candidates must be distinct other actors.');
    }
    _removeRosterReferences(previous);
    opponents[i] = List.unmodifiable(candidates);
    _addRosterReferences(candidates);
    unreachable[i].removeWhere(
      (candidate, _) => !candidates.contains(candidate),
    );
    // Selection eligibility, including player fallback, is resolved once by AI.
  }

  /// Clears inbound references before world teardown can recycle [entity].
  void forget(EntityId entity) {
    final inRoster = _rosterReferences.containsKey(entity);
    for (var i = 0; i < denseEntities.length; i++) {
      if (selected[i] == entity) selected[i] = null;
      unreachable[i].remove(entity);
      if (inRoster && opponents[i].contains(entity)) {
        opponents[i] = List.unmodifiable(
          opponents[i].where((id) => id != entity),
        );
      }
    }
    _rosterReferences.remove(entity);
  }

  void _addRosterReferences(List<EntityId> roster) {
    for (final candidate in roster) {
      _rosterReferences[candidate] = (_rosterReferences[candidate] ?? 0) + 1;
    }
  }

  void _removeRosterReferences(List<EntityId> roster) {
    for (final candidate in roster) {
      final remaining = _rosterReferences[candidate]! - 1;
      if (remaining == 0) {
        _rosterReferences.remove(candidate);
      } else {
        _rosterReferences[candidate] = remaining;
      }
    }
  }

  @override
  void onDenseAdded(int denseIndex) {
    policy.add(AiTargetPolicy.playerOnly);
    owner.add(AiTargetOwner.encounter);
    opponents.add(const []);
    includePlayer.add(true);
    perceptionSquared.add(0);
    selected.add(null);
    unreachable.add({});
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    _removeRosterReferences(opponents[removeIndex]);
    policy[removeIndex] = policy[lastIndex];
    owner[removeIndex] = owner[lastIndex];
    opponents[removeIndex] = opponents[lastIndex];
    includePlayer[removeIndex] = includePlayer[lastIndex];
    perceptionSquared[removeIndex] = perceptionSquared[lastIndex];
    selected[removeIndex] = selected[lastIndex];
    unreachable[removeIndex] = unreachable[lastIndex];
    policy.removeLast();
    owner.removeLast();
    opponents.removeLast();
    includePlayer.removeLast();
    perceptionSquared.removeLast();
    selected.removeLast();
    unreachable.removeLast();
  }
}
