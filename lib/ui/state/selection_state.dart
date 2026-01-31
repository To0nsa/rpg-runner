import '../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../core/levels/level_id.dart';
import '../../core/players/player_character_definition.dart';
import '../../core/projectiles/projectile_item_id.dart';
import '../../core/weapons/weapon_id.dart';

/// Menu-facing run type for the selected level.
enum RunType { practice, competitive }

/// Persistent menu selection state.
class SelectionState {
  const SelectionState({
    required this.selectedLevelId,
    required this.selectedRunType,
    required this.selectedCharacterId,
    required this.equippedLoadout,
  });

  static const SelectionState defaults = SelectionState(
    selectedLevelId: LevelId.field,
    selectedRunType: RunType.practice,
    selectedCharacterId: PlayerCharacterId.eloise,
    equippedLoadout: EquippedLoadoutDef(),
  );

  final LevelId selectedLevelId;
  final RunType selectedRunType;
  final PlayerCharacterId selectedCharacterId;
  final EquippedLoadoutDef equippedLoadout;

  bool get isCompetitive => selectedRunType == RunType.competitive;

  SelectionState copyWith({
    LevelId? selectedLevelId,
    RunType? selectedRunType,
    PlayerCharacterId? selectedCharacterId,
    EquippedLoadoutDef? equippedLoadout,
  }) {
    return SelectionState(
      selectedLevelId: selectedLevelId ?? this.selectedLevelId,
      selectedRunType: selectedRunType ?? this.selectedRunType,
      selectedCharacterId: selectedCharacterId ?? this.selectedCharacterId,
      equippedLoadout: equippedLoadout ?? this.equippedLoadout,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'levelId': selectedLevelId.name,
      'runType': selectedRunType.name,
      'characterId': selectedCharacterId.name,
      'loadout': _loadoutToJson(equippedLoadout),
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
    final loadout = _loadoutFromJson(json['loadout']);

    return SelectionState(
      selectedLevelId: levelId,
      selectedRunType: runType,
      selectedCharacterId: characterId,
      equippedLoadout: loadout,
    );
  }
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
    'projectileItemId': loadout.projectileItemId.name,
    'abilityPrimaryId': loadout.abilityPrimaryId,
    'abilitySecondaryId': loadout.abilitySecondaryId,
    'abilityProjectileId': loadout.abilityProjectileId,
    'abilityBonusId': loadout.abilityBonusId,
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
      WeaponId.basicSword,
    ),
    offhandWeaponId: _enumFromName(
      WeaponId.values,
      map['offhandWeaponId'] as String?,
      WeaponId.basicShield,
    ),
    projectileItemId: _enumFromName(
      ProjectileItemId.values,
      map['projectileItemId'] as String?,
      ProjectileItemId.iceBolt,
    ),
    abilityPrimaryId: (map['abilityPrimaryId'] as String?) ??
        const EquippedLoadoutDef().abilityPrimaryId,
    abilitySecondaryId: (map['abilitySecondaryId'] as String?) ??
        const EquippedLoadoutDef().abilitySecondaryId,
    abilityProjectileId: (map['abilityProjectileId'] as String?) ??
        const EquippedLoadoutDef().abilityProjectileId,
    abilityBonusId: (map['abilityBonusId'] as String?) ??
        const EquippedLoadoutDef().abilityBonusId,
    abilityMobilityId: (map['abilityMobilityId'] as String?) ??
        const EquippedLoadoutDef().abilityMobilityId,
    abilityJumpId: (map['abilityJumpId'] as String?) ??
        const EquippedLoadoutDef().abilityJumpId,
  );
}
