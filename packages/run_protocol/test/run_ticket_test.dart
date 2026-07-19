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
          loadoutSnapshot: const <String, Object?>{'mainWeapon': 'plainsteel'},
          loadoutDigest: 'abc123',
          issuedAtMs: 10,
          expiresAtMs: 20,
          singleUseNonce: 'nonce_1',
        ),
        throwsArgumentError,
      );
    });

    test('competitive ticket carries an immutable board window', () {
      final ticket = RunTicket(
        runSessionId: 'run_01',
        uid: 'u_01',
        mode: RunMode.competitive,
        boardId: 'board_01',
        boardKey: const BoardKey(
          mode: RunMode.competitive,
          levelId: 'field',
          windowId: '2026-07',
          rulesetVersion: 'rules-v1',
          scoreVersion: 'score-v1',
        ),
        seed: 7,
        tickHz: 60,
        gameCompatVersion: '2026.03.0',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
        ghostVersion: 'ghost-v1',
        boardOpensAtMs: 100,
        boardClosesAtMs: 200,
        levelId: 'field',
        playerCharacterId: 'eloise',
        loadoutSnapshot: const <String, Object?>{'mainWeapon': 'plainsteel'},
        loadoutDigest: 'abc123',
        issuedAtMs: 110,
        expiresAtMs: 120,
        singleUseNonce: 'nonce_1',
      );

      final decoded = RunTicket.fromJson(ticket.toJson());

      expect(decoded.boardOpensAtMs, 100);
      expect(decoded.boardClosesAtMs, 200);
    });
  });
}
