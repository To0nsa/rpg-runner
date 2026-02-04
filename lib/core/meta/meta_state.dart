import '../players/player_character_definition.dart';
import 'equipped_gear.dart';
import 'inventory_state.dart';
import 'meta_defaults.dart';

class MetaState {
  const MetaState({
    required this.schemaVersion,
    required this.inventory,
    required this.equippedByCharacter,
  });

  static const int latestSchemaVersion = 1;

  final int schemaVersion;
  final InventoryState inventory;
  final Map<PlayerCharacterId, EquippedGear> equippedByCharacter;

  MetaState copyWith({
    int? schemaVersion,
    InventoryState? inventory,
    Map<PlayerCharacterId, EquippedGear>? equippedByCharacter,
  }) {
    return MetaState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      inventory: inventory ?? this.inventory,
      equippedByCharacter: equippedByCharacter ?? this.equippedByCharacter,
    );
  }

  EquippedGear equippedFor(PlayerCharacterId id) {
    return equippedByCharacter[id] ?? MetaDefaults.equippedGear;
  }

  MetaState setEquippedFor(PlayerCharacterId id, EquippedGear gear) {
    final next = Map<PlayerCharacterId, EquippedGear>.from(equippedByCharacter);
    next[id] = gear;
    return copyWith(equippedByCharacter: next);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'inventory': inventory.toJson(),
      'equippedByCharacter': <String, Object?>{
        for (final entry in equippedByCharacter.entries)
          entry.key.name: entry.value.toJson(),
      },
    };
  }

  static MetaState seedAllUnlocked({required InventoryState inventory}) {
    final equipped = <PlayerCharacterId, EquippedGear>{
      for (final id in PlayerCharacterId.values) id: MetaDefaults.equippedGear,
    };
    return MetaState(
      schemaVersion: latestSchemaVersion,
      inventory: inventory,
      equippedByCharacter: equipped,
    );
  }

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

    return MetaState(
      schemaVersion: schemaVersion,
      inventory: inventory,
      equippedByCharacter: equippedByCharacter,
    );
  }
}
