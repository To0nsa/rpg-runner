import '../../combat/ai_target_policy.dart';
import '../../collision/terrain/terrain_edge_id.dart';
import '../../collision/terrain/terrain_traversal_profile.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

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
  final List<List<EntityId>> opponents = [];
  final List<bool> includePlayer = [];
  final List<double> perceptionSquared = [];
  final List<EntityId?> selected = [];
  final List<Map<EntityId, AiTargetNavigationEvidence>> unreachable = [];

  void configure(
    EntityId actor, {
    required AiTargetPolicy targetPolicy,
    required Iterable<EntityId> candidates,
    bool playerFallback = true,
    double perceptionRange = 800,
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
    policy[index] = targetPolicy;
    opponents[index] = roster;
    includePlayer[index] = playerFallback;
    perceptionSquared[index] = perceptionRange * perceptionRange;
    selected[index] = null;
    unreachable[index].clear();
  }

  /// Invalidates inbound references in addition to removing the actor's store.
  void forget(EntityId entity) {
    for (var i = 0; i < denseEntities.length; i++) {
      if (selected[i] == entity) selected[i] = null;
      unreachable[i].remove(entity);
      if (opponents[i].contains(entity)) {
        opponents[i] = List.unmodifiable(
          opponents[i].where((id) => id != entity),
        );
      }
    }
  }

  @override
  void onDenseAdded(int denseIndex) {
    policy.add(AiTargetPolicy.playerOnly);
    opponents.add(const []);
    includePlayer.add(true);
    perceptionSquared.add(0);
    selected.add(null);
    unreachable.add({});
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    policy[removeIndex] = policy[lastIndex];
    opponents[removeIndex] = opponents[lastIndex];
    includePlayer[removeIndex] = includePlayer[lastIndex];
    perceptionSquared[removeIndex] = perceptionSquared[lastIndex];
    selected[removeIndex] = selected[lastIndex];
    unreachable[removeIndex] = unreachable[lastIndex];
    policy.removeLast();
    opponents.removeLast();
    includePlayer.removeLast();
    perceptionSquared.removeLast();
    selected.removeLast();
    unreachable.removeLast();
  }
}
