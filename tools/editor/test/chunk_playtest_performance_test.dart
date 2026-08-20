import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/playtest/chunk_playtest_preparation.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

const int _warmupCount = 2;
const int _sampleCount = 12;
const int _backgroundSampleCount = 4;

void main() {
  test('profiles canonical capture and playtest preparation', () async {
    final workspaceRoot = p.normalize(
      p.absolute(p.join(Directory.current.path, '..', '..')),
    );
    final document = await ChunkDomainPlugin().loadV2FromRepo(
      EditorWorkspace(rootPath: workspaceRoot),
    );
    final selectedChunkKey = document.chunks
        .singleWhere((chunk) => chunk.levelId == 'forest')
        .chunkKey;

    for (var index = 0; index < _warmupCount; index += 1) {
      final input = captureChunkPlaytestPreparationInput(
        document: document,
        selectedChunkKey: selectedChunkKey,
      );
      expect(prepareChunkPlaytest(input).scenario, isNotNull);
    }

    final captureMicros = <int>[];
    final synchronousPreparationMicros = <int>[];
    late ChunkPlaytestPreparationInput input;
    for (var index = 0; index < _sampleCount; index += 1) {
      final captureWatch = Stopwatch()..start();
      input = captureChunkPlaytestPreparationInput(
        document: document,
        selectedChunkKey: selectedChunkKey,
      );
      captureWatch.stop();
      captureMicros.add(captureWatch.elapsedMicroseconds);

      final preparationWatch = Stopwatch()..start();
      final result = prepareChunkPlaytest(input);
      preparationWatch.stop();
      expect(result.scenario, isNotNull);
      synchronousPreparationMicros.add(preparationWatch.elapsedMicroseconds);
    }

    final backgroundPreparationMicros = <int>[];
    for (var index = 0; index < _backgroundSampleCount; index += 1) {
      final watch = Stopwatch()..start();
      final result = await prepareChunkPlaytestInBackground(input);
      watch.stop();
      expect(result.scenario, isNotNull);
      backgroundPreparationMicros.add(watch.elapsedMicroseconds);
    }

    final revision = Process.runSync('git', const <String>[
      'rev-parse',
      'HEAD',
    ], workingDirectory: workspaceRoot);
    final status = Process.runSync('git', const <String>[
      'status',
      '--porcelain',
      '--untracked-files=all',
    ], workingDirectory: workspaceRoot);
    final report = <String, Object>{
      'revision': revision.exitCode == 0
          ? (revision.stdout as String).trim()
          : 'unavailable',
      'dirty':
          status.exitCode != 0 || (status.stdout as String).trim().isNotEmpty,
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'processors': Platform.numberOfProcessors,
      'dartVersion': Platform.version,
      'warmups': _warmupCount,
      'samples': _sampleCount,
      'backgroundSamples': _backgroundSampleCount,
      'captureMicros': _summarize(captureMicros),
      'synchronousPreparationMicros': _summarize(synchronousPreparationMicros),
      'backgroundPreparationMicros': _summarize(backgroundPreparationMicros),
    };
    debugPrint('CHUNK_PLAYTEST_PHASE6_PROFILE ${jsonEncode(report)}');

    expect(captureMicros, everyElement(lessThan(30000000)));
    expect(synchronousPreparationMicros, everyElement(lessThan(30000000)));
    expect(backgroundPreparationMicros, everyElement(lessThan(30000000)));
  });
}

Map<String, int> _summarize(List<int> samples) {
  final sorted = List<int>.of(samples)..sort();
  return <String, int>{
    'min': sorted.first,
    'median': _percentile(sorted, 0.5),
    'p95': _percentile(sorted, 0.95),
    'max': sorted.last,
  };
}

int _percentile(List<int> sorted, double percentile) {
  final index = ((sorted.length - 1) * percentile).ceil();
  return sorted[index];
}
