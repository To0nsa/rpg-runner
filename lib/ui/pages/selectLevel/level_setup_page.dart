import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/app_segmented_control.dart';
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
            Center(
              child: AppSegmentedControl<RunMode>(
                values: const [
                  RunMode.practice,
                  RunMode.competitive,
                  RunMode.weekly,
                ],
                selected: selection.selectedRunMode,
                onChanged: appState.setRunMode,
                labelBuilder: (context, value) => switch (value) {
                  RunMode.practice => const Text('Practice (Random)'),
                  RunMode.competitive => const Text('Competitive (Season)'),
                  RunMode.weekly => const Text('Weekly'),
                },
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: LevelSelectSection(
                selectedLevelId: selection.selectedLevelId,
                onSelectLevel: appState.setLevel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
