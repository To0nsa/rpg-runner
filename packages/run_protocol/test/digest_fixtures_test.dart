import 'dart:convert';
import 'dart:io';

import 'package:run_protocol/codecs/canonical_json_codec.dart';
import 'package:run_protocol/run_protocol.dart';
import 'package:test/test.dart';

Object? fixture(String name) {
  final packagePath = Directory('packages/run_protocol').existsSync()
      ? 'packages/run_protocol/'
      : '';
  return jsonDecode(
    File('${packagePath}test/fixtures/$name.json').readAsStringSync(),
  );
}

void main() {
  final loadouts = fixture('loadout_digest_v1')! as Map<String, dynamic>;
  for (final value in loadouts['valid'] as List) {
    final sample = value as Map<String, dynamic>;
    test('shared loadout fixture: ${sample['name']}', () {
      final input = sample['input'] as Map<String, dynamic>;
      expect(LoadoutDigest.canonicalJson(input), sample['canonicalJson']);
      expect(LoadoutDigest.sha256ForMap(input), sample['sha256']);
    });
  }
  for (final value in loadouts['invalid'] as List) {
    final sample = value as Map<String, dynamic>;
    test('shared loadout rejection: ${sample['name']}', () {
      expect(
        () =>
            LoadoutDigest.sha256ForMap(sample['input'] as Map<String, dynamic>),
        throwsArgumentError,
      );
    });
  }
  test('loadout rejects non-JSON values and non-finite numbers', () {
    for (final value in <Object?>[
      double.nan,
      double.infinity,
      Object(),
      {1: 'x'},
    ]) {
      expect(
        () => LoadoutDigest.sha256ForMap({'x': value}),
        throwsArgumentError,
      );
    }
  });

  for (final value in fixture('replay_v1')! as List) {
    final sample = value as Map<String, dynamic>;
    test('replay-v1 historical bytes and digest: ${sample['name']}', () {
      final replay = ReplayBlobV1.fromJson(sample['replay']);
      expect(
        canonicalJsonEncode(replay.toCanonicalPayloadJson()),
        sample['canonicalJson'],
      );
      expect(replay.canonicalSha256, sample['sha256']);
      final rebuilt = ReplayBlobV1.withComputedDigest(
        runSessionId: replay.runSessionId,
        tickHz: replay.tickHz,
        seed: replay.seed,
        levelId: replay.levelId,
        playerCharacterId: replay.playerCharacterId,
        loadoutSnapshot: replay.loadoutSnapshot,
        totalTicks: replay.totalTicks,
        commandStream: replay.commandStream,
        boardId: replay.boardId,
        boardKey: replay.boardKey,
        clientSummary: replay.clientSummary,
      );
      expect(rebuilt.canonicalSha256, sample['sha256']);
      final wireRoundTrip = ReplayBlobV1.fromJson(
        jsonDecode(jsonEncode(rebuilt.toJson())),
      );
      expect(wireRoundTrip.canonicalSha256, sample['sha256']);
    });
  }
}
