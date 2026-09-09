import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/content_build_dialog.dart';
import 'package:runner_editor/src/build/content_build_process.dart';
import 'package:runner_editor/src/build/content_build_service.dart';

void main() {
  late Directory root;
  late _Process process;
  late ContentBuildService service;
  late Completer<void> launched;
  late List<String> capturedArguments;
  setUp(() {
    root = Directory.systemTemp.createTempSync('editor_build_service_');
    final generator = File(
      '${root.path}/tool/generate_chunk_runtime_data.dart',
    );
    generator.parent.createSync(recursive: true);
    generator.writeAsStringSync('// fake generator');
    process = _Process();
    launched = Completer();
    service = ContentBuildService(
      executableResolver: () async => 'C:/Dart SDK/dart.exe',
      launcher:
          ({
            required executable,
            required arguments,
            required workingDirectory,
          }) async {
            expect(executable, 'C:/Dart SDK/dart.exe');
            expect(workingDirectory, await root.resolveSymbolicLinks());
            capturedArguments = arguments;
            launched.complete();
            return process;
          },
    );
  });
  tearDown(() async {
    service.dispose();
    await Future<void>.delayed(Duration.zero);
    await root.delete(recursive: true);
  });

  test(
    'one job, fixed process arguments, and frozen structured result',
    () async {
      final job = service.build(workspaceRoot: root.path);
      await launched.future;
      await expectLater(
        service.build(workspaceRoot: root.path),
        throwsStateError,
      );
      expect(capturedArguments.last, '--machine-readable');
      expect(capturedArguments, hasLength(2));
      process.progress('validating');
      await Future<void>.delayed(Duration.zero);
      expect(service.phase, ContentBuildPhase.validating);
      await process.finish(_report());
      final result = await job;
      expect(service.status, GeneratedContentStatus.builtAndVerified);
      expect(result.includedLevels.single.levelId, 'ready');
      expect(result.excludedLevels.single.levelId, 'unfinished');
      expect(() => result.levels.clear(), throwsUnsupportedError);
      service.setAuthoringDirty(true);
      expect(service.status, GeneratedContentStatus.buildNeeded);
      service.setAuthoringDirty(false);
      expect(service.status, GeneratedContentStatus.buildNeeded);
      service.resetForWorkspaceChange();
      expect(service.result, isNull);
      expect(service.workspaceRoot, isNull);
      expect(service.status, GeneratedContentStatus.notChecked);
    },
  );

  test(
    'cancellation requests once and waits for authoritative final report',
    () async {
      final job = service.build(workspaceRoot: root.path);
      await launched.future;
      await Future<void>.delayed(Duration.zero);
      expect(service.cancel(), isTrue);
      expect(service.cancel(), isFalse);
      expect(process.cancellations, 1);
      expect(service.isRunning, isTrue);
      await process.finish(_report(outcome: 'cancelled'), exit: 1);
      expect((await job).outcome, 'cancelled');
      expect(service.status, GeneratedContentStatus.cancelled);
    },
  );

  test(
    'replacement crossing disables cancellation and reports committed outcome',
    () async {
      final job = service.build(workspaceRoot: root.path);
      await launched.future;
      process.progress('committing');
      await Future<void>.delayed(Duration.zero);
      expect(service.isFinishingSafely, isTrue);
      expect(service.cancel(), isFalse);
      expect(process.cancellations, 0);
      await process.finish(_report(outcome: 'stale', committed: true), exit: 1);
      final result = await job;
      expect(result.outputsCommitted, isTrue);
      expect(result.isVerified, isFalse);
      expect(service.status, GeneratedContentStatus.buildNeeded);
    },
  );

  test('missing final result after replacement is unknown, never clean cancellation', () async {
    final job = service.build(workspaceRoot: root.path);
    await launched.future;
    process.progress('committing');
    await process.finish(null, exit: 1);
    final result = await job;
    expect(result.outcome, 'failed');
    expect(result.transactionOutcomeUnknown, isTrue);
    expect(result.outputsCommitted, isFalse);
  });

  test('exit zero cannot replace exact report validation', () async {
    final job = service.checkFreshness(workspaceRoot: root.path);
    await launched.future;
    expect(capturedArguments.last, '--dry-run');
    final invalid = _report(outcome: 'current', dryRun: true);
    invalid['inputFingerprint'] = 'not-a-content-digest';
    await process.finish(invalid);
    expect((await job).outcome, 'failed');
    expect(service.status, GeneratedContentStatus.failed);
  });

  test(
    'freshness check accounts for unsaved changes and disk changes',
    () async {
      service.setAuthoringDirty(true);
      await expectLater(
        service.build(workspaceRoot: root.path),
        throwsStateError,
      );
      final job = service.checkFreshness(workspaceRoot: root.path);
      await launched.future;
      await process.finish(_report(outcome: 'current', dryRun: true));
      expect((await job).isVerified, isTrue);
      expect(service.status, GeneratedContentStatus.buildNeeded);
      service.setAuthoringDirty(false);
      service.markSourcesChanged();
      expect(service.status, GeneratedContentStatus.buildNeeded);
    },
  );

  test('source invalidation during a job cannot be overwritten by a late success report', () async {
    final job = service.checkFreshness(workspaceRoot: root.path);
    await launched.future;
    service.markSourcesChanged();
    await process.finish(_report(outcome: 'current', dryRun: true));
    expect((await job).isVerified, isTrue);
    expect(service.status, GeneratedContentStatus.buildNeeded);
  });

  test(
    'external generated-output edits invalidate the reported success',
    () async {
      final generated = File('${root.path}/lib/generated.dart');
      generated.parent.createSync(recursive: true);
      generated.writeAsStringSync('before');
      final job = service.build(workspaceRoot: root.path);
      await launched.future;
      await process.finish(_report());
      await job;
      expect(service.status, GeneratedContentStatus.builtAndVerified);
      final invalidated = Completer<void>();
      service.addListener(() {
        if (service.status == GeneratedContentStatus.buildNeeded &&
            !invalidated.isCompleted) {
          invalidated.complete();
        }
      });
      generated.writeAsStringSync('after');
      await invalidated.future.timeout(const Duration(seconds: 3));
      expect(service.result!.outcome, 'built');
      expect(service.status, GeneratedContentStatus.buildNeeded);
    },
    skip: !Platform.isWindows && !Platform.isMacOS,
  );

  testWidgets(
    'dialog explains safe completion and keeps repair actions usable at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Future<ContentBuildResult> job;
      await tester.runAsync(() async {
        job = service.build(workspaceRoot: root.path);
        await launched.future;
        process.progress('committing');
        await Future<void>.delayed(Duration.zero);
      });
      var closed = false;
      String? opened;
      String? restored;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentBuildDialog(
              controller: service,
              onClose: () => closed = true,
              onOpenLevel: (level) => opened = level.levelId,
              onAddContent: (_) {},
              onExcludeLevel: (_) {},
              onRestoreLevel: (level) => restored = level.levelId,
            ),
          ),
        ),
      );
      expect(find.text('Finishing safely'), findsWidgets);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('content_build_cancel')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('content_build_close')));
      expect(closed, isFalse);
      await tester.runAsync(() async {
        await process.finish(_report(outcome: 'invalid'), exit: 1);
        await job;
      });
      await tester.pumpAndSettle();
      expect(find.text('Included in game build (1)'), findsOneWidget);
      expect(find.text('Excluded from game build (1)'), findsOneWidget);
      expect(find.text('Exclude from game build'), findsOneWidget);
      await tester.tap(find.text('Open').first);
      expect(opened, 'ready');
      await tester.ensureVisible(find.text('Restore to game build'));
      await tester.tap(find.text('Restore to game build'));
      expect(restored, 'unfinished');
      expect(tester.takeException(), isNull);
    },
  );
}

Map<String, Object?> _report({
  String outcome = 'built',
  bool dryRun = false,
  bool? committed,
}) => {
  'protocolVersion': 1,
  'type': 'result',
  'outcome': outcome,
  'dryRun': dryRun,
  'inputFingerprint': List.filled(64, 'a').join(),
  'levels': [
    {
      'levelId': 'ready',
      'displayName': 'Ready',
      'includeInBuild': true,
      'status': 'active',
    },
    {
      'levelId': 'unfinished',
      'displayName': 'Unfinished',
      'includeInBuild': false,
      'status': 'active',
    },
  ],
  'changes': [],
  'outputs': ['lib/generated.dart'],
  'issues': [],
  'outputsCommitted': committed ?? outcome == 'built',
  'rollbackComplete': false,
  'transactionFailures': [],
};

final class _Process implements ContentBuildProcess {
  final output = StreamController<String>();
  final errors = StreamController<String>();
  final exited = Completer<int>();
  var cancellations = 0;
  @override
  Stream<String> get stdoutLines => output.stream;
  @override
  Stream<String> get stderrLines => errors.stream;
  @override
  Future<int> get exitCode => exited.future;
  @override
  void requestCancellation() => cancellations++;
  void progress(String phase) => output.add(
    jsonEncode({'protocolVersion': 1, 'type': 'progress', 'phase': phase}),
  );
  Future<void> finish(Map<String, Object?>? result, {int exit = 0}) async {
    if (result != null) output.add(jsonEncode(result));
    await output.close();
    await errors.close();
    exited.complete(exit);
  }
}
