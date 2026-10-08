import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ownership/selection_state.dart';

/// Device-local developer settings, deliberately separate from account caches.
abstract class DeveloperProfileStore {
  /// Missing preferences default to normal account startup.
  Future<bool> loadEnabled();

  /// Completes after the toggle is saved, or throws without changing profiles.
  Future<void> saveEnabled(bool enabled);

  /// Reads developer selections, using defaults for missing or malformed data.
  Future<SelectionState> loadSelection();

  /// Persists only developer selections; callers serialize concurrent writes.
  Future<void> saveSelection(SelectionState selection);
}

/// Persists the developer toggle and loadouts across ordinary app updates.
class SharedPrefsDeveloperProfileStore implements DeveloperProfileStore {
  static const _enabledKey = 'developer_practice.enabled.v1';
  static const _selectionKey = 'developer_practice.selection.v1';

  @override
  Future<bool> loadEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  @override
  Future<void> saveEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_enabledKey, enabled)) {
      throw StateError('Could not save Developer mode.');
    }
  }

  @override
  Future<SelectionState> loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_selectionKey);
    if (raw == null) return SelectionState.defaults;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) return SelectionState.fromJson(json);
    } on FormatException {
      // A damaged developer save must not make the development build unusable.
    } on TypeError {
      // Catalog/schema edits can invalidate an older local selection.
    }
    return SelectionState.defaults;
  }

  @override
  Future<void> saveSelection(SelectionState selection) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_selectionKey, jsonEncode(selection.toJson()))) {
      throw StateError('Could not save the developer loadout.');
    }
  }
}
