import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'selection_state.dart';

class SelectionStore {
  static const String _prefsKey = 'ui.selection_state.v1';

  Future<SelectionState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return SelectionState.defaults;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return SelectionState.fromJson(decoded);
      }
      if (decoded is Map) {
        return SelectionState.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Fall through to defaults.
    }

    return SelectionState.defaults;
  }

  Future<void> save(SelectionState state) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(state.toJson());
    await prefs.setString(_prefsKey, payload);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
