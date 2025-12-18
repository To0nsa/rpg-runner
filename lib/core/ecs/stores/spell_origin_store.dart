import '../../spells/spell_id.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class SpellOriginDef {
  const SpellOriginDef({required this.spellId});

  final SpellId spellId;
}

class SpellOriginStore extends SparseSet {
  final List<SpellId> spellId = <SpellId>[];

  void add(EntityId entity, SpellOriginDef def) {
    final i = addEntity(entity);
    spellId[i] = def.spellId;
  }

  @override
  void onDenseAdded(int denseIndex) {
    spellId.add(SpellId.iceBolt);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    spellId[removeIndex] = spellId[lastIndex];
    spellId.removeLast();
  }
}

