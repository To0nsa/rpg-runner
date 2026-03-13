abstract class GhostPublisher {
  Future<void> updateGhostArtifacts({
    required String runSessionId,
  });
}

class NoopGhostPublisher implements GhostPublisher {
  @override
  Future<void> updateGhostArtifacts({
    required String runSessionId,
  }) async {}
}

