import 'package:run_protocol/run_protocol.dart';
import 'package:test/test.dart';

void main() {
  const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('runtime contract invariants', () {
    test('rejects invalid direct replay and board construction', () {
      expect(() => ReplayCommandFrameV1(tick: 0), throwsArgumentError);
      expect(
        () => ReplayCommandFrameV1(tick: 1, moveAxis: 1.1),
        throwsArgumentError,
      );
      expect(
        () => BoardKey(
          mode: RunMode.practice,
          levelId: 'field',
          windowId: '2026-07',
          rulesetVersion: 'rules-v1',
          scoreVersion: 'score-v1',
        ),
        throwsArgumentError,
      );
      expect(
        () => BoardManifest(
          boardId: 'board_1',
          boardKey: BoardKey(
            mode: RunMode.competitive,
            levelId: 'field',
            windowId: '2026-07',
            rulesetVersion: 'rules-v1',
            scoreVersion: 'score-v1',
          ),
          gameCompatVersion: '2026.03.0',
          ghostVersion: 'ghost-v1',
          tickHz: 0,
          seed: 1,
          opensAtMs: 100,
          closesAtMs: 200,
          status: BoardStatus.active,
        ),
        throwsArgumentError,
      );
      expect(
        () => ReplayBlobV1.withComputedDigest(
          runSessionId: 'run_1',
          tickHz: 60,
          seed: 1,
          levelId: 'field',
          playerCharacterId: 'eloise',
          loadoutSnapshot: const <String, Object?>{},
          totalTicks: 0,
          commandStream: const <ReplayCommandFrameV1>[],
          replayVersion: 2,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid direct leaderboard and submission construction', () {
      expect(
        () => LeaderboardEntry(
          boardId: 'board_1',
          entryId: 'entry_1',
          runSessionId: 'run_1',
          uid: 'user_1',
          displayName: 'Player',
          characterId: 'eloise',
          score: -1,
          distanceMeters: 1,
          durationSeconds: 1,
          sortKey: '0000000000:0000000000:0000000001:entry_1',
          ghostEligible: false,
          updatedAtMs: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => SubmissionReward(
          status: SubmissionRewardStatus.provisional,
          provisionalGold: -1,
          effectiveGoldDelta: 0,
          spendableGoldDelta: 0,
          updatedAtMs: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => SubmissionStatus(
          runSessionId: 'run_1',
          state: RunSessionState.issued,
          updatedAtMs: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => ValidatedRun(
          runSessionId: 'run_1',
          uid: 'user_1',
          mode: RunMode.practice,
          accepted: false,
          score: 0,
          distanceMeters: 0,
          durationSeconds: 0,
          tick: 0,
          endedReason: 'rejected',
          goldEarned: 0,
          stats: const <String, Object?>{},
          replayDigest: digest,
          replayStorageRef: 'runs/run_1/replay.json',
          createdAtMs: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('digest-bound JSON values', () {
    test(
      'replay snapshots are insulated from source and serialized-map mutation',
      () {
        final source = <String, Object?>{
          'loadout': <String, Object?>{'weapon': 'plainsteel'},
          'slots': <Object?>['primary'],
        };
        final clientSummary = <String, Object?>{
          'stats': <String, Object?>{'kills': 3},
        };
        final frames = <ReplayCommandFrameV1>[ReplayCommandFrameV1(tick: 1)];
        final replay = ReplayBlobV1.withComputedDigest(
          runSessionId: 'run_1',
          tickHz: 60,
          seed: 1,
          levelId: 'field',
          playerCharacterId: 'eloise',
          loadoutSnapshot: source,
          totalTicks: 1,
          commandStream: frames,
          clientSummary: clientSummary,
        );

        (source['loadout']! as Map<String, Object?>)['weapon'] = 'tampered';
        (source['slots']! as List<Object?>).add('secondary');
        (clientSummary['stats']! as Map<String, Object?>)['kills'] = 0;
        frames.add(ReplayCommandFrameV1(tick: 2));
        expect(replay.hasValidDigest, isTrue);

        final encoded = replay.toJson();
        final encodedLoadout =
            encoded['loadoutSnapshot']! as Map<String, Object?>;
        (encodedLoadout['loadout']! as Map<String, Object?>)['weapon'] =
            'tampered';
        (encodedLoadout['slots']! as List<Object?>).add('secondary');
        final encodedSummary =
            encoded['clientSummary']! as Map<String, Object?>;
        (encodedSummary['stats']! as Map<String, Object?>)['kills'] = 0;

        expect(replay.hasValidDigest, isTrue);
        expect(replay.commandStream, hasLength(1));
        expect(
          (replay.loadoutSnapshot['loadout']!
              as Map<String, Object?>)['weapon'],
          'plainsteel',
        );
        expect(
          (replay.clientSummary!['stats']! as Map<String, Object?>)['kills'],
          3,
        );
      },
    );

    test(
      'run tickets reject mismatched board identity and retain snapshots',
      () {
        final snapshot = <String, Object?>{'mask': 7};
        final ticket = RunTicket(
          runSessionId: 'run_1',
          uid: 'user_1',
          mode: RunMode.competitive,
          boardId: 'board_1',
          boardKey: BoardKey(
            mode: RunMode.competitive,
            levelId: 'field',
            windowId: '2026-07',
            rulesetVersion: 'rules-v1',
            scoreVersion: 'score-v1',
          ),
          seed: 1,
          tickHz: 60,
          gameCompatVersion: '2026.03.0',
          rulesetVersion: 'rules-v1',
          scoreVersion: 'score-v1',
          ghostVersion: 'ghost-v1',
          levelId: 'field',
          playerCharacterId: 'eloise',
          loadoutSnapshot: snapshot,
          loadoutDigest: ReplayDigest.canonicalSha256ForMap(snapshot),
          issuedAtMs: 1,
          expiresAtMs: 2,
          singleUseNonce: 'nonce_1',
        );

        snapshot['mask'] = 0;
        final encodedTicket = ticket.toJson();
        (encodedTicket['loadoutSnapshot']! as Map<String, Object?>)['mask'] = 0;
        expect(ticket.loadoutSnapshot['mask'], 7);
        expect(
          () => RunTicket(
            runSessionId: 'run_1',
            uid: 'user_1',
            mode: RunMode.competitive,
            boardId: 'board_1',
            boardKey: BoardKey(
              mode: RunMode.weekly,
              levelId: 'field',
              windowId: '2026-07',
              rulesetVersion: 'rules-v1',
              scoreVersion: 'score-v1',
            ),
            seed: 1,
            tickHz: 60,
            gameCompatVersion: '2026.03.0',
            rulesetVersion: 'rules-v1',
            scoreVersion: 'score-v1',
            ghostVersion: 'ghost-v1',
            levelId: 'field',
            playerCharacterId: 'eloise',
            loadoutSnapshot: const <String, Object?>{'mask': 7},
            loadoutDigest: digest,
            issuedAtMs: 1,
            expiresAtMs: 2,
            singleUseNonce: 'nonce_1',
          ),
          throwsArgumentError,
        );
      },
    );

    test('validated runs retain detached stats', () {
      final stats = <String, Object?>{
        'enemies': <String, Object?>{'defeated': 3},
      };
      final run = ValidatedRun(
        runSessionId: 'run_1',
        uid: 'user_1',
        mode: RunMode.practice,
        accepted: true,
        score: 1,
        distanceMeters: 1,
        durationSeconds: 1,
        tick: 1,
        endedReason: 'completed',
        goldEarned: 1,
        stats: stats,
        replayDigest: digest,
        replayStorageRef: 'runs/run_1/replay.json',
        createdAtMs: 1,
      );

      (stats['enemies']! as Map<String, Object?>)['defeated'] = 0;
      final encoded = run.toJson();
      ((encoded['stats']! as Map<String, Object?>)['enemies']!
              as Map<String, Object?>)['defeated'] =
          0;

      expect((run.stats['enemies']! as Map<String, Object?>)['defeated'], 3);
    });
  });
}
