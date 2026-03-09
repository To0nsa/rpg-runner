import '../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../core/levels/level_id.dart';
import '../../core/players/player_character_definition.dart';
import '../../core/players/player_character_registry.dart';
import '../../core/projectiles/projectile_id.dart';
import '../../core/spellBook/spell_book_id.dart';
import '../../core/accessories/accessory_id.dart';
import '../../core/weapons/weapon_id.dart';

/// Menu-facing run type for the selected level.
enum RunType { practice, competitive }

/// Persistent menu selection state.
class SelectionState {
  SelectionState({
    required this.selectedLevelId,
    required this.selectedRunType,
    required this.selectedCharacterId,
    required Map<PlayerCharacterId, EquippedLoadoutDef> loadoutsByCharacter,
    required this.buildName,
  }) : loadoutsByCharacter = Map.unmodifiable(
         _ensureLoadoutsForAllCharacters(loadoutsByCharacter),
       );

  static const String defaultBuildName = 'Build 1';
  static const int buildNameMaxLength = 24;
  static const int schemaVersion = 1;

  static final SelectionState defaults = SelectionState(
    selectedLevelId: LevelId.field,
    selectedRunType: RunType.practice,
    selectedCharacterId: PlayerCharacterId.eloise,
    loadoutsByCharacter: _seedLoadoutsWithDefaults(),
    buildName: defaultBuildName,
  );

  final LevelId selectedLevelId;
  final RunType selectedRunType;
  final PlayerCharacterId selectedCharacterId;
  final Map<PlayerCharacterId, EquippedLoadoutDef> loadoutsByCharacter;
  final String buildName;

  bool get isCompetitive => selectedRunType == RunType.competitive;

  EquippedLoadoutDef loadoutFor(PlayerCharacterId id) {
    return loadoutsByCharacter[id] ?? _defaultLoadoutForCharacter(id);
  }

  SelectionState copyWith({
    LevelId? selectedLevelId,
    RunType? selectedRunType,
    PlayerCharacterId? selectedCharacterId,
    Map<PlayerCharacterId, EquippedLoadoutDef>? loadoutsByCharacter,
    String? buildName,
  }) {
    return SelectionState(
      selectedLevelId: selectedLevelId ?? this.selectedLevelId,
      selectedRunType: selectedRunType ?? this.selectedRunType,
      selectedCharacterId: selectedCharacterId ?? this.selectedCharacterId,
      loadoutsByCharacter: loadoutsByCharacter ?? this.loadoutsByCharacter,
      buildName: buildName == null
          ? this.buildName
          : normalizeBuildName(buildName),
    );
  }

  SelectionState withLoadoutFor(
    PlayerCharacterId id,
    EquippedLoadoutDef loadout,
  ) {
    final next = Map<PlayerCharacterId, EquippedLoadoutDef>.from(
      loadoutsByCharacter,
    );
    next[id] = loadout;
    return copyWith(loadoutsByCharacter: next);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'levelId': selectedLevelId.name,
      'runType': selectedRunType.name,
      'characterId': selectedCharacterId.name,
      'loadoutsByCharacter': <String, Object?>{
        for (final id in PlayerCharacterId.values)
          id.name: _loadoutToJson(loadoutFor(id)),
      },
      'buildName': buildName,
    };
  }

  static SelectionState fromJson(Map<String, dynamic> json) {
    final storedSchemaVersion = json['schemaVersion'];
    if (storedSchemaVersion is! int || storedSchemaVersion != schemaVersion) {
      return SelectionState.defaults;
    }

    final loadoutsRaw = json['loadoutsByCharacter'];
    if (loadoutsRaw is! Map) {
      return SelectionState.defaults;
    }

    final levelId = _enumFromName(
      LevelId.values,
      json['levelId'] as String?,
      LevelId.field,
    );
    final runType = _enumFromName(
      RunType.values,
      json['runType'] as String?,
      RunType.practice,
    );
    final characterId = _enumFromName(
      PlayerCharacterId.values,
      json['characterId'] as String?,
      PlayerCharacterId.eloise,
    );
    final loadouts = _seedLoadoutsWithDefaults();
    for (final id in PlayerCharacterId.values) {
      final raw = loadoutsRaw[id.name];
      if (raw is Map<String, dynamic>) {
        loadouts[id] = _loadoutFromJson(raw, fallback: loadouts[id]!);
      } else if (raw is Map) {
        loadouts[id] = _loadoutFromJson(
          Map<String, dynamic>.from(raw),
          fallback: loadouts[id]!,
        );
      }
    }
    final buildName = normalizeBuildName(
      json['buildName'] is String ? json['buildName'] as String : null,
    );

    return SelectionState(
      selectedLevelId: levelId,
      selectedRunType: runType,
      selectedCharacterId: characterId,
      loadoutsByCharacter: loadouts,
      buildName: buildName,
    );
  }

  static String normalizeBuildName(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return defaultBuildName;
    if (trimmed.length <= buildNameMaxLength) return trimmed;
    return trimmed.substring(0, buildNameMaxLength);
  }
}

Map<PlayerCharacterId, EquippedLoadoutDef> _seedLoadoutsWithDefaults() {
  return <PlayerCharacterId, EquippedLoadoutDef>{
    for (final id in PlayerCharacterId.values)
      id: _defaultLoadoutForCharacter(id),
  };
}

Map<PlayerCharacterId, EquippedLoadoutDef> _ensureLoadoutsForAllCharacters(
  Map<PlayerCharacterId, EquippedLoadoutDef> source,
) {
  return <PlayerCharacterId, EquippedLoadoutDef>{
    for (final id in PlayerCharacterId.values)
      id: source[id] ?? _defaultLoadoutForCharacter(id),
  };
}

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

Map<String, Object?> _loadoutToJson(EquippedLoadoutDef loadout) {
  return <String, Object?>{
    'mask': loadout.mask,
    'mainWeaponId': loadout.mainWeaponId.name,
    'offhandWeaponId': loadout.offhandWeaponId.name,
    'spellBookId': loadout.spellBookId.name,
    'projectileSlotSpellId': loadout.projectileSlotSpellId.name,
    'accessoryId': loadout.accessoryId.name,
    'abilityPrimaryId': loadout.abilityPrimaryId,
    'abilitySecondaryId': loadout.abilitySecondaryId,
    'abilityProjectileId': loadout.abilityProjectileId,
    'abilitySpellId': loadout.abilitySpellId,
    'abilityMobilityId': loadout.abilityMobilityId,
    'abilityJumpId': loadout.abilityJumpId,
  };
}

EquippedLoadoutDef _loadoutFromJson(
  Object? raw, {
  required EquippedLoadoutDef fallback,
}) {
  if (raw is! Map) {
    return fallback;
  }
  final map = Map<String, dynamic>.from(raw);
  return EquippedLoadoutDef(
    mask: map['mask'] is int ? map['mask'] as int : fallback.mask,
    mainWeaponId: _enumFromName(
      WeaponId.values,
      map['mainWeaponId'] as String?,
      fallback.mainWeaponId,
    ),
    offhandWeaponId: _enumFromName(
      WeaponId.values,
      map['offhandWeaponId'] as String?,
      fallback.offhandWeaponId,
    ),
    spellBookId: _enumFromName(
      SpellBookId.values,
      map['spellBookId'] as String?,
      fallback.spellBookId,
    ),
    projectileSlotSpellId: _enumFromName(
      ProjectileId.values,
      map['projectileSlotSpellId'] as String?,
      fallback.projectileSlotSpellId,
    ),
    accessoryId: _enumFromName(
      AccessoryId.values,
      map['accessoryId'] as String?,
      fallback.accessoryId,
    ),
    abilityPrimaryId:
        (map['abilityPrimaryId'] as String?) ?? fallback.abilityPrimaryId,
    abilitySecondaryId:
        (map['abilitySecondaryId'] as String?) ?? fallback.abilitySecondaryId,
    abilityProjectileId:
        (map['abilityProjectileId'] as String?) ?? fallback.abilityProjectileId,
    abilitySpellId:
        (map['abilitySpellId'] as String?) ?? fallback.abilitySpellId,
    abilityMobilityId:
        (map['abilityMobilityId'] as String?) ?? fallback.abilityMobilityId,
    abilityJumpId: (map['abilityJumpId'] as String?) ?? fallback.abilityJumpId,
  );
}

EquippedLoadoutDef _defaultLoadoutForCharacter(PlayerCharacterId id) {
  final catalog = PlayerCharacterRegistry.resolve(id).catalog;
  return EquippedLoadoutDef(
    mask: catalog.loadoutSlotMask,
    mainWeaponId: catalog.weaponId,
    offhandWeaponId: catalog.offhandWeaponId,
    spellBookId: catalog.spellBookId,
    projectileSlotSpellId: catalog.projectileSlotSpellId,
    accessoryId: AccessoryId.strengthBelt,
    abilityPrimaryId: catalog.abilityPrimaryId,
    abilitySecondaryId: catalog.abilitySecondaryId,
    abilityProjectileId: catalog.abilityProjectileId,
    abilitySpellId: catalog.abilitySpellId,
    abilityMobilityId: catalog.abilityMobilityId,
    abilityJumpId: catalog.abilityJumpId,
  );
}
