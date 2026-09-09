import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rpg_runner/playtest.dart';

import '../../../playtest/authored_playtest_preparation.dart';

/// One captured authored scenario; pages still own field acceptance and source
/// selection. Generation checks span both asynchronous capture and compilation.
enum AuthoredPlaytestMode { edit, preparing, playing, preparationFailed }

typedef AuthoredPlaytestHostBuilder = Widget Function({
  required PlaytestScenario scenario,
  required RunnerPlaytestController controller,
  required AssetBundle assetBundle,
  required RunnerPlaytestAppearance appearance,
  required VoidCallback onStop,
});

class AuthoredPlaytestSession extends ChangeNotifier {
  AuthoredPlaytestMode _mode = AuthoredPlaytestMode.edit;
  Object? _capturedSource;
  int _generation = 0;
  bool _disposed = false;
  RunnerPlaytestController? _controller;
  PlaytestPreparationResult? _result;
  List<PlaytestPreparationIssue> _issues = const [];
  final Set<RunnerPlaytestController> _retiredControllers = {};

  AuthoredPlaytestMode get mode => _mode;
  bool get locksEditor => _mode != AuthoredPlaytestMode.edit;
  PlaytestPreparationResult? get result => _result;
  List<PlaytestPreparationIssue> get issues => _issues;
  RunnerPlaytestController? get controller => _controller;

  Future<void> prepare({
    required Object source,
    required bool Function() isSourceCurrent,
    required Future<PlaytestPreparationInput> Function() capture,
    required PlaytestPreparationRunner runner,
  }) async {
    if (_disposed || locksEditor) return;
    final generation = ++_generation;
    _capturedSource = source;
    _issues = const [];
    _result = null;
    _setMode(AuthoredPlaytestMode.preparing);
    bool accepts() =>
        !_disposed &&
        generation == _generation &&
        _mode == AuthoredPlaytestMode.preparing &&
        identical(_capturedSource, source) &&
        isSourceCurrent();
    late final PlaytestPreparationResult prepared;
    try {
      final input = await capture();
      if (!accepts()) return;
      prepared = await runner(input);
    } on PlaytestPreparationException catch (error) {
      if (accepts()) {
        _fail([
          PlaytestPreparationIssue(code: error.code, message: error.message),
        ]);
      }
      return;
    } on Object catch (error) {
      if (accepts()) {
        _fail([
          PlaytestPreparationIssue(
            code: 'authored_playtest_preparation_failed',
            message: 'Could not prepare this captured workspace: $error',
          ),
        ]);
      }
      return;
    }
    if (!accepts()) return;
    if (!prepared.isSuccess) {
      _fail(prepared.issues);
      return;
    }
    if (prepared.assetBundle == null || prepared.appearance == null) {
      _fail(const [
        PlaytestPreparationIssue(
          code: 'playtest_capture_incomplete',
          message:
              'The captured appearance or images are missing. Prepare again.',
        ),
      ]);
      return;
    }
    _result = prepared;
    _controller = RunnerPlaytestController();
    _setMode(AuthoredPlaytestMode.playing);
  }

  /// External reload, controller replacement, or source edits invalidate any
  /// pending work before a late completion can mount a host for stale content.
  void reconcileSource(Object? source) {
    if (locksEditor && !identical(source, _capturedSource)) stop();
  }

  bool stop() {
    if (_disposed || !locksEditor) return false;
    final current = _controller;
    if (current != null && current.stop()) return true;
    _returnToEdit();
    return true;
  }

  void runtimeStopped(RunnerPlaytestController stopped) {
    if (!_disposed && identical(stopped, _controller)) _returnToEdit();
    _retire(stopped);
  }

  /// F5 in Edit is admitted by the page, which can first validate local input.
  bool handleShortcut(LogicalKeyboardKey key) {
    if (!locksEditor) return false;
    if (key == LogicalKeyboardKey.f5 || key == LogicalKeyboardKey.escape) {
      return stop();
    }
    if (_mode != AuthoredPlaytestMode.playing) return false;
    final current = _controller;
    if (current == null) return false;
    if (key == LogicalKeyboardKey.f6) return current.restart();
    if (key == LogicalKeyboardKey.keyP) return current.togglePause();
    if (key == LogicalKeyboardKey.enter) return current.start();
    return false;
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (_mode == AuthoredPlaytestMode.playing &&
        state != AppLifecycleState.resumed) {
      _controller?.releaseFocus();
    }
  }

  void _fail(List<PlaytestPreparationIssue> issues) {
    _issues = List.unmodifiable(issues);
    _setMode(AuthoredPlaytestMode.preparationFailed);
  }

  void _returnToEdit() {
    _generation++;
    final current = _controller;
    _controller = null;
    _capturedSource = null;
    _result = null;
    _issues = const [];
    _setMode(AuthoredPlaytestMode.edit);
    if (current != null) _retire(current);
  }

  void _setMode(AuthoredPlaytestMode value) {
    if (_mode == value) return;
    _mode = value;
    if (!_disposed) notifyListeners();
  }

  void _retire(RunnerPlaytestController controller) {
    if (!_retiredControllers.add(controller)) return;
    // Host teardown must finish before disposing its externally owned handle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
      _retiredControllers.remove(controller);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    final current = _controller;
    _controller = null;
    if (current != null) _retire(current);
    super.dispose();
  }
}

Widget buildDefaultAuthoredPlaytestHost({
  required PlaytestScenario scenario,
  required RunnerPlaytestController controller,
  required AssetBundle assetBundle,
  required RunnerPlaytestAppearance appearance,
  required VoidCallback onStop,
}) => RunnerPlaytestHost(
  scenario: scenario,
  controller: controller,
  assetBundle: assetBundle,
  appearance: appearance,
  onStop: onStop,
);

/// Shared preparation/error surface and runtime composition. The authoring
/// subtree remains mounted by its page, outside this temporary overlay.
class AuthoredPlaytestOverlay extends StatelessWidget {
  const AuthoredPlaytestOverlay({
    super.key,
    required this.session,
    required this.subject,
    required this.keyPrefix,
    required this.onRetry,
    this.hostBuilder = buildDefaultAuthoredPlaytestHost,
  });

  final AuthoredPlaytestSession session;
  final String subject;
  final String keyPrefix;
  final VoidCallback onRetry;
  final AuthoredPlaytestHostBuilder hostBuilder;

  @override
  Widget build(BuildContext context) {
    final result = session.result;
    final controller = session.controller;
    if (session.mode == AuthoredPlaytestMode.playing &&
        result != null &&
        controller != null) {
      return Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                result.scenario is ChunkPlaytestScenario
                    ? 'Test chunk — focused loop · Authored markers without the level enemy-free opening.'
                    : 'Play level — seeded run · Actual difficulty, sections, and enemy-free opening.',
              ),
            ),
          ),
          if (result.warnings.isNotEmpty)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(result.warnings.join('\n')),
              ),
            ),
          Expanded(
            child: hostBuilder(
              scenario: result.scenario!,
              controller: controller,
              assetBundle: result.assetBundle!,
              appearance: result.appearance!,
              onStop: () => session.runtimeStopped(controller),
            ),
          ),
        ],
      );
    }
    final preparing = session.mode == AuthoredPlaytestMode.preparing;
    final title = preparing
        ? 'Preparing ${subject.toLowerCase()} playtest'
        : '$subject playtest could not start';
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      key: ValueKey<String>('${keyPrefix}_state_title'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      preparing
                          ? 'Capturing and compiling the accepted edits and their source dependencies.'
                          : session.issues
                                .map(
                                  (issue) =>
                                      '${issue.message}${issue.sourcePath == null ? '' : '\n${issue.sourcePath}'}\n${issue.code}',
                                )
                                .join('\n\n'),
                      key: ValueKey<String>('${keyPrefix}_state_detail'),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (!preparing)
                          FilledButton(
                            key: ValueKey<String>('${keyPrefix}_retry_button'),
                            onPressed: onRetry,
                            child: const Text('Retry'),
                          ),
                        OutlinedButton(
                          key: ValueKey<String>('${keyPrefix}_return_button'),
                          onPressed: session.stop,
                          child: const Text('Return to Edit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
