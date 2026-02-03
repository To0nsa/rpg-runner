import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/ui_routes.dart';
import '../../components/app_button.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../components/weekly_badge_row.dart';
import 'components/hub_select_character_card.dart';
import 'components/hub_select_level_card.dart';
import 'components/hub_top_row.dart';
import '../../state/app_state.dart';
import '../../state/profile_counter_keys.dart';
import '../../state/selection_state.dart';
import '../../theme/ui_tokens.dart';

class PlayHubPage extends StatefulWidget {
  const PlayHubPage({super.key});

  @override
  State<PlayHubPage> createState() => _PlayHubPageState();
}

class _PlayHubPageState extends State<PlayHubPage> {
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().startWarmup();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final appState = context.watch<AppState>();
    final selection = appState.selection;
    final profile = appState.profile;
    final gold = profile.counters[ProfileCounterKeys.gold] ?? 0;

    return MenuScaffold(
      showAppBar: false,
      child: MenuLayout(
        horizontalPadding: ui.space.lg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => setState(() => _menuOpen = !_menuOpen),
                  icon: const Icon(Icons.menu),
                  iconSize: ui.sizes.iconSize.lg,
                  color: ui.colors.textPrimary,
                  tooltip: _menuOpen ? 'Close menu' : 'Open menu',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: ui.sizes.tapTarget,
                    minHeight: ui.sizes.tapTarget,
                  ),
                ),
                if (_menuOpen) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HubIconButton(
                        icon: Icons.library_books,
                        label: 'Codex',
                        onPressed: () =>
                            Navigator.of(context).pushNamed(UiRoutes.library),
                      ),
                      _HubIconButton(
                        icon: Icons.storefront,
                        label: 'Town',
                        onPressed: () =>
                            Navigator.of(context).pushNamed(UiRoutes.town),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HubIconButton(
                        icon: Icons.person,
                        label: 'Profile',
                        onPressed: () =>
                            Navigator.of(context).pushNamed(UiRoutes.profile),
                      ),
                      _HubIconButton(
                        icon: Icons.leaderboard,
                        label: 'Top',
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed(UiRoutes.leaderboards),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HubIconButton(
                        icon: Icons.settings,
                        label: 'Options',
                        onPressed: () =>
                            Navigator.of(context).pushNamed(UiRoutes.options),
                      ),
                      _HubIconButton(
                        icon: Icons.monetization_on,
                        label: 'Support',
                        onPressed: () =>
                            Navigator.of(context).pushNamed(UiRoutes.support),
                      ),
                    ],
                  ),
                ],
              ],
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
                    profileId: profile.profileId,
                    gold: gold,
                  ),
                  SizedBox(height: ui.space.sm),
                  WeeklyBadgeRow(
                    onWeeklyPressed: null,
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
                          runTypeLabel: _runTypeLabel(
                            selection.selectedRunType,
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
                    child: AppButton(
                      label: 'PLAY',
                      size: AppButtonSize.lg,
                      onPressed: () {
                        final args = appState.buildRunStartArgs();
                        Navigator.of(
                          context,
                        ).pushNamed(UiRoutes.run, arguments: args);
                      },
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

String _runTypeLabel(RunType runType) {
  switch (runType) {
    case RunType.practice:
      return 'Practice (Random)';
    case RunType.competitive:
      return 'Competitive (Season)';
  }
}

class _HubIconButton extends StatelessWidget {
  const _HubIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: ui.colors.textPrimary),
          iconSize: ui.sizes.iconSize.lg,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: ui.sizes.tapTarget,
            minHeight: ui.sizes.tapTarget,
          ),
        ),
        SizedBox(height: ui.space.xxs),
        Text(
          label,
          style: ui.text.caption.copyWith(color: ui.colors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
