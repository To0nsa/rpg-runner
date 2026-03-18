import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/levels/level_id.dart';

import '../../app/ui_routes.dart';
import '../../components/app_segmented_control.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../components/play_button.dart';
import '../../state/app_state.dart';
import '../../state/selection_state.dart';
import 'level_select_section.dart';

class LevelSetupPage extends StatefulWidget {
  const LevelSetupPage({super.key});

  @override
  State<LevelSetupPage> createState() => _LevelSetupPageState();
}

class _LevelSetupPageState extends State<LevelSetupPage> {
  bool _preparingRunStart = false;
  bool _handlingPop = false;
  bool _hasDraftChanges = false;
  late final AppState _appState;
  RunMode _draftRunMode = RunMode.competitive;
  late LevelId _draftLevelId;
  Timer? _commitDebounceTimer;

  @override
  void initState() {
    super.initState();
    _appState = context.read<AppState>();
    final selection = _appState.selection;
    _draftRunMode = selection.selectedRunMode == RunMode.weekly
        ? RunMode.competitive
        : selection.selectedRunMode;
    _draftLevelId = selection.selectedLevelId;
  }

  Future<void> _flushDraftSelection({required bool bestEffort}) async {
    if (!_hasDraftChanges) {
      return;
    }
    final appState = _appState;
    final current = appState.selection;
    if (current.selectedRunMode != _draftRunMode ||
        current.selectedLevelId != _draftLevelId) {
      try {
        await appState.setRunModeAndLevel(
          runMode: _draftRunMode,
          levelId: _draftLevelId,
        );
      } catch (_) {
        if (!bestEffort) {
          rethrow;
        }
      }
    }
    _hasDraftChanges = false;
  }

  void _scheduleDraftCommit() {
    _commitDebounceTimer?.cancel();
    _commitDebounceTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      _commitDebounceTimer = null;
      unawaited(_flushDraftSelection(bestEffort: true));
    });
  }

  void _onRunModeChanged(RunMode mode) {
    if (_draftRunMode == mode) {
      return;
    }
    setState(() {
      _draftRunMode = mode;
      _hasDraftChanges = true;
    });
    _scheduleDraftCommit();
  }

  void _onLevelChanged(LevelId levelId) {
    if (_draftLevelId == levelId) {
      return;
    }
    setState(() {
      _draftLevelId = levelId;
      _hasDraftChanges = true;
    });
    _scheduleDraftCommit();
  }

  Future<void> _startRun(AppState appState) async {
    if (_preparingRunStart) return;
    setState(() => _preparingRunStart = true);
    try {
      _commitDebounceTimer?.cancel();
      _commitDebounceTimer = null;
      await _flushDraftSelection(bestEffort: false);
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        UiRoutes.runBootstrap,
        arguments: const RunStartBootstrapArgs(),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to navigate to run start right now. Try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _preparingRunStart = false);
      }
    }
  }

  Future<void> _commitDraftSelectionAndPopIfNeeded(
    bool didPop,
    Object? result,
  ) async {
    if (didPop || _handlingPop || _preparingRunStart) {
      return;
    }
    _handlingPop = true;
    try {
      _commitDebounceTimer?.cancel();
      _commitDebounceTimer = null;
      await _flushDraftSelection(bestEffort: false);
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } finally {
      _handlingPop = false;
    }
  }

  @override
  void dispose() {
    _commitDebounceTimer?.cancel();
    _commitDebounceTimer = null;
    unawaited(_flushDraftSelection(bestEffort: true));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _commitDraftSelectionAndPopIfNeeded,
      child: MenuScaffold(
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
                  selected: _draftRunMode,
                  onChanged: _onRunModeChanged,
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
                  selectedLevelId: _draftLevelId,
                  forcedLevelId: null,
                  onSelectLevel: _onLevelChanged,
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
      ),
    );
  }
}
