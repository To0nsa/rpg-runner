import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:replay_validator/replay_validator.dart';

void main() {
  test('healthz returns ok payload', () async {
    final app = ReplayValidatorApp(
      port: 8080,
      worker: _FakeWorker(
        result: const ValidationDispatchResult.notImplemented(),
      ),
    );

    final response = await app.handler(
      Request('GET', Uri.parse('http://localhost/healthz')),
    );
    final payload = jsonDecode(await response.readAsString()) as Map;

    expect(response.statusCode, 200);
    expect(payload['status'], 'ok');
    expect(payload['service'], 'replay-validator');
  });

  test('validate endpoint rejects missing runSessionId', () async {
    final app = ReplayValidatorApp(
      port: 8080,
      worker: _FakeWorker(
        result: const ValidationDispatchResult.notImplemented(),
      ),
    );

    final response = await app.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/tasks/validate'),
        body: jsonEncode(<String, Object?>{'data': <String, Object?>{}}),
      ),
    );
    final payload = jsonDecode(await response.readAsString()) as Map;

    expect(response.statusCode, 400);
    expect(payload['error'], 'invalid_request');
  });

  test('validate endpoint fails closed by default', () async {
    final app = ReplayValidatorApp.fromEnvironment();

    final response = await app.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/tasks/validate'),
        body: jsonEncode(<String, Object?>{'runSessionId': 'run_123'}),
      ),
    );
    final payload = jsonDecode(await response.readAsString()) as Map;

    expect(response.statusCode, 501);
    expect(payload['status'], ValidationDispatchStatus.notImplemented.name);
  });

  test('validate endpoint returns accepted when worker accepts task', () async {
    final app = ReplayValidatorApp(
      port: 8080,
      worker: _FakeWorker(
        result: const ValidationDispatchResult.accepted(),
      ),
    );

    final response = await app.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/tasks/validate'),
        body: jsonEncode(<String, Object?>{
          'data': <String, Object?>{'runSessionId': 'run_accepted'},
        }),
      ),
    );
    final payload = jsonDecode(await response.readAsString()) as Map;

    expect(response.statusCode, 202);
    expect(payload['runSessionId'], 'run_accepted');
    expect(payload['status'], ValidationDispatchStatus.accepted.name);
  });
}

class _FakeWorker implements ValidatorWorker {
  const _FakeWorker({
    required this.result,
  });

  final ValidationDispatchResult result;

  @override
  Future<ValidationDispatchResult> validateRunSession({
    required String runSessionId,
  }) async {
    return result;
  }
}

