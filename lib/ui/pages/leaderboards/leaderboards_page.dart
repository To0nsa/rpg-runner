import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/events/game_event.dart';

import 'package:runner_core/levels/level_id.dart';
import 'package:run_protocol/leaderboard_entry.dart';
import '../../app/ui_routes.dart';
import '../../components/app_segmented_control.dart';
import '../../components/leaderboard_table.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../leaderboard/run_result.dart';
import '../../leaderboard/shared_prefs_leaderboard_store.dart';
import '../../levels/level_id_ui.dart';
import '../../state/app_state.dart';
import '../../state/leaderboard_api.dart';
import '../../state/run_start_remote_exception.dart';
import '../../state/selection_state.dart';
import '../../theme/ui_tokens.dart';

enum LeaderboardsRunFilter { practice, competitive, weekly }

class LeaderboardsPage extends StatefulWidget {
  const LeaderboardsPage({super.key});

  @override
  State<LeaderboardsPage> createState() => _LeaderboardsPageState();
}

class _LeaderboardsPageState extends State<LeaderboardsPage> {
  final _store = SharedPrefsLeaderboardStore();
  bool _seeded = false;

  late LeaderboardsRunFilter _runFilter;
  late int _initialTabIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;

    final selection = context.read<AppState>().selection;
    _runFilter = switch (selection.selectedRunMode) {
      RunMode.practice => LeaderboardsRunFilter.practice,
      RunMode.competitive => LeaderboardsRunFilter.competitive,
      RunMode.weekly => LeaderboardsRunFilter.weekly,
    };
    _initialTabIndex = _levelIndexOf(selection.selectedLevelId);
    _seeded = true;
  }

  int _levelIndexOf(LevelId levelId) {
    final index = LevelId.values.indexOf(levelId);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final weeklyFeaturedLevelId = context
        .read<AppState>()
        .weeklyFeaturedLevelId;
    final segmented = AppSegmentedControl<LeaderboardsRunFilter>(
      values: const [
        LeaderboardsRunFilter.practice,
        LeaderboardsRunFilter.competitive,
        LeaderboardsRunFilter.weekly,
      ],
      selected: _runFilter,
      size: AppSegmentedControlSize.sm,
      onChanged: (value) => setState(() => _runFilter = value),
      labelBuilder: (context, value) => switch (value) {
        LeaderboardsRunFilter.practice => const Text('PRACTICE'),
        LeaderboardsRunFilter.competitive => const Text('COMPETITIVE'),
        LeaderboardsRunFilter.weekly => const Text('WEEKLY'),
      },
    );

    return MenuScaffold(
      appBarTitle: segmented,
      centerAppBarTitle: true,
      child: MenuLayout(
        scrollable: false,
        child: switch (_runFilter) {
          LeaderboardsRunFilter.practice => _PerLevelLeaderboards(
            store: _store,
            runMode: RunMode.practice,
            initialIndex: _initialTabIndex,
          ),
          LeaderboardsRunFilter.competitive => _OnlinePerLevelLeaderboards(
            runMode: RunMode.competitive,
            initialIndex: _initialTabIndex,
          ),
          LeaderboardsRunFilter.weekly => _OnlineSingleLevelLeaderboard(
            runMode: RunMode.weekly,
            levelId: weeklyFeaturedLevelId,
          ),
        },
      ),
    );
  }
}

class _PerLevelLeaderboards extends StatelessWidget {
  const _PerLevelLeaderboards({
    required this.store,
    required this.runMode,
    required this.initialIndex,
  });

  final SharedPrefsLeaderboardStore store;
  final RunMode runMode;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final levels = LevelId.values;

    return DefaultTabController(
      length: levels.length,
      initialIndex: initialIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            isScrollable: true,
            labelColor: ui.colors.textPrimary,
            unselectedLabelColor: ui.colors.textMuted,
            labelStyle: ui.text.label,
            indicatorColor: ui.colors.accent,
            tabs: [
              for (final levelId in levels)
                Tab(text: levelId.displayName.toUpperCase()),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final levelId in levels)
                  _LeaderboardList(
                    key: ValueKey('${levelId.name}-${runMode.name}'),
                    store: store,
                    levelId: levelId,
                    runMode: runMode,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardList extends StatefulWidget {
  const _LeaderboardList({
    super.key,
    required this.store,
    required this.levelId,
    required this.runMode,
  });

  final SharedPrefsLeaderboardStore store;
  final LevelId levelId;
  final RunMode runMode;

  @override
  State<_LeaderboardList> createState() => _LeaderboardListState();
}

class _LeaderboardListState extends State<_LeaderboardList> {
  late Future<List<RunResult>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _LeaderboardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.levelId == widget.levelId &&
        oldWidget.runMode == widget.runMode) {
      return;
    }
    _future = _load();
  }

  Future<List<RunResult>> _load() {
    return widget.store.loadTop10(
      levelId: widget.levelId,
      runMode: widget.runMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;

    return FutureBuilder<List<RunResult>>(
      future: _future,
      builder: (context, snapshot) {
        final entries = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: Text('Loading...', style: ui.text.body));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load leaderboard.', style: ui.text.body),
          );
        }

        if (entries == null || entries.isEmpty) {
          return Center(child: Text('No runs yet.', style: ui.text.body));
        }

        return LeaderboardTable(entries: entries, scrollable: true);
      },
    );
  }
}

class _OnlinePerLevelLeaderboards extends StatelessWidget {
  const _OnlinePerLevelLeaderboards({
    required this.runMode,
    required this.initialIndex,
  });

  final RunMode runMode;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final levels = LevelId.values;
    return DefaultTabController(
      length: levels.length,
      initialIndex: initialIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            isScrollable: true,
            labelColor: ui.colors.textPrimary,
            unselectedLabelColor: ui.colors.textMuted,
            labelStyle: ui.text.label,
            indicatorColor: ui.colors.accent,
            tabs: [
              for (final levelId in levels)
                Tab(text: levelId.displayName.toUpperCase()),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final levelId in levels)
                  _OnlineLeaderboardList(
                    key: ValueKey('${runMode.name}-${levelId.name}'),
                    runMode: runMode,
                    levelId: levelId,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineSingleLevelLeaderboard extends StatelessWidget {
  const _OnlineSingleLevelLeaderboard({
    required this.runMode,
    required this.levelId,
  });

  final RunMode runMode;
  final LevelId levelId;

  @override
  Widget build(BuildContext context) {
    return _OnlineLeaderboardList(
      key: ValueKey('${runMode.name}-${levelId.name}'),
      runMode: runMode,
      levelId: levelId,
    );
  }
}

class _OnlineLeaderboardList extends StatefulWidget {
  const _OnlineLeaderboardList({
    super.key,
    required this.runMode,
    required this.levelId,
  });

  final RunMode runMode;
  final LevelId levelId;

  @override
  State<_OnlineLeaderboardList> createState() => _OnlineLeaderboardListState();
}

class _OnlineLeaderboardListState extends State<_OnlineLeaderboardList> {
  late Future<_OnlineLeaderboardData> _future;
  String? _startingGhostEntryId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _OnlineLeaderboardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runMode == widget.runMode &&
        oldWidget.levelId == widget.levelId) {
      return;
    }
    _future = _load();
  }

  Future<_OnlineLeaderboardData> _load() async {
    final appState = context.read<AppState>();
    final data = await appState.loadOnlineLeaderboardData(
      mode: widget.runMode,
      levelId: widget.levelId,
    );
    return _OnlineLeaderboardData(board: data.board, myRank: data.myRank);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _startGhostRun(LeaderboardEntry entry) async {
    if (_startingGhostEntryId != null) {
      return;
    }
    final entryId = entry.entryId.trim();
    if (!entry.ghostEligible || entryId.isEmpty) {
      return;
    }
    setState(() => _startingGhostEntryId = entryId);
    final appState = context.read<AppState>();
    try {
      if (appState.selection.selectedRunMode != widget.runMode) {
        await appState.setRunMode(widget.runMode);
      }
      if (!mounted) {
        return;
      }
      if (appState.selection.selectedLevelId != widget.levelId) {
        await appState.setLevel(widget.levelId);
      }
      if (!mounted) {
        return;
      }
      final descriptor = await appState.prepareRunStartDescriptor(
        ghostEntryId: entryId,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(
        context,
      ).pushNamed(UiRoutes.run, arguments: descriptor);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = switch (error) {
        RunStartRemoteException exception when exception.message != null =>
          exception.message!,
        RunStartRemoteException exception when exception.isPreconditionFailed =>
          'Ghost run cannot start for this board entry right now.',
        _ =>
          'Unable to start ghost run right now. Check your connection and try again.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _startingGhostEntryId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return FutureBuilder<_OnlineLeaderboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Loading online leaderboard.', style: ui.text.body),
                SizedBox(height: ui.space.sm),
                SizedBox(
                  width: ui.sizes.iconSize.md,
                  height: ui.sizes.iconSize.md,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ui.colors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _onlineErrorMessage(snapshot.error),
                    style: ui.text.body,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ui.space.sm),
                  OutlinedButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return Center(
            child: Text('No leaderboard data.', style: ui.text.body),
          );
        }

        final topEntries = data.board.topEntries;
        final entries = _toRunResults(topEntries);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: ui.space.sm),
            Text(
              '${widget.levelId.displayName.toUpperCase()} ${widget.runMode.name.toUpperCase()} BOARD',
              style: ui.text.body.copyWith(
                color: ui.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            _MyRankLabel(myRank: data.myRank),
            SizedBox(height: ui.space.sm),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'No validated runs yet.',
                        style: ui.text.body,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : LeaderboardTable(
                      entries: entries,
                      scrollable: true,
                      trailingHeaderLabel: 'VS Ghost',
                      trailingBuilder: (context, rank, _) {
                        final source = topEntries[rank - 1];
                        final sourceEntryId = source.entryId.trim();
                        final isStarting =
                            _startingGhostEntryId != null &&
                            _startingGhostEntryId == sourceEntryId;
                        final enabled =
                            _startingGhostEntryId == null &&
                            source.ghostEligible &&
                            sourceEntryId.isNotEmpty;
                        if (isStarting) {
                          return SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ui.colors.textPrimary,
                            ),
                          );
                        }
                        return IconButton(
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          tooltip: source.ghostEligible
                              ? 'Race this ghost.'
                              : 'Ghost unavailable for this run.',
                          onPressed: enabled
                              ? () => unawaited(_startGhostRun(source))
                              : null,
                          icon: const Icon(Icons.play_arrow_rounded),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _OnlineLeaderboardData {
  const _OnlineLeaderboardData({required this.board, required this.myRank});

  final OnlineLeaderboardBoard board;
  final OnlineLeaderboardMyRank myRank;
}

class _MyRankLabel extends StatelessWidget {
  const _MyRankLabel({required this.myRank});

  final OnlineLeaderboardMyRank myRank;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final baseStyle = ui.text.body.copyWith(color: ui.colors.textMuted);
    final rank = myRank.rank;

    if (rank == null) {
      final label = myRank.totalPlayers <= 0
          ? 'No ranked players yet.'
          : 'You are not ranked on this board yet.';
      return Text(label, style: baseStyle, textAlign: TextAlign.center);
    }

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Your rank: '),
          TextSpan(
            text: '#$rank',
            style: baseStyle.copyWith(
              color: ui.colors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: ' / ${myRank.totalPlayers}'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

List<RunResult> _toRunResults(List<LeaderboardEntry> entries) {
  return List<RunResult>.generate(entries.length, (index) {
    final entry = entries[index];
    return RunResult(
      runId: index + 1,
      endedAtMs: entry.updatedAtMs,
      endedReason: RunEndReason.playerDied,
      score: entry.score,
      distanceMeters: entry.distanceMeters,
      durationSeconds: entry.durationSeconds,
      tick: entry.durationSeconds * 60,
      displayName: entry.displayName,
    );
  }, growable: false);
}

String _onlineErrorMessage(Object? error) {
  if (error is RunStartRemoteException) {
    if (error.code == 'not-found') {
      return 'No active leaderboard board for this mode and level.';
    }
    if (error.code == 'failed-precondition') {
      return error.message ?? 'Leaderboard board is not available right now.';
    }
    return error.message ?? 'Failed to load online leaderboard.';
  }
  return 'Failed to load online leaderboard.';
}
