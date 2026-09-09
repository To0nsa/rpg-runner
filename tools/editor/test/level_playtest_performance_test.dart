import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/shared/authored_playtest_session.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/playtest/authored_playtest_preparation.dart';

import 'test_support/chunk_level_fixture.dart';

/// Opt-in measurements use real source capture, compilation and image decoding.
/// Timing observations are not portable responsiveness or human usability gates.
void main() {
  test(
    'profiles Level preparation and cancellation with larger pools',
    () async {
      final repository = p.normalize(p.absolute('..', '..'));
      final workspace = await createChunkLevelFixture();
      final sprites = Directory(p.join(repository, 'assets/images/entities'));
      for (final source
          in sprites
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()) {
        final target = File(
          workspace.resolve(
            p.join(
              'assets/images/entities',
              p.relative(source.path, from: sprites.path),
            ),
          ),
        );
        target.parent.createSync(recursive: true);
        source.copySync(target.path);
      }
      const template = {
        'schemaVersion': 2,
        'status': 'active',
        'levelId': 'forest',
        'tileSize': 16,
        'width': 600,
        'height': 270,
        'difficulty': 'early',
        'assemblyGroupId': 'default',
        'tags': [],
        'tileLayers': [],
        'prefabs': [],
        'markers': [],
        'collisionShapes': [
          {
            'shapeId': 'ground',
            'collisionMode': 'solid',
            'vertices': [
              {'x': 0, 'y': 224},
              {'x': 600, 'y': 224},
              {'x': 600, 'y': 270},
              {'x': 0, 'y': 270},
            ],
            'surfaceKind': 'ground',
            'materialKey': 'grass_dirt',
          },
        ],
      };
      final reports = <Map<String, Object>>[];
      for (final count in [1, 25, 100]) {
        for (var index = 0; index < count; index++) {
          final key = 'profile_${index.toString().padLeft(3, '0')}';
          final source = {
            ...template,
            'chunkKey': key,
            'id': key,
            'revision': 1,
          };
          final file = File(
            workspace.resolve('assets/authoring/level/chunks/forest/$key.json'),
          );
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(jsonEncode(source));
        }
        final loadWatch = Stopwatch()..start();
        final level = await LevelDomainPlugin().loadFromRepo(
          workspace,
        ) as LevelDefsDocument;
        final content = await ChunkDomainPlugin().loadV2FromRepo(workspace);
        loadWatch.stop();
        debugPrint(
          'LEVEL_PROFILE loaded $count chunks in ${loadWatch.elapsedMilliseconds}ms',
        );
        final captures = <int>[];
        final preparations = <int>[];
        late PlaytestPreparationInput input;
        // One warmup and five observations at each pool size, with fresh capture.
        for (var sample = 0; sample < 6; sample++) {
          final watch = Stopwatch()..start();
          input = await captureLevelPlaytestPreparationInput(
            document: level,
            levelId: 'forest',
            workspaceRoot: workspace.rootPath,
            contentDocument: content,
          );
          final captureMicros = watch.elapsedMicroseconds;
          watch.reset();
          final result = await preparePlaytestInBackground(input);
          final preparationMicros = watch.elapsedMicroseconds;
          debugPrint(
            'LEVEL_PROFILE $count chunks sample $sample: capture ${captureMicros}us, prepare ${preparationMicros}us',
          );
          watch.stop();
          expect(
            result.isSuccess,
            isTrue,
            reason: result.issues.map((issue) => issue.message).join('\n'),
          );
          expect(result.assetBundle, isNotNull);
          expect(input.chunkSources, hasLength(count));
          if (sample > 0) {
            captures.add(captureMicros);
            preparations.add(preparationMicros);
          }
        }
        final session = AuthoredPlaytestSession();
        final started = Completer<void>();
        final pending = session.prepare(
          source: input,
          isSourceCurrent: () => true,
          capture: () async => input,
          runner: (captured) {
            started.complete();
            return preparePlaytestInBackground(captured);
          },
        );
        await Future.any([started.future, pending]);
        expect(started.isCompleted, isTrue);
        expect(session.mode, AuthoredPlaytestMode.preparing);
        final cancel = Stopwatch()..start();
        expect(session.stop(), isTrue);
        cancel.stop();
        expect(session.mode, AuthoredPlaytestMode.edit);
        await pending;
        expect(session.mode, AuthoredPlaytestMode.edit);
        expect(session.controller, isNull);
        expect(session.result, isNull);
        session.dispose();
        reports.add({
          'chunkCount': count,
          'loadMicros': loadWatch.elapsedMicroseconds,
          'captureMicros': _summary(captures),
          'prepareWithAssetsMicros': _summary(preparations),
          'cancelSessionMicros': cancel.elapsedMicroseconds,
          'lateCompletionDiscarded': true,
        });
      }
      debugPrint(
        'LEVEL_PLAYTEST_PHASE6_PROFILE ${jsonEncode({'os': Platform.operatingSystemVersion, 'processors': Platform.numberOfProcessors, 'dart': Platform.version, 'samplesPerSize': 5, 'warmupsPerSize': 1, 'fixture': 'Flat terrain, one group, reused material and runtime sprites', 'measurements': reports})}',
      );
    },
    skip: Platform.environment['LEVEL_EDITOR_PROFILE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Map<String, int> _summary(List<int> samples) {
  final sorted = [...samples]..sort();
  return {
    'min': sorted.first,
    'median': sorted[sorted.length ~/ 2],
    'max': sorted.last,
  };
}
