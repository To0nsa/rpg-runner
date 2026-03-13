import 'package:run_protocol/run_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('RunTicket', () {
    test('practice ticket is boardless', () {
      final ticket = RunTicket(
        runSessionId: 'run_01',
        uid: 'u_01',
        mode: RunMode.practice,
        seed: 7,
        tickHz: 60,
        gameCompatVersion: '1.0.0',
        levelId: 'field',
        playerCharacterId: 'eloise',
        loadoutSnapshot: const <String, Object?>{'mainWeapon': 'plainsteel'},
        loadoutDigest: 'abc123',
        issuedAtMs: 10,
        expiresAtMs: 20,
        singleUseNonce: 'nonce_1',
      );

      expect(ticket.boardId, isNull);
      expect(ticket.boardKey, isNull);
    });

    test('practice ticket rejects board fields', () {
      expect(
        () => RunTicket(
          runSessionId: 'run_01',
          uid: 'u_01',
          mode: RunMode.practice,
          boardId: 'board_01',
          seed: 7,
          tickHz: 60,
          gameCompatVersion: '1.0.0',
          levelId: 'field',
          playerCharacterId: 'eloise',
          loadoutSnapshot: const <String, Object?>{'mainWeapon': 'plainsteel'},
          loadoutDigest: 'abc123',
          issuedAtMs: 10,
          expiresAtMs: 20,
          singleUseNonce: 'nonce_1',
        ),
        throwsArgumentError,
      );
    });

    test('competitive ticket requires board fields', () {
      expect(
        () => RunTicket(
          runSessionId: 'run_01',
          uid: 'u_01',
          mode: RunMode.competitive,
          seed: 7,
          tickHz: 60,
          gameCompatVersion: '1.0.0',
          levelId: 'field',
          playerCharacterId: 'eloise',
          loadoutSnapshot: const <String, Object?>{
            'mainWeapon': 'plainsteel',
          },
          loadoutDigest: 'abc123',
          issuedAtMs: 10,
          expiresAtMs: 20,
          singleUseNonce: 'nonce_1',
        ),
        throwsArgumentError,
      );
    });
  });
}
