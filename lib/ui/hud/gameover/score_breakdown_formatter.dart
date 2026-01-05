import '../../../core/enemies/enemy_id.dart';
import '../../../core/scoring/run_score_breakdown.dart';

String formatScoreRow(
  RunScoreRow row,
  int remainingPoints, {
  required String Function(EnemyId id) enemyName,
}) {
  switch (row.kind) {
    case RunScoreRowKind.distance:
      return 'Distance: ${row.count}m -> $remainingPoints';
    case RunScoreRowKind.time:
      return 'Time: ${_formatTime(row.count)} -> $remainingPoints';
    case RunScoreRowKind.collectibles:
      return 'Collectibles: ${row.count} -> $remainingPoints';
    case RunScoreRowKind.enemyKill:
      final name = row.enemyId == null ? 'Enemy' : enemyName(row.enemyId!);
      return '$name x${row.count} -> $remainingPoints';
  }
}

String _formatTime(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
