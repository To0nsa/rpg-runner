import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/meta/meta_service.dart';
import '../../core/meta/meta_state.dart';

class MetaStore {
  static const String _prefsKey = 'ui.meta_state.v1';

  Future<MetaState> load(MetaService service) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final fallback = service.createNew();

    if (raw == null || raw.isEmpty) {
      await save(fallback);
      return fallback;
    }

    try {
      final decoded = jsonDecode(raw);
      Map<String, dynamic>? map;
      if (decoded is Map<String, dynamic>) {
        map = decoded;
      } else if (decoded is Map) {
        map = Map<String, dynamic>.from(decoded);
      }

      if (map != null) {
        final loaded = MetaState.fromJson(map, fallback: fallback);
        final normalized = service.normalize(loaded);
        if (normalized.schemaVersion != loaded.schemaVersion ||
            jsonEncode(normalized.toJson()) != jsonEncode(loaded.toJson())) {
          await save(normalized);
        }
        return normalized;
      }
    } catch (_) {
      // Fall through to defaults.
    }

    await save(fallback);
    return fallback;
  }

  Future<void> save(MetaState state) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(state.toJson());
    await prefs.setString(_prefsKey, payload);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
