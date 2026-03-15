import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/ui_routes.dart';
import '../../components/app_segmented_control.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../components/play_button.dart';
import '../../state/app_state.dart';
import '../../state/run_start_remote_exception.dart';
import '../../state/selection_state.dart';
import 'level_select_section.dart';

class LevelSetupPage extends StatefulWidget {
  const LevelSetupPage({super.key});

  @override
  State<LevelSetupPage> createState() => _LevelSetupPageState();
}

class _LevelSetupPageState extends State<LevelSetupPage> {
  bool _preparingRunStart = false;

  Future<void> _startRun(AppState appState) async {
    if (_preparingRunStart) return;
    setState(() => _preparingRunStart = true);
    try {
      final descriptor = await appState.prepareRunStartDescriptor();
      if (!mounted) return;
      await Navigator.of(context).pushNamed(UiRoutes.run, arguments: descriptor);
    } catch (error) {
      if (!mounted) return;
      final message =
          error is RunStartRemoteException && error.isPreconditionFailed
          ? 'Run start requirements are not met for the selected mode yet.'
          : 'Unable to start run right now. Check your connection and try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _preparingRunStart = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selection = appState.selection;
    final selectedRunMode = selection.selectedRunMode == RunMode.weekly
      ? RunMode.competitive
      : selection.selectedRunMode;

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
                ],
                selected: selectedRunMode,
                onChanged: appState.setRunMode,
                labelBuilder: (context, value) => switch (value) {
                  RunMode.practice => const Text('PRACTICE'),
                  RunMode.competitive => const Text('COMPETITIVE'),
                  RunMode.weekly => const SizedBox.shrink(),
                },
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: LevelSelectSection(
                selectedLevelId: selection.selectedLevelId,
                forcedLevelId: null,
                onSelectLevel: appState.setLevel,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: PlayButton(
                isLoading: _preparingRunStart,
                onPressed: () => _startRun(appState),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
