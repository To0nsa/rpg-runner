const int kSortKeyMetricWidth = 10;
const int kSortKeyMaxMetric = 9999999999;

String buildLeaderboardSortKey({
  required int score,
  required int distanceMeters,
  required int durationSeconds,
  required String entryId,
}) {
  if (entryId.isEmpty) {
    throw ArgumentError.value(entryId, 'entryId', 'must be non-empty');
  }

  final invScore = _invertDescendingMetric(score);
  final invDistance = _invertDescendingMetric(distanceMeters);
  final duration = _clampMetric(durationSeconds);

  return '${_pad(invScore)}:${_pad(invDistance)}:${_pad(duration)}:$entryId';
}

int _invertDescendingMetric(int value) {
  final clamped = _clampMetric(value);
  return kSortKeyMaxMetric - clamped;
}

int _clampMetric(int value) {
  if (value < 0) return 0;
  if (value > kSortKeyMaxMetric) return kSortKeyMaxMetric;
  return value;
}

String _pad(int value) => value.toString().padLeft(kSortKeyMetricWidth, '0');
