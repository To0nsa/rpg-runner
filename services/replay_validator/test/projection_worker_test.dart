import 'package:test/test.dart';
import 'package:run_protocol/validated_run.dart';

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
    },
  );

  test(
    'projection completes only after leaderboard and ghost publication finish',
    () async {
      final leaderboard = _FakeLeaderboardProjector();
      final ghosts = _FakeGhostPublisher();
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
    },
  );

  test('board reconciliation refreshes leaderboard and ghost state', () async {
    final leaderboard = _FakeLeaderboardProjector();
    final ghosts = _FakeGhostPublisher();
    final worker = DeterministicProjectionWorker(
      leaderboardProjector: leaderboard,
      ghostPublisher: ghosts,
      metrics: _FakeMetrics(),
    );

    final result = await worker.reconcileBoard(boardId: 'board_1');

    expect(result.status, ProjectionDispatchStatus.completed);
    expect(leaderboard.boardIds, <String>['board_1']);
    expect(ghosts.boardIds, <String>['board_1']);
  });
}

class _FakeLeaderboardProjector implements LeaderboardProjector {
  _FakeLeaderboardProjector({this.error});

  final Object? error;
  final List<String> runSessionIds = <String>[];
  final List<String> boardIds = <String>[];

  @override
  Future<void> projectValidatedRun({
    required String runSessionId,
    ValidatedRun? validatedRun,
    String? characterId,
  }) async {
    runSessionIds.add(runSessionId);
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<void> reconcileBoard({required String boardId}) async {
    boardIds.add(boardId);
    if (error != null) {
      throw error!;
    }
  }
}

class _FakeGhostPublisher implements GhostPublisher {
  final List<String> runSessionIds = <String>[];
  final List<String> boardIds = <String>[];

  @override
  Future<void> updateGhostArtifacts({
    required String runSessionId,
    ValidatedRun? validatedRun,
  }) async {
    runSessionIds.add(runSessionId);
  }

  @override
  Future<void> reconcileBoard({required String boardId}) async {
    boardIds.add(boardId);
  }
}

class _FakeMetrics implements ValidatorMetrics {
  final List<String?> phases = <String?>[];

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
  }
}
