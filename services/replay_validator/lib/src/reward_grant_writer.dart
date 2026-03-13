abstract class RewardGrantWriter {
  Future<void> writeRewardGrant({
    required String runSessionId,
  });
}

class NoopRewardGrantWriter implements RewardGrantWriter {
  @override
  Future<void> writeRewardGrant({
    required String runSessionId,
  }) async {}
}

