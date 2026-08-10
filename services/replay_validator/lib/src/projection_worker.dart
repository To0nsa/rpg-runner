import 'account_deletion_fence.dart';
import 'ghost_publisher.dart';
import 'leaderboard_projector.dart';
import 'metrics.dart';

/// Durable task disposition for optional leaderboard and ghost work.
enum ProjectionDispatchStatus { completed, retryScheduled }

/// Maps projection convergence to the HTTP response expected by Cloud Tasks.
class ProjectionDispatchResult {
  const ProjectionDispatchResult(this.status, {this.message});

  const ProjectionDispatchResult.completed({this.message})
    : status = ProjectionDispatchStatus.completed;

  const ProjectionDispatchResult.retryScheduled({this.message})
    : status = ProjectionDispatchStatus.retryScheduled;

  final ProjectionDispatchStatus status;
  final String? message;
}

/// Projects a validated run or independently reconciles all state for a board.
abstract interface class ProjectionWorker {
  Future<ProjectionDispatchResult> projectRunSession({
    required String runSessionId,
  });

  Future<ProjectionDispatchResult> reconcileBoard({required String boardId});
}

/// Publishes optional board artifacts after validation and settlement handoff.
///
/// A failure deliberately returns a retryable task result rather than touching
/// run-session state. Gold is already governed by the separate settlement
/// transaction and must never depend on leaderboard or ghost availability.
class DeterministicProjectionWorker implements ProjectionWorker {
  DeterministicProjectionWorker({
    required this.leaderboardProjector,
    required this.ghostPublisher,
    required this.metrics,
  });

  final LeaderboardProjector leaderboardProjector;
  final GhostPublisher ghostPublisher;
  final ValidatorMetrics metrics;

  @override
  Future<ProjectionDispatchResult> projectRunSession({
    required String runSessionId,
  }) async {
    final normalizedRunSessionId = runSessionId.trim();
    if (normalizedRunSessionId.isEmpty) {
      return const ProjectionDispatchResult.completed(
        message: 'runSessionId must be non-empty.',
      );
    }
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      await leaderboardProjector.projectValidatedRun(
        runSessionId: normalizedRunSessionId,
      );
      final ghostBoardId = await ghostPublisher.updateGhostArtifacts(
        runSessionId: normalizedRunSessionId,
      );
      if (ghostBoardId != null) {
        await leaderboardProjector.reconcileBoard(boardId: ghostBoardId);
      }
      await metrics.recordDispatch(
        runSessionId: normalizedRunSessionId,
        status: ProjectionDispatchStatus.completed.name,
        phase: 'projection',
        durationMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
      );
      return const ProjectionDispatchResult.completed();
    } on AccountDeletionInProgressException {
      await metrics.recordDispatch(
        runSessionId: normalizedRunSessionId,
        status: ProjectionDispatchStatus.completed.name,
        phase: 'projection_skipped_account_deletion',
        durationMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
      );
      return const ProjectionDispatchResult.completed(
        message: 'Account deletion is in progress.',
      );
    } catch (error) {
      await metrics.recordDispatch(
        runSessionId: normalizedRunSessionId,
        status: ProjectionDispatchStatus.retryScheduled.name,
        phase: 'projection_retry',
        durationMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
        errorClass: error.runtimeType.toString(),
      );
      return ProjectionDispatchResult.retryScheduled(
        message: 'Optional projection failed: ${error.runtimeType}.',
      );
    }
  }

  @override
  Future<ProjectionDispatchResult> reconcileBoard({
    required String boardId,
  }) async {
    final normalizedBoardId = boardId.trim();
    if (normalizedBoardId.isEmpty) {
      return const ProjectionDispatchResult.completed(
        message: 'boardId must be non-empty.',
      );
    }
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      await leaderboardProjector.reconcileBoard(boardId: normalizedBoardId);
      await ghostPublisher.reconcileBoard(boardId: normalizedBoardId);
      await leaderboardProjector.reconcileBoard(boardId: normalizedBoardId);
      await metrics.recordDispatch(
        runSessionId: 'board:$normalizedBoardId',
        status: ProjectionDispatchStatus.completed.name,
        phase: 'projection_reconciliation',
        durationMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
      );
      return const ProjectionDispatchResult.completed();
    } on AccountDeletionInProgressException {
      await metrics.recordDispatch(
        runSessionId: 'board:$normalizedBoardId',
        status: ProjectionDispatchStatus.completed.name,
        phase: 'projection_reconciliation_skipped_account_deletion',
        durationMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
      );
      return const ProjectionDispatchResult.completed(
        message: 'Account deletion is in progress.',
      );
    } catch (error) {
      await metrics.recordDispatch(
        runSessionId: 'board:$normalizedBoardId',
        status: ProjectionDispatchStatus.retryScheduled.name,
        phase: 'projection_reconciliation_retry',
        durationMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
        errorClass: error.runtimeType.toString(),
      );
      return const ProjectionDispatchResult.retryScheduled(
        message: 'Board projection reconciliation failed.',
      );
    }
  }
}

/// Fail-closed worker used when production projection dependencies are absent.
class StubProjectionWorker implements ProjectionWorker {
  const StubProjectionWorker();

  @override
  Future<ProjectionDispatchResult> projectRunSession({
    required String runSessionId,
  }) async => const ProjectionDispatchResult.retryScheduled(
    message: 'Projection worker is not configured.',
  );

  @override
  Future<ProjectionDispatchResult> reconcileBoard({
    required String boardId,
  }) async => const ProjectionDispatchResult.retryScheduled(
    message: 'Projection worker is not configured.',
  );
}
