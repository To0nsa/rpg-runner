enum CampaignObjective { firstCoin, blessing }

/// Read-only objective progress from the current fixed tick. An eligible exit
/// is not a clear; only the terminal Core event establishes completion.
final class CampaignSnapshot {
  const CampaignSnapshot({
    required this.missionId,
    this.firstCoinRequired = false,
    this.firstCoinCollected = false,
    this.blessingRequired = false,
    this.blessingReceived = false,
    required this.completed,
    required this.required,
    required this.failed,
    required this.exitX,
    required this.exitY,
  });
  final String missionId;
  final bool firstCoinRequired, firstCoinCollected;
  final bool blessingRequired, blessingReceived;
  final int completed, required;
  final bool failed;
  final double exitX, exitY;
  bool get exitReady => !failed && completed == required;

  bool requires(CampaignObjective objective) => switch (objective) {
    CampaignObjective.firstCoin => firstCoinRequired,
    CampaignObjective.blessing => blessingRequired,
  };
  bool isComplete(CampaignObjective objective) => switch (objective) {
    CampaignObjective.firstCoin => firstCoinCollected,
    CampaignObjective.blessing => blessingReceived,
  };
}
