import 'package:flutter/material.dart';

import '../leaderboard/run_result.dart';
import '../theme/ui_leaderboard_theme.dart';
import '../theme/ui_tokens.dart';

class LeaderboardTable extends StatelessWidget {
  const LeaderboardTable({
    super.key,
    required this.entries,
    this.highlightRunId,
    this.hideScoreForRunId,
    this.showHeader = true,
    this.inset = true,
    this.scrollable = false,
  });

  final List<RunResult> entries;
  final int? highlightRunId;
  final int? hideScoreForRunId;
  final bool showHeader;
  final bool inset;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final spec = context.leaderboards.resolveSpec(ui: ui);

    final children = <Widget>[];
    if (showHeader) {
      children.add(_LeaderboardHeaderRow(spec: spec));
      if (spec.headerGap > 0) {
        children.add(SizedBox(height: spec.headerGap));
      }
    }

    for (var i = 0; i < entries.length; i += 1) {
      final entry = entries[i];
      final rank = i + 1;
      children.add(
        _LeaderboardRow(
          spec: spec,
          rank: rank,
          entry: entry,
          highlight: highlightRunId != null && entry.runId == highlightRunId,
          hideScore:
              hideScoreForRunId != null && entry.runId == hideScoreForRunId,
        ),
      );
      if (i < entries.length - 1) {
        if (spec.rowGap > 0) {
          children.add(SizedBox(height: spec.rowGap));
        }
      }
    }

    final padding = inset ? spec.tablePadding : EdgeInsets.zero;
    final table = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    if (!scrollable) return table;
    return SingleChildScrollView(child: table);
  }
}

class _LeaderboardHeaderRow extends StatelessWidget {
  const _LeaderboardHeaderRow({required this.spec});

  final UiLeaderboardSpec spec;

  @override
  Widget build(BuildContext context) {
    final style = spec.headerTextStyle;

    Widget cell(String text, UiLeaderboardColumn column, TextAlign align) {
      return _LeaderboardColumnCell(
        column: column,
        child: Text(text, style: style, textAlign: align),
      );
    }

    final row = Row(
      children: [
        cell('#Rank', spec.columns.rank, TextAlign.left),
        cell('Score', spec.columns.score, TextAlign.right),
        cell('Distance', spec.columns.distance, TextAlign.right),
        cell('Time', spec.columns.time, TextAlign.right),
      ],
    );

    return SizedBox(
      height: spec.headerHeight,
      child: Center(child: row),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.spec,
    required this.rank,
    required this.entry,
    required this.highlight,
    required this.hideScore,
  });

  final UiLeaderboardSpec spec;
  final int rank;
  final RunResult entry;
  final bool highlight;
  final bool hideScore;

  @override
  Widget build(BuildContext context) {
    final textColor = highlight
        ? spec.highlightTextColor
        : spec.rowTextStyle.color;
    final style = spec.rowTextStyle.copyWith(color: textColor);

    final decoration = BoxDecoration(
      color: highlight ? spec.highlightBackground : spec.rowBackground,
      borderRadius: BorderRadius.circular(spec.rowRadius),
      border: Border.all(
        color: highlight ? spec.highlightBorderColor : spec.rowBorderColor,
        width: spec.rowBorderWidth,
      ),
    );

    final row = Row(
      children: [
        _LeaderboardColumnCell(
          column: spec.columns.rank,
          child: Text('#$rank', style: style),
        ),
        _LeaderboardColumnCell(
          column: spec.columns.score,
          child: Text(
            hideScore ? '—' : entry.score.toString(),
            style: style,
            textAlign: TextAlign.right,
          ),
        ),
        _LeaderboardColumnCell(
          column: spec.columns.distance,
          child: Text(
            '${entry.distanceMeters}m',
            style: style,
            textAlign: TextAlign.right,
          ),
        ),
        _LeaderboardColumnCell(
          column: spec.columns.time,
          child: Text(
            _formatTime(entry.durationSeconds),
            style: style,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );

    final padded = Padding(padding: spec.rowPadding, child: row);
    final body = SizedBox(
      height: spec.rowHeight,
      child: Center(child: padded),
    );

    return DecoratedBox(decoration: decoration, child: body);
  }
}

String _formatTime(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class _LeaderboardColumnCell extends StatelessWidget {
  const _LeaderboardColumnCell({required this.column, required this.child});

  final UiLeaderboardColumn column;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = column.width;
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: column.flex, child: child);
  }
}
