/// High-level damage categories for resistance/vulnerability rules.
enum DamageType implements DamageComposition {
  physical,
  fire,
  ice,
  water,
  thunder,
  acid,
  dark,
  bleed,
  earth,
  holy,

  /// Separate DoT/feedback identity, using the existing Acid resistance stat.
  poison;

  @override
  DamageType get primaryType => this;

  @override
  int get totalWeight => 1;

  @override
  int weightOf(DamageType type) => type == this ? 1 : 0;
}

/// Immutable proportions of a hit's total damage, independent of its magnitude.
/// A [DamageType] is a single-type composition; [DamageTypeMix] splits a hit.
sealed class DamageComposition {
  const DamageComposition();

  /// Largest authored share, with ties broken in [DamageType.values] order.
  /// Used once per hit for feedback and type-scaled status applications.
  DamageType get primaryType;
  int get totalWeight;
  int weightOf(DamageType type);
}

/// Relative integer shares of one hit, e.g. physical: 1, dark: 1 means 50/50.
/// The attack's damage amount remains the total, not damage per share.
final class DamageTypeMix implements DamageComposition {
  const DamageTypeMix({
    this.physical = 0,
    this.fire = 0,
    this.ice = 0,
    this.water = 0,
    this.thunder = 0,
    this.acid = 0,
    this.dark = 0,
    this.bleed = 0,
    this.earth = 0,
    this.holy = 0,
    this.poison = 0,
  }) : assert(
         physical >= 0 &&
             fire >= 0 &&
             ice >= 0 &&
             water >= 0 &&
             thunder >= 0 &&
             acid >= 0 &&
             dark >= 0 &&
             bleed >= 0 &&
             earth >= 0 &&
             holy >= 0 &&
             poison >= 0,
       ),
       assert(
         physical +
                 fire +
                 ice +
                 water +
                 thunder +
                 acid +
                 dark +
                 bleed +
                 earth +
                 holy +
                 poison >
             0,
       );

  final int physical;
  final int fire;
  final int ice;
  final int water;
  final int thunder;
  final int acid;
  final int dark;
  final int bleed;
  final int earth;
  final int holy;
  final int poison;

  @override
  int get totalWeight =>
      physical +
      fire +
      ice +
      water +
      thunder +
      acid +
      dark +
      bleed +
      earth +
      holy +
      poison;

  @override
  int weightOf(DamageType type) => switch (type) {
    DamageType.physical => physical,
    DamageType.fire => fire,
    DamageType.ice => ice,
    DamageType.water => water,
    DamageType.thunder => thunder,
    DamageType.acid => acid,
    DamageType.dark => dark,
    DamageType.bleed => bleed,
    DamageType.earth => earth,
    DamageType.holy => holy,
    DamageType.poison => poison,
  };

  @override
  DamageType get primaryType {
    var primary = DamageType.physical;
    var largestWeight = 0;
    for (final type in DamageType.values) {
      final weight = weightOf(type);
      if (weight > largestWeight) {
        primary = type;
        largestWeight = weight;
      }
    }
    return primary;
  }
}

extension DamageCompositionOperations on DamageComposition {
  /// Converts only the physical share to the item's type, merging equal types.
  DamageComposition withPhysicalType(DamageType type) {
    final physicalWeight = weightOf(DamageType.physical);
    if (physicalWeight == 0 || type == DamageType.physical) return this;
    if (this is DamageType) return type;
    return DamageTypeMix(
      physical: 0,
      fire:
          weightOf(DamageType.fire) +
          (type == DamageType.fire ? physicalWeight : 0),
      ice:
          weightOf(DamageType.ice) +
          (type == DamageType.ice ? physicalWeight : 0),
      water:
          weightOf(DamageType.water) +
          (type == DamageType.water ? physicalWeight : 0),
      thunder:
          weightOf(DamageType.thunder) +
          (type == DamageType.thunder ? physicalWeight : 0),
      acid:
          weightOf(DamageType.acid) +
          (type == DamageType.acid ? physicalWeight : 0),
      dark:
          weightOf(DamageType.dark) +
          (type == DamageType.dark ? physicalWeight : 0),
      bleed:
          weightOf(DamageType.bleed) +
          (type == DamageType.bleed ? physicalWeight : 0),
      earth:
          weightOf(DamageType.earth) +
          (type == DamageType.earth ? physicalWeight : 0),
      holy:
          weightOf(DamageType.holy) +
          (type == DamageType.holy ? physicalWeight : 0),
      poison:
          weightOf(DamageType.poison) +
          (type == DamageType.poison ? physicalWeight : 0),
    );
  }

  /// Splits in enum order using cumulative integer division, preserving total.
  /// The final participating type receives any remaining fixed-point units.
  Iterable<({DamageType type, int amount100})> split(int amount100) sync* {
    if (amount100 <= 0) return;
    if (this case final DamageType type) {
      yield (type: type, amount100: amount100);
      return;
    }
    final total = totalWeight;
    var cumulativeWeight = 0;
    var allocated = 0;
    for (final type in DamageType.values) {
      final weight = weightOf(type);
      if (weight == 0) continue;
      cumulativeWeight += weight;
      final throughType = amount100 * cumulativeWeight ~/ total;
      final part = throughType - allocated;
      allocated = throughType;
      if (part > 0) yield (type: type, amount100: part);
    }
  }
}
