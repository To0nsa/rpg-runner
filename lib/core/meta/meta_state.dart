import '../players/player_character_definition.dart';
import 'equipped_gear.dart';
import 'inventory_state.dart';
import 'meta_defaults.dart';
import 'spell_list.dart';

/// Persisted meta-progression state for gear inventory and loadouts.
class MetaState {
  const MetaState({
    required this.schemaVersion,
    required this.inventory,
    required this.equippedByCharacter,
    required this.spellListByCharacter,
  });

  /// Latest supported serialization schema.
  static const int latestSchemaVersion = 2;

  /// Serialized schema version of this instance.
  final int schemaVersion;

  /// Unlocked inventory sets across all gear domains.
  final InventoryState inventory;

  /// Equipped gear per playable character.
  final Map<PlayerCharacterId, EquippedGear> equippedByCharacter;

  /// Learned spell ownership per playable character.
  final Map<PlayerCharacterId, SpellList> spellListByCharacter;

  /// Returns a copy with optional field replacements.
  MetaState copyWith({
    int? schemaVersion,
    InventoryState? inventory,
    Map<PlayerCharacterId, EquippedGear>? equippedByCharacter,
    Map<PlayerCharacterId, SpellList>? spellListByCharacter,
  }) {
    return MetaState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      inventory: inventory ?? this.inventory,
      equippedByCharacter: equippedByCharacter ?? this.equippedByCharacter,
      spellListByCharacter: spellListByCharacter ?? this.spellListByCharacter,
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

  /// Reads learned spell ownership for [id], falling back to empty.
  SpellList spellListFor(PlayerCharacterId id) {
    return spellListByCharacter[id] ?? SpellList.empty;
  }

  /// Returns a copy with [spellList] assigned to character [id].
  MetaState setSpellListFor(PlayerCharacterId id, SpellList spellList) {
    final next = Map<PlayerCharacterId, SpellList>.from(spellListByCharacter);
    next[id] = spellList;
    return copyWith(spellListByCharacter: next);
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
      'spellListByCharacter': <String, Object?>{
        for (final entry in spellListByCharacter.entries)
          entry.key.name: entry.value.toJson(),
      },
    };
  }

  /// Seeds a new state where all characters start with default equipped gear.
  static MetaState seedAllUnlocked({
    required InventoryState inventory,
    Map<PlayerCharacterId, SpellList>? spellListByCharacter,
  }) {
    final equipped = <PlayerCharacterId, EquippedGear>{
      for (final id in PlayerCharacterId.values) id: MetaDefaults.equippedGear,
    };
    final spellLists = <PlayerCharacterId, SpellList>{
      for (final id in PlayerCharacterId.values)
        id: spellListByCharacter?[id] ?? SpellList.empty,
    };
    return MetaState(
      schemaVersion: latestSchemaVersion,
      inventory: inventory,
      equippedByCharacter: equipped,
      spellListByCharacter: spellLists,
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

    final spellListByCharacter = <PlayerCharacterId, SpellList>{};
    final spellListRaw = json['spellListByCharacter'];
    if (spellListRaw is Map) {
      for (final id in PlayerCharacterId.values) {
        final rawEntry = spellListRaw[id.name];
        final fallbackList = fallback.spellListFor(id);
        if (rawEntry is Map<String, dynamic>) {
          spellListByCharacter[id] = SpellList.fromJson(
            rawEntry,
            fallback: fallbackList,
          );
        } else if (rawEntry is Map) {
          spellListByCharacter[id] = SpellList.fromJson(
            Map<String, dynamic>.from(rawEntry),
            fallback: fallbackList,
          );
        }
      }
    }
    for (final id in PlayerCharacterId.values) {
      spellListByCharacter.putIfAbsent(id, () => fallback.spellListFor(id));
    }

    return MetaState(
      schemaVersion: schemaVersion,
      inventory: inventory,
      equippedByCharacter: equippedByCharacter,
      spellListByCharacter: spellListByCharacter,
    );
  }
}
