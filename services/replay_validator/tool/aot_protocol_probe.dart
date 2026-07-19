import 'package:run_protocol/replay_blob.dart';

void main() {
  final valid = ReplayBlobV1.withComputedDigest(
    runSessionId: 'aot-protocol-probe',
    tickHz: 60,
    seed: 1,
    levelId: 'field',
    playerCharacterId: 'eloise',
    loadoutSnapshot: const <String, Object?>{},
    totalTicks: 1,
    commandStream: const <ReplayCommandFrameV1>[ReplayCommandFrameV1(tick: 1)],
  ).toJson();

  _expectRejected(<String, Object?>{...valid, 'replayVersion': 999});
  _expectRejected(<String, Object?>{...valid, 'commandEncodingVersion': 999});
  _expectRejected(<String, Object?>{
    ...valid,
    'commandStream': <Object?>[
      <String, Object?>{'t': 1, 'pm': 1 << 30},
    ],
  });
}

void _expectRejected(Map<String, Object?> replay) {
  try {
    ReplayBlobV1.fromJson(replay, verifyDigest: false);
  } on FormatException {
    return;
  }
  throw StateError('Malformed replay was accepted by the AOT protocol probe.');
}
