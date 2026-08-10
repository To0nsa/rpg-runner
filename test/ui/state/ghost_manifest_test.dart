import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/ui/state/boards/ghost_api.dart';

void main() {
  test('parses required ghost integrity lineage', () {
    final manifest = GhostManifest.fromJson(_manifestJson());

    expect(manifest.sourceReplayStorageGeneration, '123');
    expect(manifest.promotedReplayStorageGeneration, '456');
    expect(
      manifest.replayDigest,
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
  });

  test('rejects malformed promoted generation and replay digest', () {
    final malformedGeneration = _manifestJson()
      ..['promotedReplayStorageGeneration'] = '0';
    final malformedDigest = _manifestJson()..['replayDigest'] = 'not-a-digest';

    expect(
      () => GhostManifest.fromJson(malformedGeneration),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => GhostManifest.fromJson(malformedDigest),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a replay reference outside the ghost publication prefix', () {
    final malformedPath = _manifestJson()
      ..['replayStorageRef'] = 'replay-submissions/run_1/replay.json';

    expect(
      () => GhostManifest.fromJson(malformedPath),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, Object?> _manifestJson() => <String, Object?>{
  'boardId': 'board_1',
  'entryId': 'entry_1',
  'runSessionId': 'run_1',
  'uid': 'uid_1',
  'replayStorageRef': 'ghosts/board_1/entry_1/ghost.bin.gz',
  'sourceReplayStorageRef': 'replay-submissions/validated/run_1.bin.gz',
  'sourceReplayStorageGeneration': '123',
  'promotedReplayStorageGeneration': '456',
  'replayDigest':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'downloadUrl': 'https://example.test/ghosts/board_1/entry_1/ghost.bin.gz',
  'downloadUrlExpiresAtMs': 1_700_000_000_000,
  'score': 1200,
  'distanceMeters': 420,
  'durationSeconds': 120,
  'sortKey': '0000000001:0000000001:0000000120:entry_1',
  'rank': 1,
  'updatedAtMs': 1_700_000_000_000,
};
