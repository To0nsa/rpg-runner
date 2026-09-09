import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'content_build_models.dart';
import 'content_build_process.dart';

export 'content_build_models.dart';

/// One shell-owned repository Build job and its independent freshness state.
/// The caller resolves Save and locks source writes before invoking [build].
final class ContentBuildService extends ChangeNotifier {
  ContentBuildService({
    ContentBuildLauncher launcher = launchContentBuildProcess,
    Future<String> Function() executableResolver =
        resolveContentBuildDartExecutable,
  }) : _launcher = launcher,
       _executableResolver = executableResolver;

  final ContentBuildLauncher _launcher;
  final Future<String> Function() _executableResolver;
  ContentBuildPhase phase = ContentBuildPhase.idle;
  GeneratedContentStatus status = GeneratedContentStatus.notChecked;
  ContentBuildResult? result;
  ContentBuildProcess? _process;
  StreamSubscription<FileSystemEvent>? _watch;
  String? _workspaceRoot;
  bool _disposed = false;
  bool _running = false;
  bool _replacementStarted = false;
  bool _cancelRequested = false;
  bool _authoringDirty = false;
  bool _freshnessInvalidatedWhileRunning = false;
  bool _receivedResult = false;
  bool _dryRunRunning = false;
  Set<String> _jobOutputs = const {};

  bool get isRunning => _running;
  bool get canCancel => _running && !_replacementStarted && !_cancelRequested;
  bool get isFinishingSafely => _running && _replacementStarted;
  bool get hasUnsavedAuthoring => _authoringDirty;
  String? get workspaceRoot => _workspaceRoot;

  /// A result belongs to one repository and cannot survive workspace selection.
  void resetForWorkspaceChange() {
    if (_running) {
      throw StateError('Cannot change workspace during content Build.');
    }
    unawaited(_watch?.cancel());
    _watch = null;
    _workspaceRoot = null;
    result = null;
    status = _authoringDirty
        ? GeneratedContentStatus.buildNeeded
        : GeneratedContentStatus.notChecked;
    _publish();
  }

  void setAuthoringDirty(bool value) {
    if (_authoringDirty == value) return;
    _authoringDirty = value;
    if (value && !_running) status = GeneratedContentStatus.buildNeeded;
    _publish();
  }

  /// Dependency edits invalidate generated status without pretending files changed.
  void markSourcesChanged() {
    if (_running) {
      _freshnessInvalidatedWhileRunning = true;
    } else {
      status = GeneratedContentStatus.buildNeeded;
    }
    _publish();
  }

  Future<ContentBuildResult> build({required String workspaceRoot}) =>
      _run(workspaceRoot: workspaceRoot, dryRun: false);
  Future<ContentBuildResult> checkFreshness({required String workspaceRoot}) =>
      _run(workspaceRoot: workspaceRoot, dryRun: true);

  bool cancel() {
    if (!canCancel) return false;
    _cancelRequested = true;
    phase = ContentBuildPhase.cancelling;
    _process?.requestCancellation();
    _publish();
    return true;
  }

  Future<ContentBuildResult> _run({
    required String workspaceRoot,
    required bool dryRun,
  }) async {
    if (_running) throw StateError('A content Build/check is already running.');
    if (_disposed) throw StateError('The content Build service is disposed.');
    if (!dryRun && _authoringDirty) {
      throw StateError(
        'Save accepted authoring changes before building game content.',
      );
    }
    _running = true;
    _cancelRequested = false;
    _replacementStarted = false;
    _freshnessInvalidatedWhileRunning = false;
    _receivedResult = false;
    _dryRunRunning = dryRun;
    _jobOutputs = const {};
    result = null;
    phase = ContentBuildPhase.starting;
    status = dryRun
        ? GeneratedContentStatus.checking
        : GeneratedContentStatus.building;
    _publish();
    final errors = <String>[];
    Object? protocolError;
    ContentBuildResult? reported;
    try {
      final canonicalRoot = await Directory(workspaceRoot)
          .resolveSymbolicLinks();
      final generator = File(
        p.join(canonicalRoot, 'tool', 'generate_chunk_runtime_data.dart'),
      );
      if (!await generator.exists()) {
        throw const FileSystemException(
          'The repository content generator is missing.',
        );
      }
      if (!p.isWithin(canonicalRoot, await generator.resolveSymbolicLinks())) {
        throw const FileSystemException(
          'The generator resolves outside this repository.',
        );
      }
      await _bindWorkspace(canonicalRoot);
      final executable = await _executableResolver();
      if (_cancelRequested) {
        reported = ContentBuildResult(outcome: 'cancelled', dryRun: dryRun);
      } else {
        final process = await _launcher(
          executable: executable,
          arguments: [
            generator.path,
            '--machine-readable',
            if (dryRun) '--dry-run',
          ],
          workingDirectory: canonicalRoot,
        );
        _process = process;
        if (_cancelRequested) process.requestCancellation();
        final outputDone = process.stdoutLines.forEach((line) {
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            if (json['protocolVersion'] != 1) {
              throw const FormatException(
                'Unsupported Build protocol version.',
              );
            }
            if (json['type'] == 'result') {
              if (reported != null) {
                throw const FormatException(
                  'Build returned duplicate results.',
                );
              }
              reported = ContentBuildResult.fromJson(json);
              _receivedResult = true;
            } else if (json['type'] == 'progress') {
              if (json['outputs'] case final List<dynamic> outputs) {
                _jobOutputs = outputs.cast<String>().toSet();
              }
              _acceptProgress(json['phase'] as String);
            } else {
              throw const FormatException('Unknown Build report record.');
            }
          } on Object catch (error) {
            protocolError ??= error;
          }
        });
        final errorDone = process.stderrLines.forEach((line) {
          if (errors.length < 24) errors.add(line);
        });
        final exitCode = await process.exitCode;
        await Future.wait([outputDone, errorDone]);
        if (protocolError != null) {
          throw FormatException('Invalid generator report: $protocolError');
        }
        if (reported == null) {
          throw FormatException(
            'Generator exited $exitCode without a report. ${errors.join('\n')}',
          );
        }
        if (reported!.dryRun != dryRun ||
            (reported!.isVerified && exitCode != 0)) {
          throw const FormatException(
            'Generator result disagrees with its requested operation or exit status.',
          );
        }
      }
    } on Object catch (error) {
      reported = ContentBuildResult(
        outcome: 'failed',
        dryRun: dryRun,
        outputsCommitted: reported?.outputsCommitted ?? false,
        transactionOutcomeUnknown: _replacementStarted && reported == null,
        issues: [
          ContentBuildIssue(
            code: 'build_process_failed',
            message: error.toString(),
          ),
        ],
      );
    } finally {
      _process = null;
      _running = false;
      phase = ContentBuildPhase.idle;
    }
    result = reported!;
    status =
        _authoringDirty ||
            (_freshnessInvalidatedWhileRunning && reported!.isVerified)
        ? GeneratedContentStatus.buildNeeded
        : switch (reported!.outcome) {
            'current' || 'built' => GeneratedContentStatus.builtAndVerified,
            'drift' || 'stale' => GeneratedContentStatus.buildNeeded,
            'cancelled' => GeneratedContentStatus.cancelled,
            _ => GeneratedContentStatus.failed,
          };
    _publish();
    return reported!;
  }

  void _acceptProgress(String value) {
    final next = switch (value) {
      'capturing' => ContentBuildPhase.capturing,
      'validating' => ContentBuildPhase.validating,
      'checking_outputs' => ContentBuildPhase.checkingOutputs,
      'staging' => ContentBuildPhase.staging,
      'committing' => ContentBuildPhase.committing,
      'verifying' => ContentBuildPhase.verifying,
      _ => throw FormatException('Unknown Build phase: $value'),
    };
    if (next == ContentBuildPhase.committing) _replacementStarted = true;
    phase = _cancelRequested && !_replacementStarted
        ? ContentBuildPhase.cancelling
        : next;
    _publish();
  }

  Future<void> _bindWorkspace(String root) async {
    if (_workspaceRoot == root) return;
    await _watch?.cancel();
    _workspaceRoot = root;
    try {
      _watch = Directory(root).watch(recursive: true).listen((event) {
        final relative = p
            .relative(event.path, from: root)
            .replaceAll('\\', '/');
        final source =
            (relative.startsWith('assets/authoring/level/') &&
                relative.endsWith('.json')) ||
            ((relative.startsWith('assets/images/level/atlases/') ||
                    relative.startsWith('assets/images/parallax/')) &&
                relative.endsWith('.png')) ||
            ((relative.startsWith('tool/') ||
                    relative.startsWith(
                      'packages/runner_content_pipeline/lib/',
                    ) ||
                    relative.startsWith('packages/terrain_materials/lib/') ||
                    relative.startsWith('packages/runner_core/lib/')) &&
                relative.endsWith('.dart')) ||
            relative == 'pubspec.yaml' ||
            relative == 'pubspec.lock' ||
            relative == 'packages/runner_core/pubspec.yaml' ||
            relative == 'packages/runner_content_pipeline/pubspec.yaml' ||
            relative == 'packages/terrain_materials/pubspec.yaml';
        final output =
            _jobOutputs.contains(relative) ||
            (result?.outputs.contains(relative) ?? false);
        if (!source && !output) return;
        // The generator owns its output writes until its final report. Input
        // changes and later events must survive the process-exit window.
        if (!_running || !output || _dryRunRunning || _receivedResult) {
          markSourcesChanged();
        }
      }, onError: (Object _) => markSourcesChanged());
    } on FileSystemException {
      // Manual freshness checks remain authoritative where filesystem watching
      // is unavailable. Existing output presence never proves a valid build.
    }
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    if (canCancel) cancel();
    _disposed = true;
    unawaited(_watch?.cancel());
    super.dispose();
  }
}
