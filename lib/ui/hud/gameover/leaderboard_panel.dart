import 'package:flutter/material.dart';

import '../../../core/events/game_event.dart';
import '../../../core/levels/level_id.dart';
import '../../../core/tuning/score_tuning.dart';
import '../../leaderboard/leaderboard_store.dart';
import '../../leaderboard/run_result.dart';
import '../../leaderboard/shared_prefs_leaderboard_store.dart';
import '../../levels/level_id_ui.dart';

class LeaderboardPanel extends StatefulWidget {
  const LeaderboardPanel({
    super.key,
    required this.levelId,
    required this.runEndedEvent,
    required this.scoreTuning,
    required this.tickHz,
    this.revealCurrentRunScore = true,
    this.leaderboardStore,
  });

  final LevelId levelId;
  final RunEndedEvent? runEndedEvent;
  final ScoreTuning scoreTuning;
  final int tickHz;
  final bool revealCurrentRunScore;
  final LeaderboardStore? leaderboardStore;

  @override
  State<LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<LeaderboardPanel> {
  late final LeaderboardStore _store;
  List<RunResult> _entries = const <RunResult>[];
  int? _currentRunId;
  bool _loaded = false;

  static const double _rankColWidth = 28;
  static const double _scoreColWidth = 64;
  static const double _distanceColWidth = 56;
  static const double _timeColWidth = 54;

  @override
  void initState() {
    super.initState();
    _store = widget.leaderboardStore ?? SharedPrefsLeaderboardStore();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final event = widget.runEndedEvent;
    if (event == null) {
      final entries = await _store.loadTop10(levelId: widget.levelId);
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
    final snapshot = await _store.addResult(
      levelId: widget.levelId,
      result: draft,
    );
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
    final scoreText =
        isCurrent && !widget.revealCurrentRunScore ? '—' : entry.score.toString();

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
              width: _rankColWidth,
              child: Text(
                '#$rank',
                style: TextStyle(color: color),
              ),
            ),
            SizedBox(
              width: _scoreColWidth,
              child: Text(
                scoreText,
                textAlign: TextAlign.right,
                style: TextStyle(color: color),
              ),
            ),
            SizedBox(
              width: _distanceColWidth,
              child: Text(
                '${entry.distanceMeters}m',
                textAlign: TextAlign.right,
                style: TextStyle(color: color),
              ),
            ),
            SizedBox(
              width: _timeColWidth,
              child: Text(
                _formatTime(entry.durationSeconds),
                textAlign: TextAlign.right,
                style: TextStyle(color: color),
              ),
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
              Text('${widget.levelId.displayName} Scoreboard', style: titleStyle),
              const SizedBox(height: 8),
              DefaultTextStyle(style: textStyle, child: content),
            ],
          ),
        ),
      ),
    );
  }
}
