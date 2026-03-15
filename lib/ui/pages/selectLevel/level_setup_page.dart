import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/app_segmented_control.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../levels/level_id_ui.dart';
import '../../state/app_state.dart';
import '../../state/selection_state.dart';
import '../../theme/ui_tokens.dart';
import 'level_select_section.dart';

class LevelSetupPage extends StatelessWidget {
  const LevelSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selection = appState.selection;
    final weeklyForcedLevelId = selection.selectedRunMode == RunMode.weekly
        ? appState.weeklyFeaturedLevelId
        : null;

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
                  RunMode.practice => const Text('PRACTICE'),
                  RunMode.competitive => const Text('COMPETITIVE'),
                  RunMode.weekly => const Text('WEEKLY'),
                },
              ),
            ),
            const SizedBox(height: 20),
            if (weeklyForcedLevelId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Weekly uses a fixed level: '
                  '${weeklyForcedLevelId.displayName}.',
                  style: context.ui.text.body,
                  textAlign: TextAlign.center,
                ),
              ),
            Center(
              child: LevelSelectSection(
                selectedLevelId: selection.selectedLevelId,
                forcedLevelId: weeklyForcedLevelId,
                onSelectLevel: appState.setLevel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
