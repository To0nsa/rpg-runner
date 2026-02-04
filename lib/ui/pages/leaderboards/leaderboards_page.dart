import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/levels/level_id.dart';
import '../../components/app_segmented_control.dart';
import '../../components/leaderboard_table.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../leaderboard/run_result.dart';
import '../../leaderboard/shared_prefs_leaderboard_store.dart';
import '../../levels/level_id_ui.dart';
import '../../state/app_state.dart';
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
  late LevelId _weeklyLevelId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;

    final selection = context.read<AppState>().selection;
    _runFilter = switch (selection.selectedRunType) {
      RunType.practice => LeaderboardsRunFilter.practice,
      RunType.competitive => LeaderboardsRunFilter.competitive,
    };
    _initialTabIndex = _levelIndexOf(selection.selectedLevelId);
    // Weekly is a single leaderboard scope (one level). For now, we default it
    // to the user's currently selected level.
    _weeklyLevelId = selection.selectedLevelId;
    _seeded = true;
  }

  RunType? _toRunType(LeaderboardsRunFilter filter) => switch (filter) {
    LeaderboardsRunFilter.practice => RunType.practice,
    LeaderboardsRunFilter.competitive => RunType.competitive,
    LeaderboardsRunFilter.weekly => null,
  };

  int _levelIndexOf(LevelId levelId) {
    final index = LevelId.values.indexOf(levelId);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final runType = _toRunType(_runFilter);
    final isWeekly = runType == null;

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
        LeaderboardsRunFilter.practice => const Text('Practice (Random)'),
        LeaderboardsRunFilter.competitive => const Text('Competitive (Season)'),
        LeaderboardsRunFilter.weekly => const Text('Weekly'),
      },
    );

    return MenuScaffold(
      appBarTitle: segmented,
      centerAppBarTitle: true,
      child: MenuLayout(
        scrollable: false,
        child: isWeekly
            ? _WeeklyLeaderboardPlaceholder(levelId: _weeklyLevelId)
            : _PerLevelLeaderboards(
                store: _store,
                runType: runType,
                initialIndex: _initialTabIndex,
              ),
      ),
    );
  }
}

class _PerLevelLeaderboards extends StatelessWidget {
  const _PerLevelLeaderboards({
    required this.store,
    required this.runType,
    required this.initialIndex,
  });

  final SharedPrefsLeaderboardStore store;
  final RunType runType;
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
                    key: ValueKey('${levelId.name}-${runType.name}'),
                    store: store,
                    levelId: levelId,
                    runType: runType,
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
    required this.runType,
  });

  final SharedPrefsLeaderboardStore store;
  final LevelId levelId;
  final RunType runType;

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
        oldWidget.runType == widget.runType) {
      return;
    }
    _future = _load();
  }

  Future<List<RunResult>> _load() {
    return widget.store.loadTop10(
      levelId: widget.levelId,
      runType: widget.runType,
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

class _WeeklyLeaderboardPlaceholder extends StatelessWidget {
  const _WeeklyLeaderboardPlaceholder({required this.levelId});

  final LevelId levelId;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Text(
          '${levelId.displayName} weekly leaderboard is coming soon.',
          style: ui.text.body,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
