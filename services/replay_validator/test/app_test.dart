import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:replay_validator/replay_validator.dart';
import 'package:replay_validator/src/settlement_dispatcher.dart';

void main() {
  test('durable event delivery is the default even with a rollback URL', () {
    final app = ReplayValidatorApp.fromEnvironment({
      'GCLOUD_PROJECT': 'demo',
      'REPLAY_STORAGE_BUCKET': 'bucket',
      'SETTLEMENT_DISPATCH_URL': 'https://example.test/settle',
    });
    final worker = app.worker as DeterministicValidatorWorker;
    expect(worker.settlementDispatcher, isA<NoopSettlementDispatcher>());
  });

  test('immediate settlement is an explicit rollback mode', () {
    final app = ReplayValidatorApp.fromEnvironment({
      'GCLOUD_PROJECT': 'demo',
      'REPLAY_STORAGE_BUCKET': 'bucket',
      'SETTLEMENT_DELIVERY_MODE': 'immediate',
      'SETTLEMENT_DISPATCH_URL': 'https://example.test/settle',
    });
    expect(
      (app.worker as DeterministicValidatorWorker).settlementDispatcher,
      isA<FunctionsSettlementDispatcher>(),
    );
  });

  test('invalid delivery configuration fails startup', () {
    for (final extra in [
      {'SETTLEMENT_DELIVERY_MODE': 'unknown'},
      {'SETTLEMENT_DELIVERY_MODE': 'immediate'},
      {
        'SETTLEMENT_DELIVERY_MODE': 'immediate',
        'SETTLEMENT_DISPATCH_URL': 'http://example.test',
      },
    ]) {
      expect(
        () => ReplayValidatorApp.fromEnvironment({
          'GCLOUD_PROJECT': 'demo',
          'REPLAY_STORAGE_BUCKET': 'bucket',
          ...extra,
        }),
        throwsFormatException,
      );
    }
  });

  test('live returns ok payload', () async {
    final app = ReplayValidatorApp(
      port: 8080,
      worker: _FakeWorker(
        result: const ValidationDispatchResult.notImplemented(),
      ),
    );

    final response = await app.handler(
      Request('GET', Uri.parse('http://localhost/live')),
    );
    final payload = jsonDecode(await response.readAsString()) as Map;

    expect(response.statusCode, 200);
    expect(payload['status'], 'ok');
    expect(payload['service'], 'replay-validator');
  });

  test('ready fails closed when workers are not configured', () async {
    final app = ReplayValidatorApp(port: 8080);

    final response = await app.handler(
      Request('GET', Uri.parse('http://localhost/ready')),
    );
    final payload = jsonDecode(await response.readAsString()) as Map;

    expect(response.statusCode, 503);
    expect(payload['status'], 'not_ready');
  });

  test(
    'ready succeeds when validation and projection are configured',
    () async {
      final app = ReplayValidatorApp(
        port: 8080,
        worker: _FakeWorker(result: const ValidationDispatchResult.accepted()),
        projectionWorker: _FakeProjectionWorker(
          result: const ProjectionDispatchResult.completed(),
        ),
      );

      final response = await app.handler(
        Request('GET', Uri.parse('http://localhost/ready')),
      );
      final payload = jsonDecode(await response.readAsString()) as Map;

      expect(response.statusCode, 200);
      expect(payload['status'], 'ready');
    },
  );

  test('invalid configured replay limit fails startup', () {
    expect(
      () => ReplayValidatorApp.fromEnvironment(<String, String>{
        'GCLOUD_PROJECT': 'demo',
        'REPLAY_STORAGE_BUCKET': 'bucket',
        'VALIDATOR_MAX_JSON_NESTING_DEPTH': '0',
      }),
      throwsFormatException,
    );
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
      worker: _FakeWorker(result: const ValidationDispatchResult.accepted()),
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

  test(
    'projection endpoint asks Cloud Tasks to retry optional projection work',
    () async {
      final app = ReplayValidatorApp(
        port: 8080,
        worker: _FakeWorker(
          result: const ValidationDispatchResult.notImplemented(),
        ),
        projectionWorker: _FakeProjectionWorker(
          result: const ProjectionDispatchResult.retryScheduled(),
        ),
      );

      final response = await app.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/tasks/project'),
          body: jsonEncode(<String, Object?>{'runSessionId': 'run_board_1'}),
        ),
      );
      final payload = jsonDecode(await response.readAsString()) as Map;

      expect(response.statusCode, 503);
      expect(payload['status'], ProjectionDispatchStatus.retryScheduled.name);
    },
  );

  test('unconfigured projection endpoint remains retryable', () async {
    final app = ReplayValidatorApp(port: 8080);

    final response = await app.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/tasks/project'),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, Object?>{'runSessionId': 'run_123'}),
      ),
    );

    expect(response.statusCode, 503);
  });

  test('projection endpoint accepts scheduled board reconciliation', () async {
    final projectionWorker = _FakeProjectionWorker(
      result: const ProjectionDispatchResult.completed(),
    );
    final app = ReplayValidatorApp(
      port: 8080,
      worker: _FakeWorker(result: const ValidationDispatchResult.accepted()),
      projectionWorker: projectionWorker,
    );

    final response = await app.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/tasks/project'),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, Object?>{'boardId': 'board_1'}),
      ),
    );

    expect(response.statusCode, 200);
    expect(projectionWorker.boardIds, <String>['board_1']);
  });
}

class _FakeWorker implements ValidatorWorker {
  const _FakeWorker({required this.result});

  final ValidationDispatchResult result;

  @override
  Future<ValidationDispatchResult> validateRunSession({
    required String runSessionId,
  }) async {
    return result;
  }
}

class _FakeProjectionWorker implements ProjectionWorker {
  _FakeProjectionWorker({required this.result});

  final ProjectionDispatchResult result;
  final List<String> boardIds = <String>[];

  @override
  Future<ProjectionDispatchResult> projectRunSession({
    required String runSessionId,
  }) async => result;

  @override
  Future<ProjectionDispatchResult> reconcileBoard({
    required String boardId,
  }) async {
    boardIds.add(boardId);
    return result;
  }
}
