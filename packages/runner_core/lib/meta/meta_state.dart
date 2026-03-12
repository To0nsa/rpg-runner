import '../players/player_character_definition.dart';
import 'ability_ownership_state.dart';
import 'equipped_gear.dart';
import 'inventory_state.dart';
import 'meta_defaults.dart';

/// Persisted meta-progression state for gear inventory and loadouts.
class MetaState {
  const MetaState({
    required this.schemaVersion,
    required this.inventory,
    required this.equippedByCharacter,
    required this.abilityOwnershipByCharacter,
  });

  /// Latest supported serialization schema.
  static const int latestSchemaVersion = 3;

  /// Serialized schema version of this instance.
  final int schemaVersion;

  /// Unlocked inventory sets across all gear domains.
  final InventoryState inventory;

  /// Equipped gear per playable character.
  final Map<PlayerCharacterId, EquippedGear> equippedByCharacter;

  /// Learned ability ownership per playable character.
  final Map<PlayerCharacterId, AbilityOwnershipState>
  abilityOwnershipByCharacter;

  /// Returns a copy with optional field replacements.
  MetaState copyWith({
    int? schemaVersion,
    InventoryState? inventory,
    Map<PlayerCharacterId, EquippedGear>? equippedByCharacter,
    Map<PlayerCharacterId, AbilityOwnershipState>? abilityOwnershipByCharacter,
  }) {
    return MetaState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      inventory: inventory ?? this.inventory,
      equippedByCharacter: equippedByCharacter ?? this.equippedByCharacter,
      abilityOwnershipByCharacter:
          abilityOwnershipByCharacter ?? this.abilityOwnershipByCharacter,
    );
  }

  /// Reads equipped gear for [id], falling back to defaults when absent.
  EquippedGear equippedFor(PlayerCharacterId id) {
    return equippedByCharacter[id] ?? MetaDefaults.equippedGear;
  }

  /// Returns a copy with [gear] assigned to character [id].
  MetaState setEquippedFor(PlayerCharacterId id, EquippedGear gear) {
    final next = Map<PlayerCharacterId, EquippedGear>.from(equippedByCharacter);
    next[id] = gear;
    return copyWith(equippedByCharacter: next);
  }

  /// Reads learned ability ownership for [id], falling back to empty.
  AbilityOwnershipState abilityOwnershipFor(PlayerCharacterId id) {
    return abilityOwnershipByCharacter[id] ?? AbilityOwnershipState.empty;
  }

  /// Returns a copy with [abilityOwnership] assigned to character [id].
  MetaState setAbilityOwnershipFor(
    PlayerCharacterId id,
    AbilityOwnershipState abilityOwnership,
  ) {
    final next = Map<PlayerCharacterId, AbilityOwnershipState>.from(
      abilityOwnershipByCharacter,
    );
    next[id] = abilityOwnership;
    return copyWith(abilityOwnershipByCharacter: next);
  }

  /// Serializes meta state as JSON-friendly maps/lists.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'inventory': inventory.toJson(),
      'equippedByCharacter': <String, Object?>{
        for (final entry in equippedByCharacter.entries)
          entry.key.name: entry.value.toJson(),
      },
      'abilityOwnershipByCharacter': <String, Object?>{
        for (final entry in abilityOwnershipByCharacter.entries)
          entry.key.name: entry.value.toJson(),
      },
    };
  }

  /// Seeds a new state where all characters start with default equipped gear.
  static MetaState seedAllUnlocked({
    required InventoryState inventory,
    Map<PlayerCharacterId, AbilityOwnershipState>? abilityOwnershipByCharacter,
  }) {
    final equipped = <PlayerCharacterId, EquippedGear>{
      for (final id in PlayerCharacterId.values) id: MetaDefaults.equippedGear,
    };
    final ownershipByCharacter = <PlayerCharacterId, AbilityOwnershipState>{
      for (final id in PlayerCharacterId.values)
        id: abilityOwnershipByCharacter?[id] ?? AbilityOwnershipState.empty,
    };
    return MetaState(
      schemaVersion: latestSchemaVersion,
      inventory: inventory,
      equippedByCharacter: equipped,
      abilityOwnershipByCharacter: ownershipByCharacter,
    );
  }

  /// Deserializes from JSON with robust fallback behavior.
  ///
  /// Invalid/missing branches fall back to [fallback], then downstream
  /// normalization in [MetaService] enforces canonical invariants.
  static MetaState fromJson(
    Map<String, dynamic> json, {
    required MetaState fallback,
  }) {
    final schemaVersionRaw = json['schemaVersion'];
    final schemaVersion = schemaVersionRaw is int
        ? schemaVersionRaw
        : (schemaVersionRaw is num
              ? schemaVersionRaw.toInt()
              : fallback.schemaVersion);
    final inventoryRaw = json['inventory'];
    final inventory = inventoryRaw is Map<String, dynamic>
        ? InventoryState.fromJson(inventoryRaw, fallback: fallback.inventory)
        : (inventoryRaw is Map
              ? InventoryState.fromJson(
                  Map<String, dynamic>.from(inventoryRaw),
                  fallback: fallback.inventory,
                )
              : fallback.inventory);

    final equippedByCharacter = <PlayerCharacterId, EquippedGear>{};
    final equippedRaw = json['equippedByCharacter'];
    if (equippedRaw is Map) {
      for (final id in PlayerCharacterId.values) {
        final rawEntry = equippedRaw[id.name];
        if (rawEntry is Map<String, dynamic>) {
          equippedByCharacter[id] = EquippedGear.fromJson(
            rawEntry,
            fallback: MetaDefaults.equippedGear,
          );
        } else if (rawEntry is Map) {
          equippedByCharacter[id] = EquippedGear.fromJson(
            Map<String, dynamic>.from(rawEntry),
            fallback: MetaDefaults.equippedGear,
          );
        }
      }
    }

    // Ensure no character has an empty slot.
    for (final id in PlayerCharacterId.values) {
      equippedByCharacter.putIfAbsent(id, () => MetaDefaults.equippedGear);
    }

    final abilityOwnershipByCharacter =
        <PlayerCharacterId, AbilityOwnershipState>{};
    final abilityOwnershipRaw = json['abilityOwnershipByCharacter'];
    if (abilityOwnershipRaw is Map) {
      for (final id in PlayerCharacterId.values) {
        final rawEntry = abilityOwnershipRaw[id.name];
        final fallbackOwnership = fallback.abilityOwnershipFor(id);
        if (rawEntry is Map<String, dynamic>) {
          abilityOwnershipByCharacter[id] = AbilityOwnershipState.fromJson(
            rawEntry,
            fallback: fallbackOwnership,
          );
        } else if (rawEntry is Map) {
          abilityOwnershipByCharacter[id] = AbilityOwnershipState.fromJson(
            Map<String, dynamic>.from(rawEntry),
            fallback: fallbackOwnership,
          );
        }
      }
    }
    for (final id in PlayerCharacterId.values) {
      abilityOwnershipByCharacter.putIfAbsent(
        id,
        () => fallback.abilityOwnershipFor(id),
      );
    }

    return MetaState(
      schemaVersion: schemaVersion,
      inventory: inventory,
      equippedByCharacter: equippedByCharacter,
      abilityOwnershipByCharacter: abilityOwnershipByCharacter,
    );
  }
}
