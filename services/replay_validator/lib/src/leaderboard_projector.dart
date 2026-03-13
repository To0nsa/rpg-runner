abstract class LeaderboardProjector {
  Future<void> projectValidatedRun({
    required String runSessionId,
  });
}

class NoopLeaderboardProjector implements LeaderboardProjector {
  @override
  Future<void> projectValidatedRun({
    required String runSessionId,
  }) async {}
}

