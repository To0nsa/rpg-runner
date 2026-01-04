import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/enemies/enemy_id.dart';
import '../../core/events/game_event.dart';
import '../../core/projectiles/projectile_id.dart';
import '../../core/scoring/run_score_breakdown.dart';
import '../../core/tuning/v0_score_tuning.dart';
// import '../../core/spells/spell_id.dart';

class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({
    super.key,
    required this.visible,
    required this.onRestart,
    required this.onExit,
    required this.showExitButton,
    required this.runEndedEvent,
    required this.scoreTuning,
    required this.tickHz,
  });

  final bool visible;
  final VoidCallback onRestart;
  final VoidCallback? onExit;
  final bool showExitButton;
  final RunEndedEvent? runEndedEvent;
  final V0ScoreTuning scoreTuning;
  final int tickHz;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

enum _FeedState { idle, feeding, complete }

class _ScoreRowState {
  _ScoreRowState({
    required this.row,
    required this.pointsPerSecond,
  }) : remainingPoints = row.points;

  final RunScoreRow row;
  final double pointsPerSecond;
  int remainingPoints;
  double carry = 0.0;
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  static const double _feedDurationSeconds = 0.8;

  late final RunScoreBreakdown _breakdown;
  late final List<_ScoreRowState> _rows;
  late final int _totalPoints;
  late int _displayScore;
  late _FeedState _feedState;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _breakdown = _buildBreakdown();
    _rows = _buildRowStates(_breakdown.rows);
    _totalPoints = _breakdown.totalPoints;
    _displayScore = 0;
    _feedState = _totalPoints > 0 ? _FeedState.idle : _FeedState.complete;
  }

  RunScoreBreakdown _buildBreakdown() {
    final event = widget.runEndedEvent;
    if (event == null) {
      return const RunScoreBreakdown(rows: <RunScoreRow>[], totalPoints: 0);
    }

    return buildRunScoreBreakdown(
      tick: event.tick,
      distanceUnits: event.distance,
      collectibles: event.stats.collectibles,
      collectibleScore: event.stats.collectibleScore,
      enemyKillCounts: event.stats.enemyKillCounts,
      tuning: widget.scoreTuning,
      tickHz: widget.tickHz,
    );
  }

  List<_ScoreRowState> _buildRowStates(List<RunScoreRow> rows) {
    return [
      for (final row in rows)
        _ScoreRowState(
          row: row,
          pointsPerSecond:
              row.points <= 0 ? 0.0 : row.points / _feedDurationSeconds,
        ),
    ];
  }

  void _startFeed() {
    if (_feedState != _FeedState.idle || _totalPoints <= 0) return;
    _feedState = _FeedState.feeding;
    _startTicker();
    setState(() {});
  }

  void _startTicker() {
    _ticker?.dispose();
    _lastElapsed = Duration.zero;
    _ticker = createTicker(_onTick)..start();
  }

  void _stopTicker() {
    final ticker = _ticker;
    if (ticker == null) return;
    ticker.stop();
    ticker.dispose();
    _ticker = null;
  }

  void _onTick(Duration elapsed) {
    if (_feedState != _FeedState.feeding) return;

    final dt =
        (elapsed - _lastElapsed).inMicroseconds.toDouble() / 1000000.0;
    _lastElapsed = elapsed;
    if (dt <= 0) return;

    var gained = 0;
    var anyRemaining = false;

    for (final row in _rows) {
      if (row.remainingPoints <= 0 || row.pointsPerSecond <= 0) continue;
      row.carry += dt * row.pointsPerSecond;
      final raw = row.carry.floor();
      if (raw <= 0) {
        anyRemaining = true;
        continue;
      }
      row.carry -= raw;
      final consume =
          raw > row.remainingPoints ? row.remainingPoints : raw;
      row.remainingPoints -= consume;
      gained += consume;
      if (row.remainingPoints > 0) anyRemaining = true;
    }

    if (gained > 0) {
      _displayScore += gained;
      if (_displayScore > _totalPoints) _displayScore = _totalPoints;
    }

    if (!anyRemaining) {
      _completeFeed();
    }

    if (mounted) setState(() {});
  }

  void _completeFeed() {
    _displayScore = _totalPoints;
    for (final row in _rows) {
      row.remainingPoints = 0;
      row.carry = 0.0;
    }
    _feedState = _FeedState.complete;
    _stopTicker();
  }

  void _onCollectPressed() {
    if (_feedState == _FeedState.idle) {
      _startFeed();
      return;
    }
    if (_feedState == _FeedState.feeding) {
      _completeFeed();
      setState(() {});
    }
  }

  void _completeThen(VoidCallback? action) {
    if (_feedState != _FeedState.complete) {
      _completeFeed();
      setState(() {});
    }
    if (action == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }

  String _formatRow(_ScoreRowState row) {
    final remaining = row.remainingPoints;
    switch (row.row.kind) {
      case RunScoreRowKind.distance:
        return 'Distance: ${row.row.count}m -> $remaining';
      case RunScoreRowKind.time:
        return 'Time: ${_formatTime(row.row.count)} -> $remaining';
      case RunScoreRowKind.collectibles:
        return 'Collectibles: ${row.row.count} -> $remaining';
      case RunScoreRowKind.enemyKill:
        final name = row.row.enemyId == null
            ? 'Enemy'
            : _enemyName(row.row.enemyId!);
        return '$name x${row.row.count} -> $remaining';
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final subtitle = _buildSubtitle(widget.runEndedEvent);
    final showCollectButton =
        _totalPoints > 0 && _feedState != _FeedState.complete;
    final collectLabel =
        _feedState == _FeedState.idle ? 'Collect score' : 'Skip';

    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0x88000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Game Over',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Score: $_displayScore',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _rows.length; i += 1) ...[
                Text(
                  _formatRow(_rows[i]),
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (i < _rows.length - 1) const SizedBox(height: 4),
              ],
              if (showCollectButton) ...[
                const SizedBox(height: 16),
                _OverlayButton(label: collectLabel, onPressed: _onCollectPressed),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OverlayButton(
                    label: 'Restart',
                    onPressed: () => _completeThen(widget.onRestart),
                  ),
                  if (widget.showExitButton) ...[
                    const SizedBox(width: 12),
                    _OverlayButton(
                      label: 'Exit',
                      onPressed: () => _completeThen(widget.onExit),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _buildSubtitle(RunEndedEvent? event) {
  if (event == null) return null;
  switch (event.reason) {
    case RunEndReason.gaveUp:
      return 'You gave up the run.';
    case RunEndReason.fellBehindCamera:
      return 'You fell behind.';
    case RunEndReason.playerDied:
      return _buildDeathSubtitle(event.deathInfo);
  }
}

String _buildDeathSubtitle(DeathInfo? info) {
  if (info == null) return 'You died.';
  switch (info.kind) {
    case DeathSourceKind.projectile:
      return _buildProjectileDeath(info);
    case DeathSourceKind.meleeHitbox:
      return _buildMeleeDeath(info);
    case DeathSourceKind.unknown:
      return 'You died.';
  }
}

String _buildProjectileDeath(DeathInfo info) {
  final projectileId = info.projectileId;
  if (projectileId == null) return 'You died.';
  final projectileName = _projectileName(projectileId);
  /* final spellName =
      info.spellId == null ? null : _spellName(info.spellId!); */
  final enemyName = info.enemyId == null ? null : _enemyName(info.enemyId!);

  final buffer = StringBuffer('Killed by $projectileName');
  /*   if (spellName != null) {
    buffer.write(' ($spellName)');
  } */
  if (enemyName != null) {
    buffer.write(' from $enemyName.');
  } else {
    buffer.write('.');
  }
  return buffer.toString();
}

String _buildMeleeDeath(DeathInfo info) {
  if (info.enemyId == null) return 'You died.';
  return 'Killed by a melee strike from a ${_enemyName(info.enemyId!)}.';
}

String _enemyName(EnemyId id) {
  switch (id) {
    case EnemyId.flyingEnemy:
      return 'Flying enemy';
    case EnemyId.groundEnemy:
      return 'Ground enemy';
  }
}

String _projectileName(ProjectileId id) {
  switch (id) {
    case ProjectileId.iceBolt:
      return 'Ice Bolt';
    case ProjectileId.lightningBolt:
      return 'Lightning Bolt';
  }
}

/* String _spellName(SpellId id) {
  switch (id) {
    case SpellId.iceBolt:
      return 'Ice Bolt';
    case SpellId.lightning:
      return 'Lightning';
  }
} */

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFFFFFFF),
        backgroundColor: const Color(0xAA000000),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFFFFFFF)),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
