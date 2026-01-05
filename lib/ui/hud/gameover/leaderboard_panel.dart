import 'package:flutter/material.dart';

import '../../../core/events/game_event.dart';
import '../../../core/tuning/v0_score_tuning.dart';
import '../../leaderboard/leaderboard_store.dart';
import '../../leaderboard/run_result.dart';
import '../../leaderboard/shared_prefs_leaderboard_store.dart';

class LeaderboardPanel extends StatefulWidget {
  const LeaderboardPanel({
    super.key,
    required this.runEndedEvent,
    required this.scoreTuning,
    required this.tickHz,
    this.leaderboardStore,
  });

  final RunEndedEvent? runEndedEvent;
  final V0ScoreTuning scoreTuning;
  final int tickHz;
  final LeaderboardStore? leaderboardStore;

  @override
  State<LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<LeaderboardPanel> {
  late final LeaderboardStore _store;
  List<RunResult> _entries = const <RunResult>[];
  int? _currentRunId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _store = widget.leaderboardStore ?? SharedPrefsLeaderboardStore();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final event = widget.runEndedEvent;
    if (event == null) {
      final entries = await _store.loadTop10();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loaded = true;
      });
      return;
    }

    final draft = buildRunResult(
      event: event,
      scoreTuning: widget.scoreTuning,
      tickHz: widget.tickHz,
      endedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final snapshot = await _store.addResult(draft);
    if (!mounted) return;
    setState(() {
      _entries = snapshot.entries;
      _currentRunId = snapshot.current.runId;
      _loaded = true;
    });
  }

  Widget _buildRow(int rank, RunResult entry) {
    final isCurrent = _currentRunId != null && entry.runId == _currentRunId;
    final color = isCurrent ? const Color(0xFFFFF59D) : const Color(0xFFFFFFFF);

    return DecoratedBox(
      decoration: isCurrent
          ? BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(6),
            )
          : const BoxDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '#$rank',
                style: TextStyle(color: color),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                entry.score.toString(),
                textAlign: TextAlign.right,
                style: TextStyle(color: color),
              ),
            ),
            const SizedBox(width: 8),
            Text('${entry.distanceMeters}m', style: TextStyle(color: color)),
            const SizedBox(width: 8),
            Text(
              _formatTime(entry.durationSeconds),
              style: TextStyle(color: color),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = const TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final textStyle = const TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

    Widget content;
    if (!_loaded) {
      content = Text('Loading leaderboard...', style: textStyle);
    } else if (_entries.isEmpty) {
      content = Text('No runs yet.', style: textStyle);
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _entries.length; i += 1) ...[
            _buildRow(i + 1, _entries[i]),
            if (i < _entries.length - 1) const SizedBox(height: 4),
          ],
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x66000000),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leaderboard', style: titleStyle),
              const SizedBox(height: 8),
              DefaultTextStyle(style: textStyle, child: content),
            ],
          ),
        ),
      ),
    );
  }
}
