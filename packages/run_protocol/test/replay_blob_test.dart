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
      final json = Map<String, Object?>.from(blob.toJson())..remove('boardKey');
      expect(
        () => ReplayBlobV1.fromJson(json, verifyDigest: false),
        throwsArgumentError,
      );
    });

    test('explicitly rejects unsupported protocol versions', () {
      final replayVersion = Map<String, Object?>.from(
        buildSampleBlob().toJson(),
      )..['replayVersion'] = 2;
      final commandVersion = Map<String, Object?>.from(
        buildSampleBlob().toJson(),
      )..['commandEncodingVersion'] = 2;

      expect(
        () => ReplayBlobV1.fromJson(replayVersion, verifyDigest: false),
        throwsFormatException,
      );
      expect(
        () => ReplayBlobV1.fromJson(commandVersion, verifyDigest: false),
        throwsFormatException,
      );
    });

    test('explicitly rejects unknown command bits', () {
      final json = Map<String, Object?>.from(buildSampleBlob().toJson());
      final stream = (json['commandStream'] as List<Object?>).toList();
      stream[0] = Map<String, Object?>.from(stream[0] as Map)..['pm'] = 1 << 10;
      json['commandStream'] = stream;

      expect(
        () => ReplayBlobV1.fromJson(json, verifyDigest: false),
        throwsFormatException,
      );
    });

    test('explicitly rejects unpaired axes and invalid hold masks', () {
      final unpaired = Map<String, Object?>.from(buildSampleBlob().toJson());
      final unpairedStream = (unpaired['commandStream'] as List<Object?>)
          .toList();
      unpairedStream[0] = Map<String, Object?>.from(unpairedStream[0] as Map)
        ..['ax'] = 0.5;
      unpaired['commandStream'] = unpairedStream;

      final holdMask = Map<String, Object?>.from(buildSampleBlob().toJson());
      final holdStream = (holdMask['commandStream'] as List<Object?>).toList();
      holdStream[0] = Map<String, Object?>.from(holdStream[0] as Map)
        ..['hm'] = 1
        ..['hv'] = 2;
      holdMask['commandStream'] = holdStream;

      expect(
        () => ReplayBlobV1.fromJson(unpaired, verifyDigest: false),
        throwsFormatException,
      );
      expect(
        () => ReplayBlobV1.fromJson(holdMask, verifyDigest: false),
        throwsFormatException,
      );
    });

    test('explicitly rejects non-monotonic and out-of-range frame ticks', () {
      final nonMonotonic = Map<String, Object?>.from(
        buildSampleBlob().toJson(),
      );
      final nonMonotonicStream =
          (nonMonotonic['commandStream'] as List<Object?>).toList();
      nonMonotonicStream[1] = Map<String, Object?>.from(
        nonMonotonicStream[1] as Map,
      )..['t'] = 1;
      nonMonotonic['commandStream'] = nonMonotonicStream;

      final beyondTotal = Map<String, Object?>.from(buildSampleBlob().toJson());
      final beyondStream = (beyondTotal['commandStream'] as List<Object?>)
          .toList();
      beyondStream[1] = Map<String, Object?>.from(beyondStream[1] as Map)
        ..['t'] = 43;
      beyondTotal['commandStream'] = beyondStream;

      expect(
        () => ReplayBlobV1.fromJson(nonMonotonic, verifyDigest: false),
        throwsFormatException,
      );
      expect(
        () => ReplayBlobV1.fromJson(beyondTotal, verifyDigest: false),
        throwsFormatException,
      );
    });
  });
}
