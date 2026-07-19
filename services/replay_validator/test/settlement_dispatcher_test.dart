import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:replay_validator/src/settlement_dispatcher.dart';
import 'package:test/test.dart';

void main() {
  test(
    'immediate dispatcher sends validator identity and run-session id',
    () async {
      final tokens = _FakeIdentityTokenProvider();
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://settlement.example/dispatch');
        expect(request.headers['authorization'], 'Bearer validator-token');
        expect(jsonDecode(request.body), <String, Object?>{
          'runSessionId': 'run_123',
        });
        return http.Response('{"outcome":"settled"}', 200);
      });
      final dispatcher = FunctionsSettlementDispatcher(
        endpoint: Uri.parse('https://settlement.example/dispatch'),
        identityTokenProvider: tokens,
        client: client,
      );

      final outcome = await dispatcher.dispatch(runSessionId: ' run_123 ');

      expect(outcome, SettlementDispatchOutcome.settled);
      expect(tokens.audiences, <Uri>[
        Uri.parse('https://settlement.example/dispatch'),
      ]);
    },
  );

  test(
    'immediate dispatcher treats a non-success response as fallback work',
    () async {
      final dispatcher = FunctionsSettlementDispatcher(
        endpoint: Uri.parse('https://settlement.example/dispatch'),
        identityTokenProvider: _FakeIdentityTokenProvider(),
        client: MockClient((_) async => http.Response('', 409)),
      );

      await expectLater(
        dispatcher.dispatch(runSessionId: 'run_not_ready'),
        throwsA(isA<StateError>()),
      );
    },
  );
}

class _FakeIdentityTokenProvider implements IdentityTokenProvider {
  final List<Uri> audiences = <Uri>[];

  @override
  Future<String> tokenForAudience(Uri audience) async {
    audiences.add(audience);
    return 'validator-token';
  }
}
