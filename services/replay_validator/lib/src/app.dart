import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'board_repository.dart';
import 'ghost_publisher.dart';
import 'leaderboard_projector.dart';
import 'metrics.dart';
import 'google_api_helpers.dart';
import 'replay_loader.dart';
import 'reward_settlement_writer.dart';
import 'run_session_repository.dart';
import 'validator_worker.dart';

class ReplayValidatorApp {
  ReplayValidatorApp({required this.port, ValidatorWorker? worker})
    : worker =
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
    final projectId =
        _readEnv('GCLOUD_PROJECT') ?? _readEnv('GOOGLE_CLOUD_PROJECT');
    final replayStorageBucket = _readEnv('REPLAY_STORAGE_BUCKET');
    final graceWindowMs =
      _readPositiveIntEnv('VALIDATOR_INTERNAL_ERROR_GRACE_WINDOW_MS') ??
      const Duration(hours: 1).inMilliseconds;
    final incidentMode =
      _readBoolEnv('VALIDATOR_INCIDENT_MODE_PAUSE_AUTO_REVOKE') ?? false;
    final enableRewardSettlementWrites =
      _readBoolEnv('VALIDATOR_REWARD_SETTLEMENT_WRITES_ENABLED') ?? true;
    final incidentRetryDelayMs =
      _readPositiveIntEnv('VALIDATOR_INCIDENT_MODE_RETRY_DELAY_MS') ??
      const Duration(minutes: 15).inMilliseconds;
    if (projectId == null || replayStorageBucket == null) {
      return ReplayValidatorApp(port: parsedPort ?? 8080);
    }
    final apiProvider = GoogleCloudApiProvider();
    return ReplayValidatorApp(
      port: parsedPort ?? 8080,
      worker: DeterministicValidatorWorker(
        replayLoader: GoogleCloudStorageReplayLoader(
          bucketName: replayStorageBucket,
          apiProvider: apiProvider,
        ),
        boardRepository: FirestoreBoardRepository(
          projectId: projectId,
          apiProvider: apiProvider,
        ),
        runSessionRepository: FirestoreRunSessionRepository(
          projectId: projectId,
          apiProvider: apiProvider,
        ),
        leaderboardProjector: FirestoreLeaderboardProjector(
          projectId: projectId,
          apiProvider: apiProvider,
        ),
        rewardGrantWriter: FirestoreRewardGrantWriter(
          projectId: projectId,
          apiProvider: apiProvider,
        ),
        ghostPublisher: FirestoreGhostPublisher(
          projectId: projectId,
          replayStorageBucket: replayStorageBucket,
          apiProvider: apiProvider,
        ),
        metrics: ConsoleValidatorMetrics(),
        enableRewardSettlementWrites: enableRewardSettlementWrites,
        internalErrorGraceWindow: Duration(milliseconds: graceWindowMs),
        incidentModeAutoRevokePaused: incidentMode,
        incidentModeRetryDelay: Duration(milliseconds: incidentRetryDelayMs),
      ),
    );
  }

  final int port;
  final ValidatorWorker worker;

  Handler get handler {
    final router = Router()
      ..get('/healthz', _healthz)
      ..post('/tasks/validate', _validateTask);

    return Pipeline().addMiddleware(logRequests()).addHandler(router.call);
  }

  Future<Response> _healthz(Request request) async {
    return _json(HttpStatus.ok, <String, Object?>{
      'status': 'ok',
      'service': 'replay-validator',
    });
  }

  Future<Response> _validateTask(Request request) async {
    final decoded = await _decodeBody(request);
    final runSessionId = _extractRunSessionId(decoded);
    if (runSessionId == null) {
      return _json(HttpStatus.badRequest, const <String, Object?>{
        'error': 'invalid_request',
        'message': 'Expected non-empty runSessionId in body.',
      });
    }

    final result = await worker.validateRunSession(runSessionId: runSessionId);
    final statusCode = switch (result.status) {
      ValidationDispatchStatus.accepted => HttpStatus.accepted,
      ValidationDispatchStatus.rejected => HttpStatus.ok,
      ValidationDispatchStatus.badRequest => HttpStatus.badRequest,
      ValidationDispatchStatus.retryScheduled => HttpStatus.serviceUnavailable,
      ValidationDispatchStatus.notImplemented => HttpStatus.notImplemented,
    };
    return _json(statusCode, <String, Object?>{
      'runSessionId': runSessionId,
      'status': result.status.name,
      if (result.message != null) 'message': result.message,
    });
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

String? _readEnv(String name) {
  final raw = Platform.environment[name];
  if (raw == null) {
    return null;
  }
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _readPositiveIntEnv(String name) {
  final raw = _readEnv(name);
  if (raw == null) {
    return null;
  }
  final parsed = int.tryParse(raw);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

bool? _readBoolEnv(String name) {
  final raw = _readEnv(name)?.toLowerCase();
  if (raw == null) {
    return null;
  }
  if (raw == '1' || raw == 'true' || raw == 'yes' || raw == 'on') {
    return true;
  }
  if (raw == '0' || raw == 'false' || raw == 'no' || raw == 'off') {
    return false;
  }
  return null;
}
