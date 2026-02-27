import '../abilities/ability_def.dart';
import '../projectiles/projectile_id.dart';

/// Persistent learned spell ownership for one character.
///
/// This is independent from equipped gear. It represents what the character
/// has learned and is allowed to equip in loadout pickers.
class SpellList {
  const SpellList({
    required this.learnedProjectileSpellIds,
    required this.learnedSpellAbilityIds,
  });

  /// Empty spell list (used as a safe placeholder before normalization).
  static const SpellList empty = SpellList(
    learnedProjectileSpellIds: <ProjectileId>{},
    learnedSpellAbilityIds: <AbilityKey>{},
  );

  /// Learned projectile spell ids (spell-typed projectile items).
  final Set<ProjectileId> learnedProjectileSpellIds;

  /// Learned non-projectile spell ability ids (spell-slot abilities).
  final Set<AbilityKey> learnedSpellAbilityIds;

  /// Returns a copy with selected fields replaced.
  SpellList copyWith({
    Set<ProjectileId>? learnedProjectileSpellIds,
    Set<AbilityKey>? learnedSpellAbilityIds,
  }) {
    return SpellList(
      learnedProjectileSpellIds:
          learnedProjectileSpellIds ?? this.learnedProjectileSpellIds,
      learnedSpellAbilityIds:
          learnedSpellAbilityIds ?? this.learnedSpellAbilityIds,
    );
  }

  /// Serializes the spell list using stable enum/string IDs.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'projectileSpells': learnedProjectileSpellIds
          .map((id) => id.name)
          .toList(growable: false),
      'spellAbilities': learnedSpellAbilityIds.toList(growable: false),
    };
  }

  /// Deserializes spell list data with fallback safety.
  static SpellList fromJson(
    Map<String, dynamic> json, {
    required SpellList fallback,
  }) {
    return SpellList(
      learnedProjectileSpellIds: _readProjectileIdSet(
        json['projectileSpells'],
        fallback.learnedProjectileSpellIds,
      ),
      learnedSpellAbilityIds: _readAbilityKeySet(
        json['spellAbilities'],
        fallback.learnedSpellAbilityIds,
      ),
    );
  }
}

Set<ProjectileId> _readProjectileIdSet(
  Object? raw,
  Set<ProjectileId> fallback,
) {
  if (raw is! List) return fallback;
  final result = <ProjectileId>{};
  for (final item in raw) {
    if (item is! String) continue;
    for (final value in ProjectileId.values) {
      if (value.name == item) {
        result.add(value);
        break;
      }
    }
  }
  return result.isEmpty ? fallback : result;
}

Set<AbilityKey> _readAbilityKeySet(
  Object? raw,
  Set<AbilityKey> fallback,
) {
  if (raw is! List) return fallback;
  final result = <AbilityKey>{};
  for (final item in raw) {
    if (item is String && item.isNotEmpty) {
      result.add(item);
    }
  }
  return result.isEmpty ? fallback : result;
}
