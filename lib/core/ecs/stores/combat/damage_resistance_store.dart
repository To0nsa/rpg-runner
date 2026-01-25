import '../../../combat/damage_type.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class DamageResistanceDef {
  const DamageResistanceDef({
    this.physicalBp = 0,
    this.fireBp = 0,
    this.iceBp = 0,
    this.thunderBp = 0,
    this.bleedBp = 0,
  });

  /// Basis points (100 = 1%).
  final int physicalBp;
  final int fireBp;
  final int iceBp;
  final int thunderBp;
  final int bleedBp;

  int modBpFor(DamageType type) {
    switch (type) {
      case DamageType.physical:
        return physicalBp;
      case DamageType.fire:
        return fireBp;
      case DamageType.ice:
        return iceBp;
      case DamageType.thunder:
        return thunderBp;
      case DamageType.bleed:
        return bleedBp;
    }
  }
}

/// Per-entity resistance/vulnerability modifiers by [DamageType].
class DamageResistanceStore extends SparseSet {
  /// Basis points (100 = 1%).
  final List<int> physicalBp = <int>[];
  final List<int> fireBp = <int>[];
  final List<int> iceBp = <int>[];
  final List<int> thunderBp = <int>[];
  final List<int> bleedBp = <int>[];

  void add(EntityId entity, [DamageResistanceDef def = const DamageResistanceDef()]) {
    final i = addEntity(entity);
    physicalBp[i] = def.physicalBp;
    fireBp[i] = def.fireBp;
    iceBp[i] = def.iceBp;
    thunderBp[i] = def.thunderBp;
    bleedBp[i] = def.bleedBp;
  }

  int modBpForEntity(EntityId entity, DamageType type) {
    final i = tryIndexOf(entity);
    if (i == null) return 0;
    return modBpForIndex(i, type);
  }

  int modBpForIndex(int index, DamageType type) {
    switch (type) {
      case DamageType.physical:
        return physicalBp[index];
      case DamageType.fire:
        return fireBp[index];
      case DamageType.ice:
        return iceBp[index];
      case DamageType.thunder:
        return thunderBp[index];
      case DamageType.bleed:
        return bleedBp[index];
    }
  }

  @override
  void onDenseAdded(int denseIndex) {
    physicalBp.add(0);
    fireBp.add(0);
    iceBp.add(0);
    thunderBp.add(0);
    bleedBp.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    physicalBp[removeIndex] = physicalBp[lastIndex];
    fireBp[removeIndex] = fireBp[lastIndex];
    iceBp[removeIndex] = iceBp[lastIndex];
    thunderBp[removeIndex] = thunderBp[lastIndex];
    bleedBp[removeIndex] = bleedBp[lastIndex];

    physicalBp.removeLast();
    fireBp.removeLast();
    iceBp.removeLast();
    thunderBp.removeLast();
    bleedBp.removeLast();
  }
}
