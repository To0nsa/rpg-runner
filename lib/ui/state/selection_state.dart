import '../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../core/levels/level_id.dart';
import '../../core/players/player_character_definition.dart';
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

  static final SelectionState defaults = SelectionState(
    selectedLevelId: LevelId.field,
    selectedRunType: RunType.practice,
    selectedCharacterId: PlayerCharacterId.eloise,
    loadoutsByCharacter: _seedLoadoutsWith(const EquippedLoadoutDef()),
    buildName: defaultBuildName,
  );

  final LevelId selectedLevelId;
  final RunType selectedRunType;
  final PlayerCharacterId selectedCharacterId;
  final Map<PlayerCharacterId, EquippedLoadoutDef> loadoutsByCharacter;
  final String buildName;

  bool get isCompetitive => selectedRunType == RunType.competitive;

  EquippedLoadoutDef loadoutFor(PlayerCharacterId id) {
    return loadoutsByCharacter[id] ?? const EquippedLoadoutDef();
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
    final baseLoadout = json.containsKey('loadout')
        ? _loadoutFromJson(json['loadout'])
        : const EquippedLoadoutDef();
    final loadouts = _seedLoadoutsWith(baseLoadout);
    final loadoutsRaw = json['loadoutsByCharacter'];
    if (loadoutsRaw is Map) {
      for (final id in PlayerCharacterId.values) {
        final raw = loadoutsRaw[id.name];
        if (raw is Map<String, dynamic>) {
          loadouts[id] = _loadoutFromJson(raw);
        } else if (raw is Map) {
          loadouts[id] = _loadoutFromJson(Map<String, dynamic>.from(raw));
        }
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

Map<PlayerCharacterId, EquippedLoadoutDef> _seedLoadoutsWith(
  EquippedLoadoutDef loadout,
) {
  return <PlayerCharacterId, EquippedLoadoutDef>{
    for (final id in PlayerCharacterId.values) id: loadout,
  };
}

Map<PlayerCharacterId, EquippedLoadoutDef> _ensureLoadoutsForAllCharacters(
  Map<PlayerCharacterId, EquippedLoadoutDef> source,
) {
  return <PlayerCharacterId, EquippedLoadoutDef>{
    for (final id in PlayerCharacterId.values)
      id: source[id] ?? const EquippedLoadoutDef(),
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
    'ProjectileId': loadout.projectileId.name,
    'spellBookId': loadout.spellBookId.name,
    'projectileSlotSpellId': loadout.projectileSlotSpellId?.name,
    'accessoryId': loadout.accessoryId.name,
    'abilityPrimaryId': loadout.abilityPrimaryId,
    'abilitySecondaryId': loadout.abilitySecondaryId,
    'abilityProjectileId': loadout.abilityProjectileId,
    'abilitySpellId': loadout.abilitySpellId,
    'abilityMobilityId': loadout.abilityMobilityId,
    'abilityJumpId': loadout.abilityJumpId,
  };
}

EquippedLoadoutDef _loadoutFromJson(Object? raw) {
  if (raw is! Map) {
    return const EquippedLoadoutDef();
  }
  final map = Map<String, dynamic>.from(raw);
  return EquippedLoadoutDef(
    mask: map['mask'] is int ? map['mask'] as int : LoadoutSlotMask.defaultMask,
    mainWeaponId: _enumFromName(
      WeaponId.values,
      map['mainWeaponId'] as String?,
      WeaponId.woodenSword,
    ),
    offhandWeaponId: _enumFromName(
      WeaponId.values,
      map['offhandWeaponId'] as String?,
      WeaponId.woodenShield,
    ),
    projectileId: _enumFromName(
      ProjectileId.values,
      map['ProjectileId'] as String?,
      ProjectileId.throwingKnife,
    ),
    spellBookId: _enumFromName(
      SpellBookId.values,
      map['spellBookId'] as String?,
      SpellBookId.basicSpellBook,
    ),
    projectileSlotSpellId: map.containsKey('projectileSlotSpellId')
        ? _enumFromNameNullable(
            ProjectileId.values,
            map['projectileSlotSpellId'] as String?,
          )
        : const EquippedLoadoutDef().projectileSlotSpellId,
    accessoryId: _enumFromName(
      AccessoryId.values,
      map['accessoryId'] as String?,
      AccessoryId.speedBoots,
    ),
    abilityPrimaryId:
        (map['abilityPrimaryId'] as String?) ??
        const EquippedLoadoutDef().abilityPrimaryId,
    abilitySecondaryId:
        (map['abilitySecondaryId'] as String?) ??
        const EquippedLoadoutDef().abilitySecondaryId,
    abilityProjectileId:
        (map['abilityProjectileId'] as String?) ??
        const EquippedLoadoutDef().abilityProjectileId,
    abilitySpellId:
        (map['abilitySpellId'] as String?) ??
        (map['abilityBonusId'] as String?) ??
        const EquippedLoadoutDef().abilitySpellId,
    abilityMobilityId:
        (map['abilityMobilityId'] as String?) ??
        const EquippedLoadoutDef().abilityMobilityId,
    abilityJumpId:
        (map['abilityJumpId'] as String?) ??
        const EquippedLoadoutDef().abilityJumpId,
  );
}

T? _enumFromNameNullable<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
