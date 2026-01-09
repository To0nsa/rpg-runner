import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/levels/level_id.dart';
import 'leaderboard_store.dart';
import 'run_result.dart';

class SharedPrefsLeaderboardStore implements LeaderboardStore {
  static const String _entriesKeyPrefix = 'leaderboard_v2_entries_';
  static const String _nextIdKeyPrefix = 'leaderboard_v2_next_id_';

  String _entriesKey(LevelId levelId) => '$_entriesKeyPrefix${levelId.name}';
  String _nextIdKey(LevelId levelId) => '$_nextIdKeyPrefix${levelId.name}';

  @override
  Future<LeaderboardSnapshot> addResult({
    required LevelId levelId,
    required RunResult result,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final nextId = (prefs.getInt(_nextIdKey(levelId)) ?? 1);
    final stored = result.copyWith(runId: nextId);
    final entries = _loadEntries(prefs, levelId);
    entries.add(stored);
    entries.sort(_compare);

    final top = entries.length > 10 ? entries.sublist(0, 10) : entries;
    await prefs.setString(_entriesKey(levelId), _encode(top));
    await prefs.setInt(_nextIdKey(levelId), nextId + 1);

    return LeaderboardSnapshot(
      entries: List<RunResult>.unmodifiable(top),
      current: stored,
    );
  }

  @override
  Future<List<RunResult>> loadTop10({required LevelId levelId}) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _loadEntries(prefs, levelId);
    entries.sort(_compare);
    if (entries.length > 10) return entries.sublist(0, 10);
    return List<RunResult>.unmodifiable(entries);
  }

  List<RunResult> _loadEntries(SharedPreferences prefs, LevelId levelId) {
    final raw = prefs.getString(_entriesKey(levelId));
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

  String _encode(List<RunResult> entries) {
    return jsonEncode(entries.map((entry) => entry.toJson()).toList());
  }

  int _compare(RunResult a, RunResult b) {
    if (a.score != b.score) return b.score.compareTo(a.score);
    if (a.endedAtMs != b.endedAtMs) {
      return b.endedAtMs.compareTo(a.endedAtMs);
    }
    return b.runId.compareTo(a.runId);
  }
}
