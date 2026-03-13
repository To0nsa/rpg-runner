import 'board_repository.dart';
import 'ghost_publisher.dart';
import 'leaderboard_projector.dart';
import 'metrics.dart';
import 'replay_loader.dart';
import 'reward_grant_writer.dart';
import 'run_session_repository.dart';

enum ValidationDispatchStatus {
  accepted,
  rejected,
  badRequest,
  notImplemented,
}

class ValidationDispatchResult {
  const ValidationDispatchResult(this.status, {this.message});

  const ValidationDispatchResult.accepted({this.message})
    : status = ValidationDispatchStatus.accepted;

  const ValidationDispatchResult.rejected({this.message})
    : status = ValidationDispatchStatus.rejected;

  const ValidationDispatchResult.badRequest({this.message})
    : status = ValidationDispatchStatus.badRequest;

  const ValidationDispatchResult.notImplemented({this.message})
    : status = ValidationDispatchStatus.notImplemented;

  final ValidationDispatchStatus status;
  final String? message;
}

abstract class ValidatorWorker {
  Future<ValidationDispatchResult> validateRunSession({
    required String runSessionId,
  });
}

class StubValidatorWorker implements ValidatorWorker {
  StubValidatorWorker({
    required this.replayLoader,
    required this.boardRepository,
    required this.runSessionRepository,
    required this.leaderboardProjector,
    required this.rewardGrantWriter,
    required this.ghostPublisher,
    required this.metrics,
  });

  final ReplayLoader replayLoader;
  final BoardRepository boardRepository;
  final RunSessionRepository runSessionRepository;
  final LeaderboardProjector leaderboardProjector;
  final RewardGrantWriter rewardGrantWriter;
  final GhostPublisher ghostPublisher;
  final ValidatorMetrics metrics;

  @override
  Future<ValidationDispatchResult> validateRunSession({
    required String runSessionId,
  }) async {
    await metrics.recordDispatch(
      runSessionId: runSessionId,
      status: ValidationDispatchStatus.notImplemented.name,
      message: 'Validator algorithm implementation lands in Phase 4.',
    );
    return const ValidationDispatchResult.notImplemented(
      message: 'Validator algorithm implementation lands in Phase 4.',
    );
  }
}

