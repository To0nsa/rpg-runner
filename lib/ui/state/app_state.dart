import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../core/levels/level_id.dart';
import '../../core/meta/gear_slot.dart';
import '../../core/meta/meta_service.dart';
import '../../core/meta/meta_state.dart';
import '../../core/players/player_character_definition.dart';
import '../app/ui_routes.dart';
import 'selection_state.dart';
import 'selection_store.dart';
import 'meta_store.dart';
import 'user_profile.dart';
import 'user_profile_store.dart';

class AppState extends ChangeNotifier {
  AppState({
    SelectionStore? selectionStore,
    MetaStore? metaStore,
    UserProfileStore? userProfileStore,
    MetaService? metaService,
  }) : _selectionStore = selectionStore ?? SelectionStore(),
       _metaStore = metaStore ?? MetaStore(),
       _profileStore = userProfileStore ?? UserProfileStore(),
       _metaService = metaService ?? const MetaService();

  final Random _random = Random();
  final SelectionStore _selectionStore;
  final MetaStore _metaStore;
  final UserProfileStore _profileStore;
  final MetaService _metaService;

  SelectionState _selection = SelectionState.defaults;
  MetaState _meta = const MetaService().createNew();
  UserProfile _profile = UserProfile.empty();
  bool _bootstrapped = false;
  bool _warmupStarted = false;

  SelectionState get selection => _selection;
  MetaState get meta => _meta;
  UserProfile get profile => _profile;
  bool get isBootstrapped => _bootstrapped;

  Future<void> bootstrap({bool force = false}) async {
    if (_bootstrapped && !force) return;
    final loadedSelection = await _selectionStore.load();
    final loadedMeta = await _metaStore.load(_metaService);
    final loadedProfile = await _profileStore.load();
    _selection = loadedSelection;
    _meta = loadedMeta;
    _profile = loadedProfile;
    _bootstrapped = true;
    notifyListeners();
  }

  void applyDefaults() {
    _selection = SelectionState.defaults;
    _meta = _metaService.createNew();
    _profile = _profileStore.createFresh();
    _persistSelection();
    _persistMeta();
    _persistProfile();
    notifyListeners();
  }

  Future<void> setLevel(LevelId levelId) async {
    _selection = _selection.copyWith(selectedLevelId: levelId);
    _persistSelection();
    notifyListeners();
  }

  Future<void> setRunType(RunType runType) async {
    _selection = _selection.copyWith(selectedRunType: runType);
    _persistSelection();
    notifyListeners();
  }

  Future<void> setCharacter(PlayerCharacterId id) async {
    _selection = _selection.copyWith(selectedCharacterId: id);
    _persistSelection();
    notifyListeners();
  }

  Future<void> setLoadout(EquippedLoadoutDef loadout) async {
    _selection = _selection.copyWith(equippedLoadout: loadout);
    _persistSelection();
    notifyListeners();
  }

  Future<void> equipGear({
    required PlayerCharacterId characterId,
    required GearSlot slot,
    required Object itemId,
  }) async {
    final next = _metaService.equip(
      _meta,
      characterId: characterId,
      slot: slot,
      itemId: itemId,
    );
    _meta = next;
    _persistMeta();
    notifyListeners();
  }

  Future<void> setBuildName(String buildName) async {
    final normalized = SelectionState.normalizeBuildName(buildName);
    if (normalized == _selection.buildName) return;
    _selection = _selection.copyWith(buildName: normalized);
    _persistSelection();
    notifyListeners();
  }

  Future<void> updateProfile(
    UserProfile Function(UserProfile current) fn,
  ) async {
    final current = _profile;
    final updated = fn(current);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final next = updated.copyWith(
      schemaVersion: UserProfile.latestSchemaVersion,
      profileId: updated.profileId.isEmpty
          ? current.profileId
          : updated.profileId,
      createdAtMs: updated.createdAtMs == 0
          ? current.createdAtMs
          : updated.createdAtMs,
      updatedAtMs: nowMs,
      revision: current.revision + 1,
    );
    _profile = next;
    await _profileStore.save(next);
    notifyListeners();
  }

  void startWarmup() {
    if (_warmupStarted) return;
    _warmupStarted = true;
    // TODO: kick off non-critical asset caching and lightweight services.
  }

  RunStartArgs buildRunStartArgs({int? seed}) {
    final equipped = _buildRunEquippedLoadout();
    return RunStartArgs(
      runId: createRunId(),
      seed: seed ?? _random.nextInt(1 << 31),
      levelId: _selection.selectedLevelId,
      playerCharacterId: _selection.selectedCharacterId,
      runType: _selection.selectedRunType,
      equippedLoadout: equipped,
    );
  }

  EquippedLoadoutDef _buildRunEquippedLoadout() {
    final gear = _meta.equippedFor(_selection.selectedCharacterId);
    final base = _selection.equippedLoadout;
    return EquippedLoadoutDef(
      mask: base.mask,
      mainWeaponId: gear.mainWeaponId,
      offhandWeaponId: gear.offhandWeaponId,
      projectileItemId: gear.throwingWeaponId,
      spellBookId: gear.spellBookId,
      accessoryId: gear.accessoryId,
      abilityPrimaryId: base.abilityPrimaryId,
      abilitySecondaryId: base.abilitySecondaryId,
      abilityProjectileId: base.abilityProjectileId,
      abilityBonusId: base.abilityBonusId,
      abilityMobilityId: base.abilityMobilityId,
      abilityJumpId: base.abilityJumpId,
    );
  }

  int createRunId() => _createRunId();

  int _createRunId() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final salt = _random.nextInt(1 << 20);
    return (nowMs << 20) | salt;
  }

  void _persistSelection() {
    _selectionStore.save(_selection);
  }

  void _persistMeta() {
    _metaStore.save(_meta);
  }

  void _persistProfile() {
    _profileStore.save(_profile);
  }
}
