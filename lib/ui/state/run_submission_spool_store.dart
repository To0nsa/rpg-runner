import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pending_run_submission.dart';

abstract class RunSubmissionSpoolStore {
  Future<void> upsert({required PendingRunSubmission submission});

  Future<PendingRunSubmission?> load({required String runSessionId});

  Future<List<PendingRunSubmission>> loadAll();

  Future<void> remove({required String runSessionId});

  Future<void> clear();
}

class SharedPrefsRunSubmissionSpoolStore implements RunSubmissionSpoolStore {
  SharedPrefsRunSubmissionSpoolStore({
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  static const String _entriesKey = 'run_submission_spool_v1_entries';

  final Future<SharedPreferences> Function() _prefsProvider;

  @override
  Future<void> upsert({required PendingRunSubmission submission}) async {
    final entries = await loadAll();
    final mapBySession = <String, PendingRunSubmission>{
      for (final entry in entries) entry.runSessionId: entry,
    };
    mapBySession[submission.runSessionId] = submission;
    await _writeEntries(mapBySession.values.toList(growable: false));
  }

  @override
  Future<PendingRunSubmission?> load({required String runSessionId}) async {
    final entries = await loadAll();
    for (final entry in entries) {
      if (entry.runSessionId == runSessionId) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<List<PendingRunSubmission>> loadAll() async {
    final prefs = await _prefsProvider();
    final raw = prefs.getString(_entriesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <PendingRunSubmission>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <PendingRunSubmission>[];
    }
    final entries = <PendingRunSubmission>[];
    for (final item in decoded) {
      try {
        entries.add(PendingRunSubmission.fromJson(item));
      } on FormatException {
        // Ignore malformed rows and keep valid rows recoverable.
      }
    }
    entries.sort((a, b) {
      final byCreated = a.createdAtMs.compareTo(b.createdAtMs);
      if (byCreated != 0) {
        return byCreated;
      }
      return a.runSessionId.compareTo(b.runSessionId);
    });
    return List<PendingRunSubmission>.unmodifiable(entries);
  }

  @override
  Future<void> remove({required String runSessionId}) async {
    final entries = await loadAll();
    final next = entries
        .where((entry) => entry.runSessionId != runSessionId)
        .toList(growable: false);
    await _writeEntries(next);
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefsProvider();
    await prefs.remove(_entriesKey);
  }

  Future<void> _writeEntries(List<PendingRunSubmission> entries) async {
    final prefs = await _prefsProvider();
    final payload = jsonEncode(
      entries.map((entry) => entry.toJson()).toList(growable: false),
    );
    await prefs.setString(_entriesKey, payload);
  }
}
