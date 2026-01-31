import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/ui_routes.dart';
import '../../components/menu_button.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app_state.dart';
import '../../state/selection_state.dart';
import 'level_select_section.dart';

class LevelSetupPage extends StatelessWidget {
  const LevelSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selection = appState.selection;

    return MenuScaffold(
      title: 'Select Level',
      child: MenuLayout(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Run Type',
              style: TextStyle(color: Colors.white70, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            SegmentedButton<RunType>(
              segments: const [
                ButtonSegment<RunType>(
                  value: RunType.practice,
                  label: Text('Practice (Random)'),
                ),
                ButtonSegment<RunType>(
                  value: RunType.competitive,
                  label: Text('Competitive (Season)'),
                ),
              ],
              selected: {selection.selectedRunType},
              onSelectionChanged: (value) {
                if (value.isEmpty) return;
                appState.setRunType(value.first);
              },
            ),
            const SizedBox(height: 24),
            _WeeklyChallengeCard(
              onPlayWeekly: null,
              onLeaderboard: () =>
                  Navigator.of(context).pushNamed(UiRoutes.leaderboards),
            ),
            const SizedBox(height: 24),
            Center(
              child: LevelSelectSection(
                selectedLevelId: selection.selectedLevelId,
                onSelectLevel: appState.setLevel,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                MenuButton(
                  label: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
                MenuButton(
                  label: 'Loadout',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(UiRoutes.setupLoadout),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyChallengeCard extends StatelessWidget {
  const _WeeklyChallengeCard({
    required this.onPlayWeekly,
    required this.onLeaderboard,
  });

  final VoidCallback? onPlayWeekly;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Challenge',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Week 01 · ends in 2d 14h',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              MenuButton(
                label: 'Play Weekly',
                width: 140,
                height: 40,
                fontSize: 12,
                onPressed: onPlayWeekly,
              ),
              const SizedBox(width: 8),
              MenuButton(
                label: 'Leaderboard',
                width: 140,
                height: 40,
                fontSize: 12,
                onPressed: onLeaderboard,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
