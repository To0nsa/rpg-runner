import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:run_protocol/run_mode.dart';

import 'package:rpg_runner/ui/state/boards/ghost_api.dart';
import 'package:rpg_runner/ui/state/boards/ghost_replay_cache.dart';
import 'package:rpg_runner/ui/state/run/run_start_remote_exception.dart';

void main() {
  test('downloads and caches verified ghost replay blob', () async {
    final cacheDir = await Directory.systemTemp.createTemp('ghost-cache-');
    addTearDown(() => cacheDir.delete(recursive: true));
    final replayBlob = _buildReplayBlob(
      boardId: 'board_1',
      runSessionId: 'run_1',
    );
    final downloader = _FakeGhostReplayDownloader(
      payload: utf8.encode(jsonEncode(replayBlob.toJson())),
    );
    final cache = FileGhostReplayCache(
      cacheDirectory: cacheDir,
      downloader: downloader,
      clockMs: () => 1234,
    );
    final manifest = _manifest(
      boardId: 'board_1',
      entryId: 'entry_1',
      runSessionId: 'run_1',
      expiresAtMs: 10_000,
    );

    final first = await cache.loadReplay(manifest: manifest);
    final second = await cache.loadReplay(manifest: manifest);

    expect(downloader.calls, 1);
    expect(first.replayBlob.runSessionId, 'run_1');
    expect(second.replayBlob.canonicalSha256, first.replayBlob.canonicalSha256);
    expect(await first.cachedFile.exists(), isTrue);
  });

  test('rejects replay that does not match manifest board/session', () async {
    final cacheDir = await Directory.systemTemp.createTemp(
      'ghost-cache-mismatch-',
    );
    addTearDown(() => cacheDir.delete(recursive: true));
    final replayBlob = _buildReplayBlob(
      boardId: 'board_2',
      runSessionId: 'run_2',
    );
    final cache = FileGhostReplayCache(
      cacheDirectory: cacheDir,
      downloader: _FakeGhostReplayDownloader(
        payload: utf8.encode(jsonEncode(replayBlob.toJson())),
      ),
      clockMs: () => 1234,
    );

    await expectLater(
      () => cache.loadReplay(
        manifest: _manifest(
          boardId: 'board_1',
          entryId: 'entry_1',
          runSessionId: 'run_1',
          expiresAtMs: 10_000,
        ),
      ),
      throwsA(
        isA<RunStartRemoteException>().having(
          (RunStartRemoteException e) => e.code,
          'code',
          'failed-precondition',
        ),
      ),
    );
  });

  test('rejects expired manifest download URL when no cache exists', () async {
    final cacheDir = await Directory.systemTemp.createTemp(
      'ghost-cache-expired-',
    );
    addTearDown(() => cacheDir.delete(recursive: true));
    final cache = FileGhostReplayCache(
      cacheDirectory: cacheDir,
      downloader: _FakeGhostReplayDownloader(payload: const <int>[]),
      clockMs: () => 10_000,
    );

    await expectLater(
      () => cache.loadReplay(
        manifest: _manifest(
          boardId: 'board_1',
          entryId: 'entry_1',
          runSessionId: 'run_1',
          expiresAtMs: 9_999,
        ),
      ),
      throwsA(
        isA<RunStartRemoteException>().having(
          (RunStartRemoteException e) => e.code,
          'code',
          'failed-precondition',
        ),
      ),
    );
  });
}

ReplayBlobV1 _buildReplayBlob({
  required String boardId,
  required String runSessionId,
}) {
  return ReplayBlobV1.withComputedDigest(
    runSessionId: runSessionId,
    boardId: boardId,
    boardKey: const BoardKey(
      mode: RunMode.competitive,
      levelId: 'field',
      windowId: '2026-03',
      rulesetVersion: 'rules-v1',
      scoreVersion: 'score-v1',
    ),
    tickHz: 60,
    seed: 42,
    levelId: 'field',
    playerCharacterId: 'eloise',
    loadoutSnapshot: const <String, Object?>{
      'mask': 0,
      'mainWeaponId': 'debugSword',
      'offhandWeaponId': 'none',
      'spellBookId': 'emptyBook',
      'projectileSlotSpellId': 'iceBolt',
      'accessoryId': 'none',
      'abilityPrimaryId': 'slash',
      'abilitySecondaryId': 'parry',
      'abilityProjectileId': 'projectileBasic',
      'abilitySpellId': 'spellBasic',
      'abilityMobilityId': 'dash',
      'abilityJumpId': 'jump',
    },
    totalTicks: 2,
    commandStream: const <ReplayCommandFrameV1>[
      ReplayCommandFrameV1(tick: 1, moveAxis: 1),
      ReplayCommandFrameV1(tick: 2, moveAxis: 1),
    ],
  );
}

GhostManifest _manifest({
  required String boardId,
  required String entryId,
  required String runSessionId,
  required int expiresAtMs,
}) {
  return GhostManifest(
    boardId: boardId,
    entryId: entryId,
    runSessionId: runSessionId,
    uid: 'uid_1',
    replayStorageRef: 'ghosts/$boardId/$entryId/ghost.bin.gz',
    sourceReplayStorageRef:
        'replay-submissions/pending/uid_1/$runSessionId/replay.bin.gz',
    downloadUrl: 'https://example.test/ghosts/$boardId/$entryId/ghost.bin.gz',
    downloadUrlExpiresAtMs: expiresAtMs,
    score: 1200,
    distanceMeters: 420,
    durationSeconds: 120,
    sortKey: '0000000001:0000000001:0000000120:$entryId',
    rank: 1,
    updatedAtMs: 1_700_000_000_000,
  );
}

class _FakeGhostReplayDownloader implements GhostReplayDownloader {
  _FakeGhostReplayDownloader({required this.payload});

  final List<int> payload;
  int calls = 0;

  @override
  Future<List<int>> downloadBytes({required Uri url}) async {
    calls += 1;
    return List<int>.from(payload);
  }
}
