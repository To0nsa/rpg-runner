import '../text/number_format.dart';

import 'package:game_presentation/game_localization.dart';
import 'package:game_presentation/character_text.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:runner_core/players/player_character_registry.dart';

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
    this.showPlayerLevelColumn = false,
    this.trailingHeaderLabel,
    this.trailingBuilder,
    this.trailingColumnWidth = 84,
  });

  final List<RunResult> entries;
  final int? highlightRunId;
  final int? hideScoreForRunId;
  final bool showHeader;
  final bool inset;
  final bool scrollable;
  final bool showPlayerLevelColumn;
  final String? trailingHeaderLabel;
  final Widget Function(BuildContext context, int rank, RunResult entry)?
  trailingBuilder;
  final double trailingColumnWidth;

  bool get _showDisplayNameColumn =>
      entries.any((entry) => (entry.displayName ?? '').trim().isNotEmpty);

  bool get _showPlayerLevelColumn =>
      _showDisplayNameColumn && showPlayerLevelColumn;

  bool get _showCharacterColumn =>
      entries.any((entry) => entry.characterId != null);

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final spec = context.leaderboards.resolveSpec(ui: ui);

    final children = <Widget>[];
    if (showHeader) {
      children.add(
        _LeaderboardHeaderRow(
          spec: spec,
          showDisplayNameColumn: _showDisplayNameColumn,
          showPlayerLevelColumn: _showPlayerLevelColumn,
          showCharacterColumn: _showCharacterColumn,
          trailingHeaderLabel: trailingHeaderLabel,
          trailingColumnWidth: trailingColumnWidth,
        ),
      );
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
          showDisplayNameColumn: _showDisplayNameColumn,
          showPlayerLevelColumn: _showPlayerLevelColumn,
          showCharacterColumn: _showCharacterColumn,
          trailingChild: trailingBuilder?.call(context, rank, entry),
          trailingColumnWidth: trailingColumnWidth,
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
  const _LeaderboardHeaderRow({
    required this.spec,
    required this.showDisplayNameColumn,
    required this.showPlayerLevelColumn,
    required this.showCharacterColumn,
    required this.trailingHeaderLabel,
    required this.trailingColumnWidth,
  });

  final UiLeaderboardSpec spec;
  final bool showDisplayNameColumn;
  final bool showPlayerLevelColumn;
  final bool showCharacterColumn;
  final String? trailingHeaderLabel;
  final double trailingColumnWidth;

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
        cell(context.l10n.uiRank, spec.columns.rank, TextAlign.left),
        if (showDisplayNameColumn)
          SizedBox(
            width: showPlayerLevelColumn
                ? _playerNameColumnWidthWithLevel
                : _playerNameColumnWidth,
            child: Text(
              context.l10n.uiName,
              style: style,
              textAlign: TextAlign.left,
            ),
          ),
        if (showPlayerLevelColumn)
          SizedBox(
            width: _playerLevelColumnWidth,
            child: Text(
              context.l10n.uiLvl,
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
        if (showCharacterColumn)
          SizedBox(
            width: _characterColumnWidth,
            child: Text(
              context.l10n.uiCharacter,
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
        cell(context.l10n.uiScore, spec.columns.score, TextAlign.right),
        cell(context.l10n.uiDistance, spec.columns.distance, TextAlign.right),
        cell(context.l10n.uiTime, spec.columns.time, TextAlign.right),
        if (trailingHeaderLabel != null)
          SizedBox(
            width: trailingColumnWidth,
            child: Text(
              trailingHeaderLabel!,
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );

    return SizedBox(
      height: spec.headerHeight,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(
            left: spec.rowPadding.left,
            right: spec.rowPadding.right,
          ),
          child: row,
        ),
      ),
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
    required this.showDisplayNameColumn,
    required this.showPlayerLevelColumn,
    required this.showCharacterColumn,
    required this.trailingChild,
    required this.trailingColumnWidth,
  });

  final UiLeaderboardSpec spec;
  final int rank;
  final RunResult entry;
  final bool highlight;
  final bool hideScore;
  final bool showDisplayNameColumn;
  final bool showPlayerLevelColumn;
  final bool showCharacterColumn;
  final Widget? trailingChild;
  final double trailingColumnWidth;

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
        if (showDisplayNameColumn)
          SizedBox(
            width: showPlayerLevelColumn
                ? _playerNameColumnWidthWithLevel
                : _playerNameColumnWidth,
            child: Text(
              (entry.displayName ?? '').trim().isEmpty
                  ? context.l10n.uiUnknown
                  : entry.displayName!.trim(),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
        if (showPlayerLevelColumn)
          SizedBox(
            width: _playerLevelColumnWidth,
            child: Text(
              entry.playerLevel == null
                  ? '—'
                  : formatCount(entry.playerLevel!, l10n: context.l10n),
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
        if (showCharacterColumn)
          SizedBox(
            width: _characterColumnWidth,
            child: Text(
              _characterName(entry.characterId, context.gameL10n),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        _LeaderboardColumnCell(
          column: spec.columns.score,
          child: Text(
            hideScore ? '—' : formatCount(entry.score, l10n: context.l10n),
            style: style,
            textAlign: TextAlign.right,
          ),
        ),
        _LeaderboardColumnCell(
          column: spec.columns.distance,
          child: Text(
            context.l10n.shortDistance(meters: entry.distanceMeters),
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
        if (trailingChild != null)
          SizedBox(
            width: trailingColumnWidth,
            child: Center(child: trailingChild),
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

const double _playerNameColumnWidth = 132;
const double _playerNameColumnWidthWithLevel = 104;
const double _playerLevelColumnWidth = 32;
const double _characterColumnWidth = 80;

String _characterName(String? characterId, GameLocalizations strings) {
  for (final character in PlayerCharacterRegistry.all) {
    if (character.id.name == characterId) {
      return characterDisplayName(character.id, strings: strings);
    }
  }
  return '—';
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
