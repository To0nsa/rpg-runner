abstract class BoardRepository {
  Future<Map<String, Object?>?> loadBoardForRunSession({
    required String runSessionId,
  });
}

class NoopBoardRepository implements BoardRepository {
  @override
  Future<Map<String, Object?>?> loadBoardForRunSession({
    required String runSessionId,
  }) async {
    return null;
  }
}

