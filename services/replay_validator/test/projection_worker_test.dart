import 'package:test/test.dart';
import 'package:run_protocol/validated_run.dart';

import 'package:replay_validator/src/account_deletion_fence.dart';
import 'package:replay_validator/src/ghost_publisher.dart';
import 'package:replay_validator/src/leaderboard_projector.dart';
import 'package:replay_validator/src/metrics.dart';
import 'package:replay_validator/src/projection_worker.dart';

void main() {
  test(
    'projection failure is retryable without changing validation outcome',
    () async {
      final leaderboard = _FakeLeaderboardProjector(
        error: StateError('leaderboard unavailable'),
      );
      final metrics = _FakeMetrics();
      final worker = DeterministicProjectionWorker(
        leaderboardProjector: leaderboard,
        ghostPublisher: _FakeGhostPublisher(),
        metrics: metrics,
      );

      final result = await worker.projectRunSession(
        runSessionId: 'run_board_1',
      );

      expect(result.status, ProjectionDispatchStatus.retryScheduled);
      expect(leaderboard.runSessionIds, <String>['run_board_1']);
      expect(metrics.phases, contains('projection_retry'));
      expect(metrics.errorClasses, contains('leaderboard_StateError'));
    },
  );

  test(
    'projection completes only after leaderboard and ghost publication finish',
    () async {
      final leaderboard = _FakeLeaderboardProjector();
      final ghosts = _FakeGhostPublisher(boardIdForUpdate: 'board_2');
      final worker = DeterministicProjectionWorker(
        leaderboardProjector: leaderboard,
        ghostPublisher: ghosts,
        metrics: _FakeMetrics(),
      );

      final result = await worker.projectRunSession(
        runSessionId: 'run_board_2',
      );

      expect(result.status, ProjectionDispatchStatus.completed);
      expect(leaderboard.runSessionIds, <String>['run_board_2']);
      expect(ghosts.runSessionIds, <String>['run_board_2']);
      expect(leaderboard.boardIds, <String>['board_2']);
    },
  );

  test('run projection reports changed materialization', () async {
    final metrics = _FakeMetrics();
    final worker = DeterministicProjectionWorker(
      leaderboardProjector: _FakeLeaderboardProjector(
        runResult: LeaderboardMaterializationResult.changed,
      ),
      ghostPublisher: _FakeGhostPublisher(),
      metrics: metrics,
    );

    final result = await worker.projectRunSession(runSessionId: 'run_changed');

    expect(result.status, ProjectionDispatchStatus.completed);
    expect(metrics.phases, contains('projection_changed'));
  });

  test(
    'account deletion completes projection without retrying the task',
    () async {
      final metrics = _FakeMetrics();
      final worker = DeterministicProjectionWorker(
        leaderboardProjector: _FakeLeaderboardProjector(
          error: const AccountDeletionInProgressException('uid_deleted'),
        ),
        ghostPublisher: _FakeGhostPublisher(),
        metrics: metrics,
      );

      final result = await worker.projectRunSession(
        runSessionId: 'run_deleted',
      );

      expect(result.status, ProjectionDispatchStatus.completed);
      expect(metrics.phases, contains('projection_skipped_account_deletion'));
    },
  );

  test('board reconciliation refreshes leaderboard and ghost state', () async {
    final leaderboard = _FakeLeaderboardProjector();
    final ghosts = _FakeGhostPublisher();
    final metrics = _FakeMetrics();
    final worker = DeterministicProjectionWorker(
      leaderboardProjector: leaderboard,
      ghostPublisher: ghosts,
      metrics: metrics,
    );

    final result = await worker.reconcileBoard(boardId: 'board_1');

    expect(result.status, ProjectionDispatchStatus.completed);
    expect(leaderboard.boardIds, <String>['board_1', 'board_1']);
    expect(ghosts.boardIds, <String>['board_1']);
    expect(metrics.phases, contains('projection_reconciliation_unchanged'));
  });

  test('board reconciliation reports a ghost-only materialization', () async {
    final metrics = _FakeMetrics();
    final worker = DeterministicProjectionWorker(
      leaderboardProjector: _FakeLeaderboardProjector(
        boardResults: const <LeaderboardMaterializationResult>[
          LeaderboardMaterializationResult.unchanged,
          LeaderboardMaterializationResult.changed,
        ],
      ),
      ghostPublisher: _FakeGhostPublisher(),
      metrics: metrics,
    );

    final result = await worker.reconcileBoard(boardId: 'board_ghost_change');

    expect(result.status, ProjectionDispatchStatus.completed);
    expect(
      metrics.phases,
      contains('projection_reconciliation_ghost_only_change'),
    );
  });

  test('projection conflict exhaustion has a distinct retry outcome', () async {
    final metrics = _FakeMetrics();
    final worker = DeterministicProjectionWorker(
      leaderboardProjector: _FakeLeaderboardProjector(
        error: const LeaderboardProjectionConflictException('board_conflict'),
      ),
      ghostPublisher: _FakeGhostPublisher(),
      metrics: metrics,
    );

    final result = await worker.reconcileBoard(boardId: 'board_conflict');

    expect(result.status, ProjectionDispatchStatus.retryScheduled);
    expect(
      metrics.errorClasses,
      contains(
        'leaderboard_before_ghost_LeaderboardProjectionConflictException',
      ),
    );
  });
}

class _FakeLeaderboardProjector implements LeaderboardProjector {
  _FakeLeaderboardProjector({
    this.error,
    this.runResult = LeaderboardMaterializationResult.unchanged,
    this.boardResults = const <LeaderboardMaterializationResult>[],
  });

  final Object? error;
  final LeaderboardMaterializationResult runResult;
  final List<LeaderboardMaterializationResult> boardResults;
  final List<String> runSessionIds = <String>[];
  final List<String> boardIds = <String>[];

  @override
  Future<LeaderboardMaterializationResult> projectValidatedRun({
    required String runSessionId,
    ValidatedRun? validatedRun,
    String? characterId,
  }) async {
    runSessionIds.add(runSessionId);
    if (error != null) {
      throw error!;
    }
    return runResult;
  }

  @override
  Future<LeaderboardMaterializationResult> reconcileBoard({
    required String boardId,
  }) async {
    boardIds.add(boardId);
    if (error != null) {
      throw error!;
    }
    final resultIndex = boardIds.length - 1;
    return resultIndex < boardResults.length
        ? boardResults[resultIndex]
        : LeaderboardMaterializationResult.unchanged;
  }
}

class _FakeGhostPublisher implements GhostPublisher {
  _FakeGhostPublisher({this.boardIdForUpdate});

  final String? boardIdForUpdate;
  final List<String> runSessionIds = <String>[];
  final List<String> boardIds = <String>[];

  @override
  Future<String?> updateGhostArtifacts({
    required String runSessionId,
    ValidatedRun? validatedRun,
  }) async {
    runSessionIds.add(runSessionId);
    return boardIdForUpdate;
  }

  @override
  Future<void> reconcileBoard({required String boardId}) async {
    boardIds.add(boardId);
  }
}

class _FakeMetrics implements ValidatorMetrics {
  final List<String?> phases = <String?>[];
  final List<String?> errorClasses = <String?>[];

  @override
  Future<void> recordDispatch({
    required String runSessionId,
    required String status,
    String? message,
    int? attempt,
    String? mode,
    String? phase,
    String? rejectionReason,
    int? durationMs,
    String? errorClass,
  }) async {
    phases.add(phase);
    errorClasses.add(errorClass);
  }
}
