import '../abilities/ability_def.dart';
import '../projectiles/projectile_id.dart';

/// Persistent learned ability ownership for one character.
///
/// This is independent from equipped gear. It represents what the character
/// has learned and is allowed to equip in loadout pickers.
class AbilityOwnershipState {
  const AbilityOwnershipState({
    required this.learnedProjectileSpellIds,
    required this.learnedAbilityIdsBySlot,
  });

  /// Empty ownership state (used as a safe placeholder before normalization).
  static const AbilityOwnershipState empty = AbilityOwnershipState(
    learnedProjectileSpellIds: <ProjectileId>{},
    learnedAbilityIdsBySlot: <AbilitySlot, Set<AbilityKey>>{},
  );

  /// Learned projectile spell ids (spell-typed projectile items).
  final Set<ProjectileId> learnedProjectileSpellIds;

  /// Learned ability ids keyed by slot.
  final Map<AbilitySlot, Set<AbilityKey>> learnedAbilityIdsBySlot;

  /// Returns learned ability ids for [slot], or an empty set.
  Set<AbilityKey> learnedAbilityIdsForSlot(AbilitySlot slot) {
    return learnedAbilityIdsBySlot[slot] ?? const <AbilityKey>{};
  }

  /// Returns a copy with selected fields replaced.
  AbilityOwnershipState copyWith({
    Set<ProjectileId>? learnedProjectileSpellIds,
    Map<AbilitySlot, Set<AbilityKey>>? learnedAbilityIdsBySlot,
  }) {
    return AbilityOwnershipState(
      learnedProjectileSpellIds:
          learnedProjectileSpellIds ?? this.learnedProjectileSpellIds,
      learnedAbilityIdsBySlot:
          learnedAbilityIdsBySlot ?? this.learnedAbilityIdsBySlot,
    );
  }

  /// Serializes ownership state using stable enum/string IDs.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'projectileSpells': learnedProjectileSpellIds
          .map((id) => id.name)
          .toList(growable: false),
      'abilitiesBySlot': <String, Object?>{
        for (final slot in AbilitySlot.values)
          slot.name: learnedAbilityIdsForSlot(slot).toList(growable: false),
      },
    };
  }

  /// Deserializes ownership state data with fallback safety.
  static AbilityOwnershipState fromJson(
    Map<String, dynamic> json, {
    required AbilityOwnershipState fallback,
  }) {
    final learnedAbilityIdsBySlot = <AbilitySlot, Set<AbilityKey>>{};
    final abilitiesBySlotRaw = json['abilitiesBySlot'];
    for (final slot in AbilitySlot.values) {
      final fallbackIds = fallback.learnedAbilityIdsForSlot(slot);
      Object? rawForSlot;
      if (abilitiesBySlotRaw is Map<String, dynamic>) {
        rawForSlot = abilitiesBySlotRaw[slot.name];
      } else if (abilitiesBySlotRaw is Map) {
        rawForSlot = abilitiesBySlotRaw[slot.name];
      }
      learnedAbilityIdsBySlot[slot] = _readAbilityKeySet(
        rawForSlot,
        fallbackIds,
      );
    }

    return AbilityOwnershipState(
      learnedProjectileSpellIds: _readProjectileIdSet(
        json['projectileSpells'],
        fallback.learnedProjectileSpellIds,
      ),
      learnedAbilityIdsBySlot: learnedAbilityIdsBySlot,
    );
  }
}

Set<ProjectileId> _readProjectileIdSet(
  Object? raw,
  Set<ProjectileId> fallback,
) {
  if (raw is! List) return Set<ProjectileId>.from(fallback);
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
  return result.isEmpty ? Set<ProjectileId>.from(fallback) : result;
}

Set<AbilityKey> _readAbilityKeySet(Object? raw, Set<AbilityKey> fallback) {
  if (raw is! List) return Set<AbilityKey>.from(fallback);
  final result = <AbilityKey>{};
  for (final item in raw) {
    if (item is String && item.isNotEmpty) {
      result.add(item);
    }
  }
  return result.isEmpty ? Set<AbilityKey>.from(fallback) : result;
}
