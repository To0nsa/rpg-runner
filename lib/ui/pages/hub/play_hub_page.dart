import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/ui_routes.dart';
import '../../components/menu_button.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import 'components/selected_character_card.dart';
import 'components/selected_level_card.dart';
import 'components/top_row.dart';
import '../../state/app_state.dart';
import '../../state/profile_counter_keys.dart';
import '../../state/selection_state.dart';

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
    final appState = context.watch<AppState>();
    final selection = appState.selection;
    final profile = appState.profile;
    final gold = profile.counters[ProfileCounterKeys.gold] ?? 0;

    return MenuScaffold(
      showAppBar: false,
      child: MenuLayout(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(0, -12),
                  child: IconButton(
                    onPressed: () => setState(() => _menuOpen = !_menuOpen),
                    icon: const Icon(Icons.menu),
                    iconSize: 32,
                    color: Colors.white,
                    tooltip: _menuOpen ? 'Close menu' : 'Open menu',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TopRow(
                    displayName: profile.displayName.isEmpty
                        ? 'Guest'
                        : profile.displayName,
                    profileId: profile.profileId,
                    gold: gold,
                  ),
                  const SizedBox(height: 12),
                  _WeeklyBadgeRow(
                    onWeeklyPressed: null,
                    onWeeklyLeaderboardPressed: () =>
                        Navigator.of(context).pushNamed(UiRoutes.leaderboards),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SelectedLevelCard(
                          levelId: selection.selectedLevelId,
                          runTypeLabel: _runTypeLabel(
                            selection.selectedRunType,
                          ),
                          onChange: () => Navigator.of(
                            context,
                          ).pushNamed(UiRoutes.setupLevel),
                        ),
                        SelectedCharacterCard(
                          characterId: selection.selectedCharacterId,
                          buildName: selection.buildName,
                          onChange: () => Navigator.of(
                            context,
                          ).pushNamed(UiRoutes.setupLoadout),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: MenuButton(
                      label: 'PLAY',
                      width: 160,
                      height: 48,
                      fontSize: 16,
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

class _WeeklyBadgeRow extends StatelessWidget {
  const _WeeklyBadgeRow({
    required this.onWeeklyPressed,
    required this.onWeeklyLeaderboardPressed,
  });

  final VoidCallback? onWeeklyPressed;
  final VoidCallback onWeeklyLeaderboardPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white70),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Weekly Challenge · Coming Soon',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          MenuButton(
            label: 'Play',
            width: 100,
            height: 36,
            fontSize: 12,
            onPressed: onWeeklyPressed,
          ),
          const SizedBox(width: 8),
          MenuButton(
            label: 'Leaderboard',
            width: 120,
            height: 36,
            fontSize: 12,
            onPressed: onWeeklyLeaderboardPressed,
          ),
        ],
      ),
    );
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
          iconSize: 32,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
