import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/ui_routes.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../components/play_button.dart';
import '../../levels/level_id_ui.dart';
import 'components/weekly_badge_row.dart';
import 'components/hub_menu_icon_column.dart';
import 'components/hub_select_character_card.dart';
import 'components/hub_select_level_card.dart';
import 'components/hub_top_row.dart';
import '../../state/app_state.dart';
import '../../state/progression_state.dart';
import '../../state/selection_state.dart';
import '../../theme/ui_tokens.dart';

class PlayHubPage extends StatefulWidget {
  const PlayHubPage({super.key});

  @override
  State<PlayHubPage> createState() => _PlayHubPageState();
}

class _PlayHubPageState extends State<PlayHubPage> {
  bool _preparingRunStart = false;
  _RunStartSource? _runStartSource;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().startWarmup();
    });
  }

  Future<void> _startRun(
    {
    _RunStartSource source = _RunStartSource.main,
  }) async {
    if (_preparingRunStart) return;
    setState(() {
      _preparingRunStart = true;
      _runStartSource = source;
    });
    try {
      if (!mounted) return;
      await Navigator.of(
        context,
      ).pushNamed(
        UiRoutes.runBootstrap,
        arguments: const RunStartBootstrapArgs(),
      );
    } catch (error) {
      debugPrint('Run start preparation failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to navigate to run start right now. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _preparingRunStart = false;
          _runStartSource = null;
        });
      }
    }
  }

  Future<void> _startWeeklyRun(AppState appState) async {
    if (_preparingRunStart) return;
    if (appState.selection.selectedRunMode != RunMode.weekly) {
      await appState.setRunMode(RunMode.weekly);
    }
    if (!mounted) return;
    await _startRun(source: _RunStartSource.weekly);
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final appState = context.watch<AppState>();
    final progression = appState.progression;
    final selection = appState.selection;
    final profile = appState.profile;
    final gold = appState.displayGold;

    return MenuScaffold(
      showAppBar: false,
      child: MenuLayout(
        horizontalPadding: ui.space.lg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            HubMenuIconColumn(
              onCodexPressed: () =>
                  Navigator.of(context).pushNamed(UiRoutes.library),
              onTownPressed: () =>
                  Navigator.of(context).pushNamed(UiRoutes.town),
              onProfilePressed: () =>
                  Navigator.of(context).pushNamed(UiRoutes.profile),
              onLeaderboardsPressed: () =>
                  Navigator.of(context).pushNamed(UiRoutes.leaderboards),
              onMessagesPressed: () =>
                  Navigator.of(context).pushNamed(UiRoutes.messages),
              onSupportPressed: () =>
                  Navigator.of(context).pushNamed(UiRoutes.support),
              onOptionsPressed: () =>
                  Navigator.of(context).pushNamed(UiRoutes.options),
            ),
            SizedBox(width: ui.space.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HubTopRow(
                    displayName: profile.displayName.isEmpty
                        ? 'Guest'
                        : profile.displayName,
                    gold: gold,
                  ),
                  SizedBox(height: ui.space.sm),
                  WeeklyBadgeRow(
                    title: _weeklyBadgeTitle(progression, appState),
                    isWeeklyLoading:
                      _preparingRunStart &&
                      _runStartSource == _RunStartSource.weekly,
                    onWeeklyPressed: _preparingRunStart
                      ? null
                      : () => _startWeeklyRun(appState),
                    onWeeklyLeaderboardPressed: () =>
                        Navigator.of(context).pushNamed(UiRoutes.leaderboards),
                  ),
                  SizedBox(height: ui.space.lg),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: ui.space.md,
                      runSpacing: ui.space.md,
                      children: [
                        HubSelectedLevelCard(
                          levelId: selection.selectedLevelId,
                          runModeLabel: _runModeLabel(
                            selection.selectedRunMode,
                          ),
                          onChange: () => Navigator.of(
                            context,
                          ).pushNamed(UiRoutes.setupLevel),
                        ),
                        HubSelectCharacterCard(
                          characterId: selection.selectedCharacterId,
                          buildName: selection.buildName,
                          onChange: () => Navigator.of(
                            context,
                          ).pushNamed(UiRoutes.setupLoadout),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: ui.space.lg),
                  Center(
                    child: PlayButton(
                      isLoading:
                          _preparingRunStart &&
                          _runStartSource == _RunStartSource.main,
                      onPressed: _preparingRunStart
                          ? null
                          : () => _startRun(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RunStartSource { main, weekly }

String _runModeLabel(RunMode runMode) {
  switch (runMode) {
    case RunMode.practice:
      return 'PRACTICE';
    case RunMode.competitive:
      return 'COMPETITIVE';
    case RunMode.weekly:
      return 'WEEKLY';
  }
}

String _weeklyBadgeTitle(ProgressionState progression,AppState appState) {
  final weeklyLevelName = appState.weeklyFeaturedLevelId.displayName
      .toUpperCase();
  final weekly = progression.weekly;
  return 'WEEKLY ${weekly.currentWindowId} • $weeklyLevelName';
}
