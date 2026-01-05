import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'leaderboard_store.dart';
import 'run_result.dart';

class SharedPrefsLeaderboardStore implements LeaderboardStore {
  static const String _entriesKey = 'leaderboard_v1_entries';
  static const String _nextIdKey = 'leaderboard_v1_next_id';

  @override
  Future<LeaderboardSnapshot> addResult(RunResult result) async {
    final prefs = await SharedPreferences.getInstance();

    final nextId = (prefs.getInt(_nextIdKey) ?? 1);
    final stored = result.copyWith(runId: nextId);
    final entries = _loadEntries(prefs);
    entries.add(stored);
    entries.sort(_compare);

    final top = entries.length > 10 ? entries.sublist(0, 10) : entries;
    await prefs.setString(_entriesKey, _encode(top));
    await prefs.setInt(_nextIdKey, nextId + 1);

    return LeaderboardSnapshot(
      entries: List<RunResult>.unmodifiable(top),
      current: stored,
    );
  }

  @override
  Future<List<RunResult>> loadTop10() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _loadEntries(prefs);
    entries.sort(_compare);
    if (entries.length > 10) return entries.sublist(0, 10);
    return List<RunResult>.unmodifiable(entries);
  }

  List<RunResult> _loadEntries(SharedPreferences prefs) {
    final raw = prefs.getString(_entriesKey);
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
