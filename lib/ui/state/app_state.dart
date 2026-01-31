import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../core/levels/level_id.dart';
import '../../core/players/player_character_definition.dart';
import '../app/ui_routes.dart';
import 'selection_state.dart';
import 'selection_store.dart';

class AppState extends ChangeNotifier {
  AppState({SelectionStore? selectionStore})
      : _selectionStore = selectionStore ?? SelectionStore();

  final SelectionStore _selectionStore;

  SelectionState _selection = SelectionState.defaults;
  bool _bootstrapped = false;
  bool _warmupStarted = false;

  SelectionState get selection => _selection;
  bool get isBootstrapped => _bootstrapped;

  Future<void> bootstrap({bool force = false}) async {
    if (_bootstrapped && !force) return;
    final loaded = await _selectionStore.load();
    _selection = loaded;
    _bootstrapped = true;
    notifyListeners();
  }

  void applyDefaults() {
    _selection = SelectionState.defaults;
    _persistSelection();
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
}
