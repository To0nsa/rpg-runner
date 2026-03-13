class LoadedReplay {
  const LoadedReplay({
    required this.runSessionId,
    required this.bytes,
  });

  final String runSessionId;
  final List<int> bytes;
}

abstract class ReplayLoader {
  Future<LoadedReplay> loadReplay({
    required String runSessionId,
  });
}

class UnimplementedReplayLoader implements ReplayLoader {
  @override
  Future<LoadedReplay> loadReplay({
    required String runSessionId,
  }) {
    throw UnimplementedError(
      'Replay loading implementation lands in Phase 4.',
    );
  }
}

