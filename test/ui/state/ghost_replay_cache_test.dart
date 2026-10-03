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
  test(
    'corrupt cached gzip is replaced only after verified decoding',
    () async {
      final directory = await Directory.systemTemp.createTemp('ghost-corrupt-');
      addTearDown(() => directory.delete(recursive: true));
      final replay = _buildReplayBlob(
        boardId: 'board_1',
        runSessionId: 'run_1',
      );
      final downloader = _FakeGhostReplayDownloader(
        payload: gzip.encode(utf8.encode(jsonEncode(replay.toJson()))),
      );
      final cache = FileGhostReplayCache(
        cacheDirectory: directory,
        downloader: downloader,
        clockMs: () => 1234,
      );
      final manifest = _manifest(
        boardId: 'board_1',
        entryId: 'entry_1',
        runSessionId: 'run_1',
        expiresAtMs: 10000,
        replayDigest: replay.canonicalSha256,
      );
      final first = await cache.loadReplay(manifest: manifest);
      await first.cachedFile.writeAsBytes([
        0x1f,
        0x8b,
        99,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        255,
      ]);
      final recovered = await cache.loadReplay(manifest: manifest);
      expect(downloader.calls, 2);
      expect(recovered.replayBlob.toJson(), replay.toJson());
      expect(await recovered.cachedFile.readAsBytes(), downloader.payload);
    },
  );

  for (final corruptGzip in [false, true]) {
    test(
      'worker rejects corrupt payload (gzip: $corruptGzip) without caching',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'ghost-invalid-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final replay = _buildReplayBlob(
          boardId: 'board_1',
          runSessionId: 'run_1',
        );
        final json = replay.toJson()..['seed'] = 999;
        final cache = FileGhostReplayCache(
          cacheDirectory: directory,
          downloader: _FakeGhostReplayDownloader(
            payload: corruptGzip
                ? [0x1f, 0x8b, 99, 0, 0, 0, 0, 0, 0, 0, 255]
                : gzip.encode(utf8.encode(jsonEncode(json))),
          ),
          clockMs: () => 1234,
        );
        await expectLater(
          cache.loadReplay(
            manifest: _manifest(
              boardId: 'board_1',
              entryId: 'entry_1',
              runSessionId: 'run_1',
              expiresAtMs: 10000,
              replayDigest: replay.canonicalSha256,
            ),
          ),
          throwsA(
            corruptGzip
                ? isA<RunStartRemoteException>()
                : isA<FormatException>(),
          ),
        );
        expect(await directory.list().toList(), isEmpty);
      },
    );
  }

  test('downloads and caches verified ghost replay blob', () async {
    final cacheDir = await Directory.systemTemp.createTemp('ghost-cache-');
    addTearDown(() => cacheDir.delete(recursive: true));
    final replayBlob = _buildReplayBlob(
      boardId: 'board_1',
      runSessionId: 'run_1',
    );
    final downloader = _FakeGhostReplayDownloader(
      payload: gzip.encode(utf8.encode(jsonEncode(replayBlob.toJson()))),
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
      replayDigest: replayBlob.canonicalSha256,
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
          replayDigest: replayBlob.canonicalSha256,
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

  test(
    'caches production-length ghost identities within filename limits',
    () async {
      final cacheDir = await Directory.systemTemp.createTemp(
        'ghost-cache-long-',
      );
      addTearDown(() => cacheDir.delete(recursive: true));
      const runId = 'run_2c067fce43a2d48b8bcc1f77b7a1b77f54aa6c69';
      final replay = _buildReplayBlob(
        boardId: _productionBoardId,
        runSessionId: runId,
      );
      final downloader = _FakeGhostReplayDownloader(
        payload: utf8.encode(jsonEncode(replay.toJson())),
      );
      final cache = FileGhostReplayCache(
        cacheDirectory: cacheDir,
        downloader: downloader,
        clockMs: () => 1234,
      );
      final manifest = _manifest(
        boardId: _productionBoardId,
        entryId: runId,
        runSessionId: runId,
        expiresAtMs: 10_000,
        replayDigest: replay.canonicalSha256,
        promotedReplayStorageGeneration: '1791010882375016',
      );

      final first = await cache.loadReplay(manifest: manifest);
      final second = await cache.loadReplay(manifest: manifest);

      expect(
        utf8.encode(first.cachedFile.uri.pathSegments.last).length,
        lessThanOrEqualTo(255),
      );
      expect(await first.cachedFile.exists(), isTrue);
      expect(second.cachedFile.path, first.cachedFile.path);
      expect(second.replayBlob.canonicalSha256, replay.canonicalSha256);
      expect(downloader.calls, 1);
    },
  );

  test(
    'republication prunes only the same full board and entry identity',
    () async {
      final cacheDir = await Directory.systemTemp.createTemp(
        'ghost-cache-prune-',
      );
      addTearDown(() => cacheDir.delete(recursive: true));
      final replay = _buildReplayBlob(
        boardId: _productionBoardId,
        runSessionId: 'run_1',
      );
      final downloader = _FakeGhostReplayDownloader(
        payload: utf8.encode(jsonEncode(replay.toJson())),
      );
      final cache = FileGhostReplayCache(
        cacheDirectory: cacheDir,
        downloader: downloader,
        clockMs: () => 1234,
      );
      GhostManifest manifest(String entryId, String generation) => _manifest(
        boardId: _productionBoardId,
        entryId: entryId,
        runSessionId: 'run_1',
        expiresAtMs: 10_000,
        replayDigest: replay.canonicalSha256,
        promotedReplayStorageGeneration: generation,
      );

      final first = await cache.loadReplay(
        manifest: manifest('entry_1', '100'),
      );
      final other = await cache.loadReplay(
        manifest: manifest('entry_2', '100'),
      );
      expect(await first.cachedFile.exists(), isTrue);

      final republished = await cache.loadReplay(
        manifest: manifest('entry_1', '101'),
      );
      expect(republished.cachedFile.path, isNot(first.cachedFile.path));
      expect(await first.cachedFile.exists(), isFalse);
      expect(await other.cachedFile.exists(), isTrue);
      expect(await republished.cachedFile.exists(), isTrue);
      await cache.loadReplay(manifest: manifest('entry_2', '100'));
      expect(downloader.calls, 3);
    },
  );

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
          replayDigest: _testReplayDigest,
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

  test('rejects replay whose digest does not match manifest', () async {
    final cacheDir = await Directory.systemTemp.createTemp(
      'ghost-cache-digest-mismatch-',
    );
    addTearDown(() => cacheDir.delete(recursive: true));
    final replayBlob = _buildReplayBlob(
      boardId: 'board_1',
      runSessionId: 'run_1',
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
          replayDigest: _testReplayDigest,
        ),
      ),
      throwsA(
        isA<RunStartRemoteException>()
            .having(
              (RunStartRemoteException e) => e.code,
              'code',
              'failed-precondition',
            )
            .having(
              (RunStartRemoteException e) => e.message,
              'message',
              'Ghost replay digest does not match manifest.',
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
    boardKey: BoardKey(
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
    commandStream: <ReplayCommandFrameV1>[
      ReplayCommandFrameV1(tick: 1, moveAxis: 1),
      ReplayCommandFrameV1(tick: 2, moveAxis: 1),
    ],
  );
}

const _testReplayDigest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

const _productionBoardId =
    'board_competitive_2026_10_forest_rules_v2_score_v3_2026_10_3_ghost_v1';

GhostManifest _manifest({
  required String boardId,
  required String entryId,
  required String runSessionId,
  required int expiresAtMs,
  required String replayDigest,
  String promotedReplayStorageGeneration = '456',
}) {
  return GhostManifest(
    boardId: boardId,
    entryId: entryId,
    runSessionId: runSessionId,
    uid: 'uid_1',
    replayStorageRef: 'ghosts/$boardId/$entryId/ghost.bin.gz',
    sourceReplayStorageRef:
        'replay-submissions/pending/uid_1/$runSessionId/replay.bin.gz',
    sourceReplayStorageGeneration: '123',
    promotedReplayStorageGeneration: promotedReplayStorageGeneration,
    replayDigest: replayDigest,
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
