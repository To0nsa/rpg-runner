/// Read-only objective progress from the current fixed tick. An eligible exit
/// is not a clear; only the terminal Core event establishes completion.
final class CampaignSnapshot {
  const CampaignSnapshot({
    required this.missionId,
    required this.completed,
    required this.required,
    required this.failed,
    required this.exitX,
    required this.exitY,
  });
  final String missionId;
  final int completed, required;
  final bool failed;
  final double exitX, exitY;
  bool get exitReady => !failed && completed == required;
}
