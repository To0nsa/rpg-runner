import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'board_repository.dart';
import 'ghost_publisher.dart';
import 'leaderboard_projector.dart';
import 'metrics.dart';
import 'replay_loader.dart';
import 'reward_grant_writer.dart';
import 'run_session_repository.dart';
import 'validator_worker.dart';

class ReplayValidatorApp {
  ReplayValidatorApp({
    required this.port,
    ValidatorWorker? worker,
  }) : worker =
           worker ??
           StubValidatorWorker(
             replayLoader: UnimplementedReplayLoader(),
             boardRepository: NoopBoardRepository(),
             runSessionRepository: NoopRunSessionRepository(),
             leaderboardProjector: NoopLeaderboardProjector(),
             rewardGrantWriter: NoopRewardGrantWriter(),
             ghostPublisher: NoopGhostPublisher(),
             metrics: ConsoleValidatorMetrics(),
           );

  factory ReplayValidatorApp.fromEnvironment() {
    final rawPort = Platform.environment['PORT'];
    final parsedPort = int.tryParse(rawPort ?? '');
    return ReplayValidatorApp(port: parsedPort ?? 8080);
  }

  final int port;
  final ValidatorWorker worker;

  Handler get handler {
    final router = Router()
      ..get('/healthz', _healthz)
      ..post('/tasks/validate', _validateTask);

    return Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);
  }

  Future<Response> _healthz(Request request) async {
    return _json(
      HttpStatus.ok,
      <String, Object?>{
        'status': 'ok',
        'service': 'replay-validator',
      },
    );
  }

  Future<Response> _validateTask(Request request) async {
    final decoded = await _decodeBody(request);
    final runSessionId = _extractRunSessionId(decoded);
    if (runSessionId == null) {
      return _json(
        HttpStatus.badRequest,
        const <String, Object?>{
          'error': 'invalid_request',
          'message': 'Expected non-empty runSessionId in body.',
        },
      );
    }

    final result = await worker.validateRunSession(runSessionId: runSessionId);
    final statusCode = switch (result.status) {
      ValidationDispatchStatus.accepted => HttpStatus.accepted,
      ValidationDispatchStatus.rejected => HttpStatus.ok,
      ValidationDispatchStatus.badRequest => HttpStatus.badRequest,
      ValidationDispatchStatus.notImplemented => HttpStatus.notImplemented,
    };
    return _json(
      statusCode,
      <String, Object?>{
        'runSessionId': runSessionId,
        'status': result.status.name,
        if (result.message != null) 'message': result.message,
      },
    );
  }

  Future<Object?> _decodeBody(Request request) async {
    final body = await request.readAsString();
    if (body.trim().isEmpty) {
      return const <String, Object?>{};
    }
    try {
      return jsonDecode(body);
    } on FormatException {
      return const <String, Object?>{};
    }
  }

  String? _extractRunSessionId(Object? decoded) {
    if (decoded is! Map) return null;
    final direct = _nonEmptyString(decoded['runSessionId']);
    if (direct != null) return direct;

    final nested = decoded['data'];
    if (nested is Map) {
      return _nonEmptyString(nested['runSessionId']);
    }
    return null;
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Response _json(int statusCode, Map<String, Object?> body) {
    return Response(
      statusCode,
      headers: const {
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      },
      body: jsonEncode(body),
    );
  }
}

