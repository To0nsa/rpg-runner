import '../../../spells/spell_id.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class EquippedSpellDef {
  const EquippedSpellDef({this.spellId = SpellId.iceBolt});

  final SpellId spellId;
}

/// Per-entity equipped spell (single active spell).
class EquippedSpellStore extends SparseSet {
  final List<SpellId> spellId = <SpellId>[];

  void add(EntityId entity, [EquippedSpellDef def = const EquippedSpellDef()]) {
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
