import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ownership_pending_command.dart';

List<OwnershipPendingCommand> _sortPendingCommands(
  Iterable<OwnershipPendingCommand> entries,
) {
  final sorted = entries.toList(growable: false);
  sorted.sort((a, b) {
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
  return sorted;
}

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
  Future<void> upsertCoalesced({
    required OwnershipPendingCommand command,
  }) async {
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
    final entries = _sortPendingCommands(_byKey.values);
    return List<OwnershipPendingCommand>.unmodifiable(entries);
  }

  @override
  Future<void> removeByCoalesceKey({required String coalesceKey}) async {
    _byKey.remove(coalesceKey);
  }

  @override
  Future<void> replaceAll({
    required List<OwnershipPendingCommand> commands,
  }) async {
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
  Future<void> _mutationQueue = Future<void>.value();

  Future<T> _enqueueMutation<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutationQueue = _mutationQueue.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  Future<void> upsertCoalesced({required OwnershipPendingCommand command}) {
    return _enqueueMutation(() async {
      final existing = await _readAllEntries(sort: false);
      final byKey = <String, OwnershipPendingCommand>{
        for (final item in existing) item.coalesceKey: item,
      };
      final prior = byKey[command.coalesceKey];
      byKey[command.coalesceKey] = prior == null
          ? command
          : command.copyWith(createdAtMs: prior.createdAtMs);
      await _writeEntries(byKey.values.toList(growable: false));
    });
  }

  @override
  Future<OwnershipPendingCommand?> loadByCoalesceKey({
    required String coalesceKey,
  }) async {
    final entries = await _readAllEntries(sort: false);
    for (final entry in entries) {
      if (entry.coalesceKey == coalesceKey) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<List<OwnershipPendingCommand>> loadAll() async {
    return _readAllEntries(sort: true);
  }

  Future<List<OwnershipPendingCommand>> _readAllEntries({
    required bool sort,
  }) async {
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
    if (!sort) {
      return List<OwnershipPendingCommand>.unmodifiable(entries);
    }
    return List<OwnershipPendingCommand>.unmodifiable(
      _sortPendingCommands(entries),
    );
  }

  @override
  Future<void> removeByCoalesceKey({required String coalesceKey}) {
    return _enqueueMutation(() async {
      final existing = await _readAllEntries(sort: false);
      final next = existing
          .where((entry) => entry.coalesceKey != coalesceKey)
          .toList(growable: false);
      await _writeEntries(next);
    });
  }

  @override
  Future<void> replaceAll({required List<OwnershipPendingCommand> commands}) {
    return _enqueueMutation(() => _writeEntries(commands));
  }

  @override
  Future<void> clear() {
    return _enqueueMutation(() async {
      final prefs = await _prefsProvider();
      await prefs.remove(storageKey);
    });
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
