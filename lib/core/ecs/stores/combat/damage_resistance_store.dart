import '../../../combat/damage_type.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class DamageResistanceDef {
  const DamageResistanceDef({
    this.physicalBp = 0,
    this.fireBp = 0,
    this.iceBp = 0,
    this.thunderBp = 0,
    this.acidBp = 0,
    this.darkBp = 0,
    this.bleedBp = 0,
    this.earthBp = 0,
  });

  /// Basis points (100 = 1%).
  final int physicalBp;
  final int fireBp;
  final int iceBp;
  final int thunderBp;
  final int acidBp;
  final int darkBp;
  final int bleedBp;
  final int earthBp;

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
      case DamageType.acid:
        return acidBp;
      case DamageType.dark:
        return darkBp;
      case DamageType.bleed:
        return bleedBp;
      case DamageType.earth:
        return earthBp;
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
  final List<int> acidBp = <int>[];
  final List<int> darkBp = <int>[];
  final List<int> bleedBp = <int>[];
  final List<int> earthBp = <int>[];

  void add(
    EntityId entity, [
    DamageResistanceDef def = const DamageResistanceDef(),
  ]) {
    final i = addEntity(entity);
    physicalBp[i] = def.physicalBp;
    fireBp[i] = def.fireBp;
    iceBp[i] = def.iceBp;
    thunderBp[i] = def.thunderBp;
    acidBp[i] = def.acidBp;
    darkBp[i] = def.darkBp;
    bleedBp[i] = def.bleedBp;
    earthBp[i] = def.earthBp;
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
      case DamageType.acid:
        return acidBp[index];
      case DamageType.dark:
        return darkBp[index];
      case DamageType.bleed:
        return bleedBp[index];
      case DamageType.earth:
        return earthBp[index];
    }
  }

  @override
  void onDenseAdded(int denseIndex) {
    physicalBp.add(0);
    fireBp.add(0);
    iceBp.add(0);
    thunderBp.add(0);
    acidBp.add(0);
    darkBp.add(0);
    bleedBp.add(0);
    earthBp.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    physicalBp[removeIndex] = physicalBp[lastIndex];
    fireBp[removeIndex] = fireBp[lastIndex];
    iceBp[removeIndex] = iceBp[lastIndex];
    thunderBp[removeIndex] = thunderBp[lastIndex];
    acidBp[removeIndex] = acidBp[lastIndex];
    darkBp[removeIndex] = darkBp[lastIndex];
    bleedBp[removeIndex] = bleedBp[lastIndex];
    earthBp[removeIndex] = earthBp[lastIndex];

    physicalBp.removeLast();
    fireBp.removeLast();
    iceBp.removeLast();
    thunderBp.removeLast();
    acidBp.removeLast();
    darkBp.removeLast();
    bleedBp.removeLast();
    earthBp.removeLast();
  }
}
