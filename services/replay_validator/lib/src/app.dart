import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'board_repository.dart';
import 'ghost_publisher.dart';
import 'leaderboard_projector.dart';
import 'metrics.dart';
import 'projection_worker.dart';
import 'google_api_helpers.dart';
import 'replay_loader.dart';
import 'replay_validation_limits.dart';
import 'run_session_repository.dart';
import 'settlement_dispatcher.dart';
import 'validated_replay_archiver.dart';
import 'validator_worker.dart';

class ReplayValidatorApp {
  ReplayValidatorApp({
    required this.port,
    ValidatorWorker? worker,
    ProjectionWorker? projectionWorker,
    bool? ready,
    this.readinessMessage,
  }) : worker =
           worker ??
           StubValidatorWorker(
             replayLoader: UnimplementedReplayLoader(),
             boardRepository: NoopBoardRepository(),
             runSessionRepository: NoopRunSessionRepository(),
             metrics: ConsoleValidatorMetrics(),
           ),
       projectionWorker = projectionWorker ?? const StubProjectionWorker(),
       ready = ready ?? (worker != null && projectionWorker != null);

  factory ReplayValidatorApp.fromEnvironment([
    Map<String, String>? environment,
  ]) {
    final resolvedEnvironment = environment ?? Platform.environment;
    String? readEnv(String name) => _readEnv(resolvedEnvironment, name);
    int? readPositiveIntEnv(String name) =>
        _readPositiveIntEnv(resolvedEnvironment, name);
    bool? readBoolEnv(String name) => _readBoolEnv(resolvedEnvironment, name);

    final rawPort = resolvedEnvironment['PORT'];
    final parsedPort = int.tryParse(rawPort ?? '');
    final projectId =
        readEnv('GCLOUD_PROJECT') ?? readEnv('GOOGLE_CLOUD_PROJECT');
    final replayStorageBucket = readEnv('REPLAY_STORAGE_BUCKET');
    final graceWindowMs =
        readPositiveIntEnv('VALIDATOR_INTERNAL_ERROR_GRACE_WINDOW_MS') ??
        const Duration(hours: 1).inMilliseconds;
    final incidentMode =
        readBoolEnv('VALIDATOR_INCIDENT_MODE_PAUSE_AUTO_REVOKE') ?? false;
    final incidentRetryDelayMs =
        readPositiveIntEnv('VALIDATOR_INCIDENT_MODE_RETRY_DELAY_MS') ??
        const Duration(minutes: 15).inMilliseconds;
    final orphanedTaskRepairDelayMs =
        readPositiveIntEnv('VALIDATOR_ORPHANED_TASK_REPAIR_DELAY_MS') ??
        const Duration(minutes: 15).inMilliseconds;
    final settlementDispatchUrl = readEnv('SETTLEMENT_DISPATCH_URL');
    final settlementDispatchTimeoutMs =
        readPositiveIntEnv('SETTLEMENT_DISPATCH_TIMEOUT_MS') ?? 4000;
    final validationLeaseDurationMs =
        readPositiveIntEnv('VALIDATOR_LEASE_DURATION_MS') ??
        const Duration(minutes: 10).inMilliseconds;
    final replayLimits = ReplayValidationLimits(
      maxCompressedBytes:
          readPositiveIntEnv('VALIDATOR_MAX_COMPRESSED_REPLAY_BYTES') ??
          8 * 1024 * 1024,
      maxExpandedBytes:
          readPositiveIntEnv('VALIDATOR_MAX_EXPANDED_REPLAY_BYTES') ??
          32 * 1024 * 1024,
      maxJsonNestingDepth:
          readPositiveIntEnv('VALIDATOR_MAX_JSON_NESTING_DEPTH') ?? 64,
      maxCommandFrames:
          readPositiveIntEnv('VALIDATOR_MAX_COMMAND_FRAMES') ?? 250000,
      maxRunDuration: Duration(
        seconds:
            readPositiveIntEnv('VALIDATOR_MAX_RUN_DURATION_SECONDS') ??
            const Duration(hours: 6).inSeconds,
      ),
      maxSimulationWallTime: Duration(
        milliseconds:
            readPositiveIntEnv('VALIDATOR_MAX_SIMULATION_WALL_TIME_MS') ??
            const Duration(minutes: 2).inMilliseconds,
      ),
    );
    replayLimits.validate();
    if (projectId == null || replayStorageBucket == null) {
      return ReplayValidatorApp(
        port: parsedPort ?? 8080,
        ready: false,
        readinessMessage:
            'GCLOUD_PROJECT and REPLAY_STORAGE_BUCKET are required.',
      );
    }
    final apiProvider = GoogleCloudApiProvider();
    return ReplayValidatorApp(
      port: parsedPort ?? 8080,
      worker: DeterministicValidatorWorker(
        replayLoader: GoogleCloudStorageReplayLoader(
          bucketName: replayStorageBucket,
          apiProvider: apiProvider,
          maxBytes: replayLimits.maxCompressedBytes,
        ),
        boardRepository: FirestoreBoardRepository(
          projectId: projectId,
          apiProvider: apiProvider,
        ),
        runSessionRepository: FirestoreRunSessionRepository(
          projectId: projectId,
          apiProvider: apiProvider,
          validationLeaseDuration: Duration(
            milliseconds: validationLeaseDurationMs,
          ),
        ),
        metrics: ConsoleValidatorMetrics(),
        validatedReplayArchiver: GoogleCloudStorageValidatedReplayArchiver(
          bucketName: replayStorageBucket,
          apiProvider: apiProvider,
        ),
        settlementDispatcher: settlementDispatchUrl == null
            ? const NoopSettlementDispatcher()
            : FunctionsSettlementDispatcher(
                endpoint: Uri.parse(settlementDispatchUrl),
                identityTokenProvider: MetadataIdentityTokenProvider(),
                timeout: Duration(milliseconds: settlementDispatchTimeoutMs),
              ),
        internalErrorGraceWindow: Duration(milliseconds: graceWindowMs),
        incidentModeAutoRevokePaused: incidentMode,
        incidentModeRetryDelay: Duration(milliseconds: incidentRetryDelayMs),
        orphanedTaskRepairDelay: Duration(
          milliseconds: orphanedTaskRepairDelayMs,
        ),
        limits: replayLimits,
      ),
      projectionWorker: DeterministicProjectionWorker(
        leaderboardProjector: FirestoreLeaderboardProjector(
          projectId: projectId,
          apiProvider: apiProvider,
        ),
        ghostPublisher: FirestoreGhostPublisher(
          projectId: projectId,
          replayStorageBucket: replayStorageBucket,
          apiProvider: apiProvider,
        ),
        metrics: ConsoleValidatorMetrics(),
      ),
      ready: true,
    );
  }

  final int port;
  final ValidatorWorker worker;
  final ProjectionWorker projectionWorker;
  final bool ready;
  final String? readinessMessage;

  Handler get handler {
    final router = Router()
      ..get('/live', _live)
      ..get('/ready', _ready)
      ..post('/tasks/validate', _validateTask)
      ..post('/tasks/project', _projectTask);

    return Pipeline().addMiddleware(logRequests()).addHandler(router.call);
  }

  Future<Response> _live(Request request) async {
    return _json(HttpStatus.ok, <String, Object?>{
      'status': 'ok',
      'service': 'replay-validator',
    });
  }

  Future<Response> _ready(Request request) async {
    return _json(ready ? HttpStatus.ok : HttpStatus.serviceUnavailable, <
      String,
      Object?
    >{
      'status': ready ? 'ready' : 'not_ready',
      'service': 'replay-validator',
      if (!ready)
        'message':
            readinessMessage ?? 'Replay validator workers are not configured.',
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

  Future<Response> _projectTask(Request request) async {
    final decoded = await _decodeBody(request);
    final runSessionId = _extractRunSessionId(decoded);
    final boardId = _extractBoardId(decoded);
    if (runSessionId == null && boardId == null) {
      return _json(HttpStatus.badRequest, const <String, Object?>{
        'error': 'invalid_request',
        'message': 'Expected non-empty runSessionId or boardId in body.',
      });
    }

    final result = runSessionId != null
        ? await projectionWorker.projectRunSession(runSessionId: runSessionId)
        : await projectionWorker.reconcileBoard(boardId: boardId!);
    final statusCode = switch (result.status) {
      ProjectionDispatchStatus.completed => HttpStatus.ok,
      ProjectionDispatchStatus.retryScheduled => HttpStatus.serviceUnavailable,
    };
    return _json(statusCode, <String, Object?>{
      'runSessionId': ?runSessionId,
      'boardId': ?boardId,
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

  String? _extractBoardId(Object? decoded) {
    if (decoded is! Map) return null;
    final direct = _nonEmptyString(decoded['boardId']);
    if (direct != null) return direct;

    final nested = decoded['data'];
    if (nested is Map) {
      return _nonEmptyString(nested['boardId']);
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

String? _readEnv(Map<String, String> environment, String name) {
  final raw = environment[name];
  if (raw == null) {
    return null;
  }
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _readPositiveIntEnv(Map<String, String> environment, String name) {
  final raw = _readEnv(environment, name);
  if (raw == null) {
    return null;
  }
  final parsed = int.tryParse(raw);
  if (parsed == null || parsed <= 0) {
    throw FormatException('$name must be a positive integer.');
  }
  return parsed;
}

bool? _readBoolEnv(Map<String, String> environment, String name) {
  final raw = _readEnv(environment, name)?.toLowerCase();
  if (raw == null) {
    return null;
  }
  if (raw == '1' || raw == 'true' || raw == 'yes' || raw == 'on') {
    return true;
  }
  if (raw == '0' || raw == 'false' || raw == 'no' || raw == 'off') {
    return false;
  }
  throw FormatException('$name must be a boolean value.');
}
