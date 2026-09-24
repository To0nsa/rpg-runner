import '../../encounters/encounter_instance.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Evidence captured before component destruction and entity-ID recycling.
typedef EncounterMemberRemoval = ({
  EncounterKey encounter,
  String memberId,
  bool defeated,
  bool fatalWorldLoss,
});

class EncounterMemberStore extends SparseSet {
  final List<EncounterKey> encounter = [];
  final List<String> memberId = [];
  final List<EncounterMemberRole> role = [];
  final List<EncounterMemberRemoval> removals = [];

  void add(
    EntityId entity, {
    required EncounterKey key,
    required String localId,
    required EncounterMemberRole memberRole,
  }) {
    if (has(entity)) {
      throw StateError('Entity $entity already owns an encounter.');
    }
    final i = addEntity(entity);
    encounter[i] = key;
    memberId[i] = localId;
    role[i] = memberRole;
  }

  void recordRemoval(
    EntityId entity, {
    required bool defeated,
    required bool fatalWorldLoss,
  }) {
    final i = tryIndexOf(entity);
    if (i == null) return;
    removals.add((
      encounter: encounter[i],
      memberId: memberId[i],
      defeated: defeated,
      fatalWorldLoss: fatalWorldLoss,
    ));
  }

  @override
  void onDenseAdded(int denseIndex) {
    encounter.add((chunkIndex: 0, encounterId: ''));
    memberId.add('');
    role.add(EncounterMemberRole.npc);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    encounter[removeIndex] = encounter[lastIndex];
    memberId[removeIndex] = memberId[lastIndex];
    role[removeIndex] = role[lastIndex];
    encounter.removeLast();
    memberId.removeLast();
    role.removeLast();
  }
}
