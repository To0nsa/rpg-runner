import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../core/levels/level_id.dart';
import '../../core/players/player_character_definition.dart';
import '../app/ui_routes.dart';
import 'selection_state.dart';
import 'selection_store.dart';
import 'user_profile.dart';
import 'user_profile_store.dart';

class AppState extends ChangeNotifier {
  AppState({SelectionStore? selectionStore, UserProfileStore? userProfileStore})
      : _selectionStore = selectionStore ?? SelectionStore(),
        _profileStore = userProfileStore ?? UserProfileStore();

  final SelectionStore _selectionStore;
  final UserProfileStore _profileStore;

  SelectionState _selection = SelectionState.defaults;
  UserProfile _profile = UserProfile.empty();
  bool _bootstrapped = false;
  bool _warmupStarted = false;

  SelectionState get selection => _selection;
  UserProfile get profile => _profile;
  bool get isBootstrapped => _bootstrapped;

  Future<void> bootstrap({bool force = false}) async {
    if (_bootstrapped && !force) return;
    final loadedSelection = await _selectionStore.load();
    final loadedProfile = await _profileStore.load();
    _selection = loadedSelection;
    _profile = loadedProfile;
    _bootstrapped = true;
    notifyListeners();
  }

  void applyDefaults() {
    _selection = SelectionState.defaults;
    _profile = _profileStore.createFresh();
    _persistSelection();
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
      profileId:
          updated.profileId.isEmpty ? current.profileId : updated.profileId,
      createdAtMs:
          updated.createdAtMs == 0 ? current.createdAtMs : updated.createdAtMs,
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
    return RunStartArgs(
      seed: seed ?? Random().nextInt(1 << 31),
      levelId: _selection.selectedLevelId,
      playerCharacterId: _selection.selectedCharacterId,
      runType: _selection.selectedRunType,
    );
  }

  void _persistSelection() {
    _selectionStore.save(_selection);
  }

  void _persistProfile() {
    _profileStore.save(_profile);
  }
}
