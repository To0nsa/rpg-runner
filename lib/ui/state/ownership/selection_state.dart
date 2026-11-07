import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:run_protocol/run_mode.dart';

import '../../levels/level_id_ui.dart';

export 'package:run_protocol/run_mode.dart';

/// A named, independent equipment and ability configuration.
class CharacterBuild {
  const CharacterBuild({required this.name, required this.loadout});
  final String name;
  final EquippedLoadoutDef loadout;

  CharacterBuild copyWith({String? name, EquippedLoadoutDef? loadout}) =>
      CharacterBuild(name: name ?? this.name, loadout: loadout ?? this.loadout);
}

/// The fixed build slots and remembered selection for one character.
class CharacterBuilds {
  CharacterBuilds({
    required List<CharacterBuild> builds,
    this.selectedIndex = 0,
  }) : builds = List.unmodifiable(builds) {
    if (builds.length != SelectionState.buildCount) {
      throw ArgumentError('Exactly three builds are required.');
    }
    RangeError.checkValidIndex(selectedIndex, builds, 'selectedIndex');
  }
  final List<CharacterBuild> builds;
  final int selectedIndex;
  CharacterBuild get selected => builds[selectedIndex];

  CharacterBuilds select(int index) =>
      CharacterBuilds(builds: builds, selectedIndex: index);

  CharacterBuilds replace(int index, CharacterBuild build) {
    final next = List<CharacterBuild>.of(builds);
    next[index] = build;
    return CharacterBuilds(builds: next, selectedIndex: selectedIndex);
  }
}

/// Persistent menu selections. Each character owns three independent builds.
class SelectionState {
  SelectionState({
    required this.selectedLevelId,
    required this.selectedRunMode,
    required this.selectedCharacterId,
    required Map<PlayerCharacterId, CharacterBuilds> buildsByCharacter,
  }) : buildsByCharacter = Map.unmodifiable({
         for (final id in PlayerCharacterId.values)
           id: buildsByCharacter[id] ?? _defaultBuilds(id),
       });

  static const buildCount = 3;
  static const buildUnlockLevels = [1, 5, 12];
  static const buildNameMaxLength = 28;
  static const schemaVersion = 2;
  static String defaultBuildName(int index) => 'Build ${index + 1}';
  static bool isBuildUnlocked(int index, int playerLevel) =>
      index >= 0 &&
      index < buildCount &&
      playerLevel >= buildUnlockLevels[index];

  static final defaults = SelectionState(
    selectedLevelId: LevelRegistry.defaultLevelId,
    selectedRunMode: RunMode.practice,
    selectedCharacterId: PlayerCharacterId.eloise,
    buildsByCharacter: const {},
  );

  final LevelId selectedLevelId;
  final RunMode selectedRunMode;
  final PlayerCharacterId selectedCharacterId;
  final Map<PlayerCharacterId, CharacterBuilds> buildsByCharacter;
  String get buildName => buildsFor(selectedCharacterId).selected.name;
  bool get isCompetitive => selectedRunMode == RunMode.competitive;
  CharacterBuilds buildsFor(PlayerCharacterId id) => buildsByCharacter[id]!;
  int selectedBuildIndexFor(PlayerCharacterId id) =>
      buildsFor(id).selectedIndex;
  EquippedLoadoutDef loadoutFor(PlayerCharacterId id, {int? buildIndex}) =>
      buildsFor(id).builds[buildIndex ?? selectedBuildIndexFor(id)].loadout;

  SelectionState copyWith({
    LevelId? selectedLevelId,
    RunMode? selectedRunMode,
    PlayerCharacterId? selectedCharacterId,
    Map<PlayerCharacterId, CharacterBuilds>? buildsByCharacter,
    String? buildName,
  }) {
    final character = selectedCharacterId ?? this.selectedCharacterId;
    final builds = {...(buildsByCharacter ?? this.buildsByCharacter)};
    if (buildName != null) {
      final slots = builds[character]!;
      builds[character] = slots.replace(
        slots.selectedIndex,
        slots.selected.copyWith(
          name: normalizeBuildName(buildName, buildIndex: slots.selectedIndex),
        ),
      );
    }
    return SelectionState(
      selectedLevelId: selectedLevelId ?? this.selectedLevelId,
      selectedRunMode: selectedRunMode ?? this.selectedRunMode,
      selectedCharacterId: character,
      buildsByCharacter: builds,
    );
  }

  SelectionState withBuildNameFor(
    PlayerCharacterId id,
    int index,
    String name,
  ) {
    final slots = buildsFor(id);
    return copyWith(
      buildsByCharacter: {
        ...buildsByCharacter,
        id: slots.replace(
          index,
          slots.builds[index].copyWith(
            name: normalizeBuildName(name, buildIndex: index),
          ),
        ),
      },
    );
  }

  SelectionState selectBuild(PlayerCharacterId id, int index) => copyWith(
    selectedCharacterId: id,
    buildsByCharacter: {...buildsByCharacter, id: buildsFor(id).select(index)},
  );

  SelectionState withLoadoutFor(
    PlayerCharacterId id,
    EquippedLoadoutDef loadout, {
    int? buildIndex,
  }) {
    final slots = buildsFor(id);
    final index = buildIndex ?? slots.selectedIndex;
    return copyWith(
      buildsByCharacter: {
        ...buildsByCharacter,
        id: slots.replace(
          index,
          slots.builds[index].copyWith(loadout: loadout),
        ),
      },
    );
  }

  /// Locked saved selections cannot bypass the account's unlock level.
  SelectionState atPlayerLevel(int level) => copyWith(
    buildsByCharacter: {
      for (final entry in buildsByCharacter.entries)
        entry.key: isBuildUnlocked(entry.value.selectedIndex, level)
            ? entry.value
            : entry.value.select(0),
    },
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'levelId': selectedLevelId.name,
    'runMode': selectedRunMode.name,
    'runType': selectedRunMode.name,
    'characterId': selectedCharacterId.name,
    'buildsByCharacter': {
      for (final entry in buildsByCharacter.entries)
        entry.key.name: {
          'selectedBuildIndex': entry.value.selectedIndex,
          'builds': [
            for (final build in entry.value.builds)
              {'name': build.name, 'loadout': _loadoutToJson(build.loadout)},
          ],
        },
    },
  };

  static SelectionState fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion ||
        json['buildsByCharacter'] is! Map) {
      return defaults;
    }
    final raw = json['buildsByCharacter'] as Map;
    final builds = <PlayerCharacterId, CharacterBuilds>{};
    for (final id in PlayerCharacterId.values) {
      final branch = raw[id.name];
      final fallback = _defaultBuilds(id);
      if (branch is! Map ||
          branch['builds'] is! List ||
          (branch['builds'] as List).length != buildCount) {
        builds[id] = fallback;
        continue;
      }
      final list = branch['builds'] as List;
      final selected = branch['selectedBuildIndex'];
      builds[id] = CharacterBuilds(
        selectedIndex: selected is int && selected >= 0 && selected < buildCount
            ? selected
            : 0,
        builds: [
          for (var i = 0; i < buildCount; i++)
            if (list[i] is Map)
              CharacterBuild(
                name: normalizeBuildName(
                  _stringOrNull((list[i] as Map)['name']),
                  buildIndex: i,
                ),
                loadout: _loadoutFromJson(
                  (list[i] as Map)['loadout'],
                  fallback: fallback.builds[i].loadout,
                ),
              )
            else
              fallback.builds[i],
        ],
      );
    }
    final levelId = _enumFromName(
      LevelId.values,
      _stringOrNull(json['levelId']),
      LevelRegistry.defaultLevelId,
    );
    return SelectionState(
      selectedLevelId: levelId.isSelectableInStandardUi
          ? levelId
          : LevelRegistry.defaultLevelId,
      selectedRunMode: _enumFromName(
        RunMode.values,
        _stringOrNull(json['runMode']) ?? _stringOrNull(json['runType']),
        RunMode.practice,
      ),
      selectedCharacterId: _enumFromName(
        PlayerCharacterId.values,
        _stringOrNull(json['characterId']),
        PlayerCharacterId.eloise,
      ),
      buildsByCharacter: builds,
    );
  }

  static String normalizeBuildName(String? raw, {int buildIndex = 0}) {
    final trimmed = (raw ?? '').trim();
    return trimmed.isEmpty
        ? defaultBuildName(buildIndex)
        : trimmed.characters.take(buildNameMaxLength).toString();
  }
}

CharacterBuilds _defaultBuilds(PlayerCharacterId id) => CharacterBuilds(
  builds: [
    for (var i = 0; i < SelectionState.buildCount; i++)
      CharacterBuild(
        name: SelectionState.defaultBuildName(i),
        loadout: _defaultLoadoutForCharacter(id),
      ),
  ],
);

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

String? _stringOrNull(Object? raw) => raw is String ? raw : null;

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
      playerEquippableProjectileIds,
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
