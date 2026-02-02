import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
              child: SegmentedButton<RunType>(
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
