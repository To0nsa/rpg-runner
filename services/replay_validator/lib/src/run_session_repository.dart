abstract class RunSessionRepository {
  Future<Map<String, Object?>?> loadRunSession({
    required String runSessionId,
  });
}

class NoopRunSessionRepository implements RunSessionRepository {
  @override
  Future<Map<String, Object?>?> loadRunSession({
    required String runSessionId,
  }) async {
    return null;
  }
}

