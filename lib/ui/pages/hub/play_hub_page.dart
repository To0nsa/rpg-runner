import '../../campaign/campaign_catalog.dart';
import '../../campaign/campaign_map.dart';
import 'components/hub_select_card_frame.dart';
import 'components/hub_select_card_body.dart';
import '../../text/build_name_text.dart';

import 'package:rpg_runner/ui/l10n/app_localization.dart';
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
import '../../state/app/app_state.dart';
import '../../state/ownership/progression_state.dart';
import '../../state/ownership/selection_state.dart';
import '../../theme/ui_tokens.dart';

class PlayHubPage extends StatefulWidget {
  const PlayHubPage({super.key});

  @override
  State<PlayHubPage> createState() => _PlayHubPageState();
}

class _PlayHubPageState extends State<PlayHubPage> {
  bool _preparingRunStart = false;
  _RunStartSource? _runStartSource;
  bool? _wasCurrentRoute;
  int? _xpBeforeRun;
  int? _animateXpFrom;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isCurrent = ModalRoute.isCurrentOf(context);
    if (_wasCurrentRoute == false &&
        isCurrent == true &&
        _xpBeforeRun != null) {
      _animateXpFrom = _xpBeforeRun;
      _xpBeforeRun = null;
    }
    _wasCurrentRoute = isCurrent;
  }

  Future<void> _startRun({
    _RunStartSource source = _RunStartSource.main,
  }) async {
    if (_preparingRunStart) return;
    _xpBeforeRun = context.read<AppState>().displayedPlayerProgress.totalXp;
    setState(() {
      _preparingRunStart = true;
      _runStartSource = source;
      _animateXpFrom = null;
    });
    try {
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        UiRoutes.runBootstrap,
        arguments: const RunStartBootstrapArgs(),
      );
    } catch (error) {
      debugPrint('Run start preparation failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.uiUnableToNavigateToRunStartRightNowTryAgain,
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
    final gold = appState.displayedGold;

    return MenuScaffold(
      showAppBar: false,
      child: MenuLayout(
        maxWidth: double.infinity,
        horizontalPadding: ui.space.lg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            HubMenuIconColumn(
              onTownPressed: appState.isDeveloperMode
                  ? null
                  : () => Navigator.of(context).pushNamed(UiRoutes.town),
              onProfilePressed: appState.isDeveloperMode
                  ? null
                  : () => Navigator.of(context).pushNamed(UiRoutes.profile),
              onLeaderboardsPressed: appState.isDeveloperMode
                  ? null
                  : () =>
                        Navigator.of(context).pushNamed(UiRoutes.leaderboards),
              messagesNeedAttention: appState.inboxSummary.needsAttention,
              onMessagesPressed: appState.inboxAvailable
                  ? () => Navigator.of(context).pushNamed(UiRoutes.messages)
                  : null,
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
                        ? context.l10n.uiGuest
                        : appState.isDeveloperMode &&
                              profile.displayName == 'Developer'
                        ? context.l10n.developerIdentity
                        : profile.displayName,
                    gold: gold,
                    rewardRevision: appState.rewardDisplayRevision,
                    playerProgress: appState.isDeveloperMode
                        ? null
                        : appState.displayedPlayerProgress,
                    animateXpFrom: _animateXpFrom,
                  ),
                  SizedBox(height: ui.space.sm),
                  WeeklyBadgeRow(
                    title: _weeklyBadgeTitle(
                      progression,
                      appState,
                      context.l10n,
                    ),
                    isWeeklyLoading:
                        _preparingRunStart &&
                        _runStartSource == _RunStartSource.weekly,
                    onWeeklyPressed:
                        appState.isDeveloperMode ||
                            _preparingRunStart ||
                            !appState.weeklyFeaturedLevelAvailable
                        ? null
                        : () => _startWeeklyRun(appState),
                    onWeeklyLeaderboardPressed: appState.isDeveloperMode
                        ? null
                        : () =>
                              Navigator.of(context)
                                  .pushNamed(UiRoutes.leaderboards),
                  ),
                  SizedBox(height: ui.space.lg),
                  Row(
                    spacing: ui.space.md,
                    children: [
                      Expanded(
                        child: HubSelectedLevelCard(
                          levelId: selection.selectedLevelId,
                          runModeLabel: _runModeLabel(
                            selection.selectedRunMode,
                            context.l10n,
                          ),
                          onChange: () =>
                              Navigator.of(context)
                                  .pushNamed(UiRoutes.setupLevel),
                        ),
                      ),
                      Expanded(
                        child: HubSelectCharacterCard(
                          characterId: selection.selectedCharacterId,
                          buildName: buildDisplayName(
                            selection.buildName,
                            selection.selectedBuildIndexFor(
                              selection.selectedCharacterId,
                            ),
                            context.l10n,
                          ),
                          onChange: () =>
                              Navigator.of(context)
                                  .pushNamed(UiRoutes.selectCharacter),
                        ),
                      ),
                      Expanded(
                        child: HubSelectCardFrame(
                          onTap: () =>
                              Navigator.of(context)
                                  .pushNamed(UiRoutes.campaign),
                          background: const ValOutpostArtwork(),
                          child: HubSelectCardBody(
                            label: context.l10n.campaignHeading.toUpperCase(),
                            title: CampaignCatalog.chapters.first.title(
                              Localizations.localeOf(context).languageCode,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ui.space.lg),
                  Center(
                    child: PlayButton(
                      isLoading:
                          _preparingRunStart &&
                          _runStartSource == _RunStartSource.main,
                      showLoadingIndicator: false,
                      onPressed: _preparingRunStart ? null : () => _startRun(),
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

String _runModeLabel(RunMode runMode, AppLocalizations l10n) {
  switch (runMode) {
    case RunMode.campaign:
      return l10n.campaignHeading;
    case RunMode.practice:
      return l10n.uiPracticeHeading;
    case RunMode.competitive:
      return l10n.uiCompetitiveHeading;
    case RunMode.weekly:
      return l10n.uiWeeklyHeading;
  }
}

String _weeklyBadgeTitle(
  ProgressionState progression,
  AppState appState,
  AppLocalizations l10n,
) {
  if (appState.isDeveloperMode) return l10n.uiDeveloperModePracticeOnly;
  if (!appState.weeklyFeaturedLevelAvailable) {
    return l10n.uiWeeklyUnavailableInThisBuild;
  }
  final weeklyLevelName = appState.weeklyFeaturedLevelId
      .localizedName(l10n)
      .toUpperCase();
  final weekly = progression.weekly;
  return l10n.weeklyBadge(
    window: weekly.currentWindowId,
    level: weeklyLevelName,
  );
}
