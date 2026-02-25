import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/events/game_event.dart';
import '../../../core/levels/level_id.dart';
import '../../../core/tuning/score_tuning.dart';
import '../../components/leaderboard_table.dart';
import '../../leaderboard/leaderboard_store.dart';
import '../../leaderboard/run_result.dart';
import '../../leaderboard/shared_prefs_leaderboard_store.dart';
import '../../levels/level_id_ui.dart';
import '../../state/selection_state.dart';
import '../../theme/ui_leaderboard_theme.dart';
import '../../theme/ui_tokens.dart';

class LeaderboardPanel extends StatefulWidget {
  const LeaderboardPanel({
    super.key,
    required this.levelId,
    required this.runType,
    required this.runEndedEvent,
    required this.scoreTuning,
    required this.tickHz,
    this.revealCurrentRunScore = true,
    this.leaderboardStore,
  });

  final LevelId levelId;
  final RunType runType;
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

  @override
  void initState() {
    super.initState();
    _store = widget.leaderboardStore ?? SharedPrefsLeaderboardStore();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final event = widget.runEndedEvent;
    if (event == null) {
      final entries = await _store.loadTop10(
        levelId: widget.levelId,
        runType: widget.runType,
      );
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
      runType: widget.runType,
      result: draft,
    );
    if (!mounted) return;
    setState(() {
      _entries = snapshot.entries;
      _currentRunId = snapshot.current.runId;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final runTypeLabel = switch (widget.runType) {
      RunType.practice => 'Practice',
      RunType.competitive => 'Competitive',
    };
    final titleStyle = ui.text.body.copyWith(
      color: ui.colors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final spec = context.leaderboards.resolveSpec(ui: ui);
    final textStyle = spec.rowTextStyle;

    Widget content;
    if (!_loaded) {
      content = const Center(child: Text('Loading leaderboard...'));
    } else if (_entries.isEmpty) {
      content = const Center(child: Text('No runs yet.'));
    } else {
      content = LeaderboardTable(
        entries: _entries,
        highlightRunId: _currentRunId,
        hideScoreForRunId: widget.revealCurrentRunScore ? null : _currentRunId,
        inset: false,
        scrollable: true,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final height = maxHeight.isFinite ? math.min(maxHeight, 360.0) : null;

        final styledContent = DefaultTextStyle(
          style: textStyle,
          child: content,
        );

        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.levelId.displayName} $runTypeLabel Scoreboard',
              style: titleStyle,
            ),
            SizedBox(height: ui.space.xs),
            if (height == null)
              styledContent
            else
              Expanded(child: styledContent),
          ],
        );

        final panel = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ui.colors.shadow.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(ui.radii.sm),
            ),
            child: Padding(padding: EdgeInsets.all(ui.space.sm), child: body),
          ),
        );

        if (height == null) return panel;
        return SizedBox(height: height, child: panel);
      },
    );
  }
}
