import '../../../combat/damage_type.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class DamageResistanceDef {
  const DamageResistanceDef({
    this.physical = 0.0,
    this.fire = 0.0,
    this.ice = 0.0,
    this.thunder = 0.0,
    this.bleed = 0.0,
  });

  final double physical;
  final double fire;
  final double ice;
  final double thunder;
  final double bleed;

  double modFor(DamageType type) {
    switch (type) {
      case DamageType.physical:
        return physical;
      case DamageType.fire:
        return fire;
      case DamageType.ice:
        return ice;
      case DamageType.thunder:
        return thunder;
      case DamageType.bleed:
        return bleed;
    }
  }
}

/// Per-entity resistance/vulnerability modifiers by [DamageType].
class DamageResistanceStore extends SparseSet {
  final List<double> physical = <double>[];
  final List<double> fire = <double>[];
  final List<double> ice = <double>[];
  final List<double> thunder = <double>[];
  final List<double> bleed = <double>[];

  void add(EntityId entity, [DamageResistanceDef def = const DamageResistanceDef()]) {
    final i = addEntity(entity);
    physical[i] = def.physical;
    fire[i] = def.fire;
    ice[i] = def.ice;
    thunder[i] = def.thunder;
    bleed[i] = def.bleed;
  }

  double modForEntity(EntityId entity, DamageType type) {
    final i = tryIndexOf(entity);
    if (i == null) return 0.0;
    return modForIndex(i, type);
  }

  double modForIndex(int index, DamageType type) {
    switch (type) {
      case DamageType.physical:
        return physical[index];
      case DamageType.fire:
        return fire[index];
      case DamageType.ice:
        return ice[index];
      case DamageType.thunder:
        return thunder[index];
      case DamageType.bleed:
        return bleed[index];
    }
  }

  @override
  void onDenseAdded(int denseIndex) {
    physical.add(0.0);
    fire.add(0.0);
    ice.add(0.0);
    thunder.add(0.0);
    bleed.add(0.0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    physical[removeIndex] = physical[lastIndex];
    fire[removeIndex] = fire[lastIndex];
    ice[removeIndex] = ice[lastIndex];
    thunder[removeIndex] = thunder[lastIndex];
    bleed[removeIndex] = bleed[lastIndex];

    physical.removeLast();
    fire.removeLast();
    ice.removeLast();
    thunder.removeLast();
    bleed.removeLast();
  }
}

