import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ownership_pending_command.dart';

abstract class OwnershipOutboxStore {
  Future<void> upsertCoalesced({required OwnershipPendingCommand command});

  Future<OwnershipPendingCommand?> loadByCoalesceKey({
    required String coalesceKey,
  });

  Future<List<OwnershipPendingCommand>> loadAll();

  Future<void> removeByCoalesceKey({required String coalesceKey});

  Future<void> replaceAll({required List<OwnershipPendingCommand> commands});

  Future<void> clear();
}

/// Volatile in-memory outbox store used by tests and non-persistent contexts.
class InMemoryOwnershipOutboxStore implements OwnershipOutboxStore {
  final Map<String, OwnershipPendingCommand> _byKey =
      <String, OwnershipPendingCommand>{};

  @override
  Future<void> upsertCoalesced({required OwnershipPendingCommand command}) async {
    final prior = _byKey[command.coalesceKey];
    _byKey[command.coalesceKey] = prior == null
        ? command
        : command.copyWith(createdAtMs: prior.createdAtMs);
  }

  @override
  Future<OwnershipPendingCommand?> loadByCoalesceKey({
    required String coalesceKey,
  }) async {
    return _byKey[coalesceKey];
  }

  @override
  Future<List<OwnershipPendingCommand>> loadAll() async {
    final entries = _byKey.values.toList(growable: false);
    entries.sort((a, b) {
      final byCreated = a.createdAtMs.compareTo(b.createdAtMs);
      if (byCreated != 0) {
        return byCreated;
      }
      final byUpdated = a.updatedAtMs.compareTo(b.updatedAtMs);
      if (byUpdated != 0) {
        return byUpdated;
      }
      return a.coalesceKey.compareTo(b.coalesceKey);
    });
    return List<OwnershipPendingCommand>.unmodifiable(entries);
  }

  @override
  Future<void> removeByCoalesceKey({required String coalesceKey}) async {
    _byKey.remove(coalesceKey);
  }

  @override
  Future<void> replaceAll({required List<OwnershipPendingCommand> commands}) async {
    _byKey
      ..clear()
      ..addEntries(commands.map((entry) => MapEntry(entry.coalesceKey, entry)));
  }

  @override
  Future<void> clear() async {
    _byKey.clear();
  }
}

class SharedPrefsOwnershipOutboxStore implements OwnershipOutboxStore {
  SharedPrefsOwnershipOutboxStore({
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  static const String storageKey = 'ui.ownership_outbox.v2';
  static const int _storageVersion = 2;

  final Future<SharedPreferences> Function() _prefsProvider;

  @override
  Future<void> upsertCoalesced({required OwnershipPendingCommand command}) async {
    final existing = await loadAll();
    final byKey = <String, OwnershipPendingCommand>{
      for (final item in existing) item.coalesceKey: item,
    };
    final prior = byKey[command.coalesceKey];
    byKey[command.coalesceKey] = prior == null
        ? command
        : command.copyWith(createdAtMs: prior.createdAtMs);
    await _writeEntries(byKey.values.toList(growable: false));
  }

  @override
  Future<OwnershipPendingCommand?> loadByCoalesceKey({
    required String coalesceKey,
  }) async {
    final entries = await loadAll();
    for (final entry in entries) {
      if (entry.coalesceKey == coalesceKey) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<List<OwnershipPendingCommand>> loadAll() async {
    final prefs = await _prefsProvider();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <OwnershipPendingCommand>[];
    }
    final decoded = jsonDecode(raw);
    final rows = _decodeRows(decoded);
    if (rows.isEmpty) {
      return const <OwnershipPendingCommand>[];
    }
    final entries = <OwnershipPendingCommand>[];
    for (final row in rows) {
      final parsed = OwnershipPendingCommand.fromJson(row);
      if (parsed != null) {
        entries.add(parsed);
      }
    }
    entries.sort((a, b) {
      final byCreated = a.createdAtMs.compareTo(b.createdAtMs);
      if (byCreated != 0) {
        return byCreated;
      }
      final byUpdated = a.updatedAtMs.compareTo(b.updatedAtMs);
      if (byUpdated != 0) {
        return byUpdated;
      }
      return a.coalesceKey.compareTo(b.coalesceKey);
    });
    return List<OwnershipPendingCommand>.unmodifiable(entries);
  }

  @override
  Future<void> removeByCoalesceKey({required String coalesceKey}) async {
    final existing = await loadAll();
    final next = existing
        .where((entry) => entry.coalesceKey != coalesceKey)
        .toList(growable: false);
    await _writeEntries(next);
  }

  @override
  Future<void> replaceAll({required List<OwnershipPendingCommand> commands}) {
    return _writeEntries(commands);
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefsProvider();
    await prefs.remove(storageKey);
  }

  Future<void> _writeEntries(List<OwnershipPendingCommand> entries) async {
    final prefs = await _prefsProvider();
    final payload = <String, Object?>{
      'version': _storageVersion,
      'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
    };
    await prefs.setString(storageKey, jsonEncode(payload));
  }

  List<Object?> _decodeRows(Object? decoded) {
    if (decoded is List) {
      return List<Object?>.from(decoded);
    }
    if (decoded is Map) {
      final map = Map<String, Object?>.from(decoded);
      final rows = map['entries'];
      if (rows is List) {
        return List<Object?>.from(rows);
      }
    }
    return const <Object?>[];
  }
}
