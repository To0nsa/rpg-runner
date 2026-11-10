import '../../l10n/app_localization.dart';

import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/scoring/run_score_breakdown.dart';

String formatScoreRow(
  RunScoreRow row,
  int remainingPoints, {
  required String Function(EnemyId id) enemyName,
  required AppLocalizations l10n,
}) {
  switch (row.kind) {
    case RunScoreRowKind.distance:
      return l10n.scoreRowDistance(count: row.count, points: remainingPoints);
    case RunScoreRowKind.time:
      return l10n.scoreRowTime(
        time: _formatTime(row.count),
        points: remainingPoints,
      );
    case RunScoreRowKind.collectibles:
      return l10n.scoreRowCollectibles(
        count: row.count,
        points: remainingPoints,
      );
    case RunScoreRowKind.enemyKill:
      final name = row.enemyId == null
          ? l10n.scoreEnemy
          : enemyName(row.enemyId!);
      return l10n.scoreRowEnemy(
        enemy: name,
        count: row.count,
        points: remainingPoints,
      );
    case RunScoreRowKind.rescue:
      return l10n.scoreRowRescue(count: row.count, points: remainingPoints);
  }
}

String _formatTime(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
