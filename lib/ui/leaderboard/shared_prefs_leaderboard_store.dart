import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:runner_core/levels/level_id.dart';
import '../state/selection_state.dart';
import 'leaderboard_store.dart';
import 'run_result.dart';

class SharedPrefsLeaderboardStore implements LeaderboardStore {
  // v3: namespace leaderboards by run mode.
  static const String _entriesKeyPrefix = 'leaderboard_v3_entries_';
  static const String _nextIdKeyPrefix = 'leaderboard_v3_next_id_';

  // v2: legacy keys (per-level only). Kept for best-effort migration/read.
  static const String _legacyEntriesKeyPrefix = 'leaderboard_v2_entries_';
  static const String _legacyNextIdKeyPrefix = 'leaderboard_v2_next_id_';

  String _entriesKey(LevelId levelId, RunMode runMode) =>
      '$_entriesKeyPrefix${levelId.name}_${runMode.name}';

  String _nextIdKey(LevelId levelId, RunMode runMode) =>
      '$_nextIdKeyPrefix${levelId.name}_${runMode.name}';

  String _legacyEntriesKey(LevelId levelId) =>
      '$_legacyEntriesKeyPrefix${levelId.name}';

  String _legacyNextIdKey(LevelId levelId) =>
      '$_legacyNextIdKeyPrefix${levelId.name}';

  @override
  Future<LeaderboardSnapshot> addResult({
    required LevelId levelId,
    required RunMode runMode,
    required RunResult result,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final existingNextId = prefs.getInt(_nextIdKey(levelId, runMode));
    final entries = _loadEntries(prefs, levelId, runMode);
    final nextId =
        existingNextId ??
        _nextIdFromLegacyOrEntries(
          prefs: prefs,
          levelId: levelId,
          runMode: runMode,
          entries: entries,
        );
    final stored = result.copyWith(runId: nextId);
    // Defensive: avoid duplicate runIds (possible when mixing legacy and v3
    // data on first write after upgrade).
    entries.removeWhere((e) => e.runId == stored.runId);
    entries.add(stored);
    entries.sort(_compare);

    final unique = _dedupeByRunId(entries);
    final top = unique.length > 10 ? unique.sublist(0, 10) : unique;
    await prefs.setString(_entriesKey(levelId, runMode), _encode(top));
    await prefs.setInt(_nextIdKey(levelId, runMode), nextId + 1);

    return LeaderboardSnapshot(
      entries: List<RunResult>.unmodifiable(top),
      current: stored,
    );
  }

  @override
  Future<List<RunResult>> loadTop10({
    required LevelId levelId,
    required RunMode runMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _loadEntries(prefs, levelId, runMode);
    entries.sort(_compare);
    final unique = _dedupeByRunId(entries);
    if (unique.length > 10) {
      return List<RunResult>.unmodifiable(unique.sublist(0, 10));
    }
    return List<RunResult>.unmodifiable(unique);
  }

  List<RunResult> _loadEntries(
    SharedPreferences prefs,
    LevelId levelId,
    RunMode runMode,
  ) {
    final primary = prefs.getString(_entriesKey(levelId, runMode));
    final raw = (primary == null || primary.isEmpty)
        ? _loadLegacy(prefs, levelId, runMode)
        : primary;
    if (raw == null || raw.isEmpty) return <RunResult>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <RunResult>[];

    final entries = <RunResult>[];
    for (final entry in decoded) {
      if (entry is Map<String, dynamic>) {
        entries.add(RunResult.fromJson(entry));
      } else if (entry is Map) {
        entries.add(RunResult.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    return entries;
  }

  String? _loadLegacy(
    SharedPreferences prefs,
    LevelId levelId,
    RunMode runMode,
  ) {
    // Best-effort: if a user upgrades from v2, show the legacy per-level
    // scores under practice so the leaderboard isn't empty.
    if (runMode != RunMode.practice) return null;
    final legacy = prefs.getString(_legacyEntriesKey(levelId));
    if (legacy == null || legacy.isEmpty) return null;
    return legacy;
  }

  String _encode(List<RunResult> entries) {
    return jsonEncode(entries.map((entry) => entry.toJson()).toList());
  }

  int _nextIdFromLegacyOrEntries({
    required SharedPreferences prefs,
    required LevelId levelId,
    required RunMode runMode,
    required List<RunResult> entries,
  }) {
    // Only attempt v2->v3 continuity for practice leaderboards.
    if (runMode != RunMode.practice) return 1;

    final legacyNextId = prefs.getInt(_legacyNextIdKey(levelId));
    if (legacyNextId != null && legacyNextId > 0) {
      return legacyNextId;
    }

    // Fall back to the highest runId we can see in the loaded entries (which
    // may be legacy data when v3 is empty) to avoid duplicate runIds.
    var maxId = 0;
    for (final entry in entries) {
      if (entry.runId > maxId) maxId = entry.runId;
    }
    return maxId > 0 ? maxId + 1 : 1;
  }

  List<RunResult> _dedupeByRunId(List<RunResult> sortedEntries) {
    // Keep the highest-ranked entry for each runId (the list is already sorted
    // best-first).
    final seen = <int>{};
    final unique = <RunResult>[];
    for (final entry in sortedEntries) {
      if (seen.add(entry.runId)) unique.add(entry);
    }
    return unique;
  }

  int _compare(RunResult a, RunResult b) {
    if (a.score != b.score) return b.score.compareTo(a.score);
    if (a.endedAtMs != b.endedAtMs) {
      return b.endedAtMs.compareTo(a.endedAtMs);
    }
    return b.runId.compareTo(a.runId);
  }
}
