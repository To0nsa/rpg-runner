import 'package:run_protocol/run_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ReplayBlobV1', () {
    ReplayBlobV1 buildSampleBlob() {
      return ReplayBlobV1.withComputedDigest(
        runSessionId: 'run_01',
        boardId: 'board_01',
        boardKey: const BoardKey(
          mode: RunMode.competitive,
          levelId: 'field',
          windowId: '2026-03',
          rulesetVersion: 'r1',
          scoreVersion: 's1',
        ),
        tickHz: 60,
        seed: 123,
        levelId: 'field',
        playerCharacterId: 'eloise',
        loadoutSnapshot: const <String, Object?>{
          'weapon': 'plainsteel',
          'ability': 'eloise.seeker_slash',
        },
        totalTicks: 42,
        commandStream: const <ReplayCommandFrameV1>[
          ReplayCommandFrameV1(
            tick: 1,
            moveAxis: 1.0,
            pressedMask: ReplayCommandFrameV1.pressedJumpBit,
          ),
          ReplayCommandFrameV1(
            tick: 2,
            aimDirX: 1.0,
            aimDirY: 0.0,
            pressedMask: ReplayCommandFrameV1.pressedStrikeBit,
            abilitySlotHeldChangedMask: 2,
            abilitySlotHeldValueMask: 2,
          ),
        ],
      );
    }

    test('encodes and decodes with stable digest', () {
      final blob = buildSampleBlob();
      final decoded = ReplayBlobV1.fromJson(blob.toJson());

      expect(decoded.runSessionId, 'run_01');
      expect(decoded.tickHz, 60);
      expect(decoded.commandStream.length, 2);
      expect(decoded.hasValidDigest, isTrue);
      expect(decoded.canonicalSha256, blob.canonicalSha256);
    });

    test('same payload yields same canonical digest', () {
      final a = buildSampleBlob();
      final b = buildSampleBlob();
      expect(a.canonicalSha256, b.canonicalSha256);
    });

    test('rejects payload when digest does not match', () {
      final blob = buildSampleBlob();
      final tampered = Map<String, Object?>.from(blob.toJson());
      final stream = (tampered['commandStream'] as List<Object?>).toList();
      final frame0 = Map<String, Object?>.from(stream.first as Map);
      frame0['mx'] = -1.0;
      stream[0] = frame0;
      tampered['commandStream'] = stream;

      expect(
        () => ReplayBlobV1.fromJson(tampered),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects boardId/boardKey mismatch', () {
      final blob = buildSampleBlob();
      final json = Map<String, Object?>.from(blob.toJson())
        ..remove('boardKey');
      expect(
        () => ReplayBlobV1.fromJson(json, verifyDigest: false),
        throwsArgumentError,
      );
    });
  });
}
