import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/enemies/enemy_id.dart';
import '../../../core/events/game_event.dart';
import '../../../core/projectiles/projectile_id.dart';
import '../../../core/scoring/run_score_breakdown.dart';
import '../../../core/tuning/v0_score_tuning.dart';
import '../../leaderboard/leaderboard_store.dart';
import 'game_over_header.dart';
import 'leaderboard_panel.dart';
import 'restart_exit_buttons.dart';
import 'score_breakdown_formatter.dart';
import 'score_distribution.dart';
import 'score_feed_controller.dart';
// import '../../../core/spells/spell_id.dart';

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
    this.leaderboardStore,
  });

  final bool visible;
  final VoidCallback onRestart;
  final VoidCallback? onExit;
  final bool showExitButton;
  final RunEndedEvent? runEndedEvent;
  final V0ScoreTuning scoreTuning;
  final int tickHz;
  final LeaderboardStore? leaderboardStore;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final RunScoreBreakdown _breakdown;
  late final ScoreFeedController _feedController;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _breakdown = _buildBreakdown();
    _feedController = ScoreFeedController(
      rows: _breakdown.rows,
      totalPoints: _breakdown.totalPoints,
    );
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

  void _startFeed() {
    if (_feedController.startFeed()) {
      _startTicker();
      setState(() {});
    }
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
    if (_feedController.feedState != ScoreFeedState.feeding) return;

    final dt =
        (elapsed - _lastElapsed).inMicroseconds.toDouble() / 1000000.0;
    _lastElapsed = elapsed;
    if (dt <= 0) return;

    final changed = _feedController.tick(dt);
    if (_feedController.feedState == ScoreFeedState.complete) {
      _stopTicker();
    }
    if (changed && mounted) setState(() {});
  }

  void _completeFeed() {
    _feedController.completeFeed();
    _stopTicker();
  }

  void _onCollectPressed() {
    if (_feedController.feedState == ScoreFeedState.idle) {
      _startFeed();
      return;
    }
    if (_feedController.feedState == ScoreFeedState.feeding) {
      _completeFeed();
      setState(() {});
    }
  }

  void _completeThen(VoidCallback? action) {
    if (_feedController.feedState != ScoreFeedState.complete) {
      _completeFeed();
      setState(() {});
    }
    if (action == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final subtitleDeathReason = _buildSubtitleDeathReason(widget.runEndedEvent);
    final showCollectButton =
        _feedController.totalPoints > 0 &&
        _feedController.feedState != ScoreFeedState.complete;
    final showScoreInHeader =
        _feedController.feedState == ScoreFeedState.complete;
    final collectLabel =
        _feedController.feedState == ScoreFeedState.idle
            ? 'Collect score'
            : 'Skip';
    final rowLabels = [
      for (var i = 0; i < _feedController.rows.length; i += 1)
        formatScoreRow(
          _feedController.rows[i].row,
          _feedController.rows[i].remainingPoints,
          enemyName: _enemyName,
        ),
    ];

    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0x88000000),
        child: SafeArea(
          minimum: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      GameOverHeader(
                        subtitleDeathReason: subtitleDeathReason,
                        displayScore:
                            showScoreInHeader ? _feedController.displayScore : null,
                      ),
                      const SizedBox(height: 14),
                      if (showCollectButton)
                        _OverlayButton(
                          label: collectLabel,
                          onPressed: _onCollectPressed,
                        )
                      else
                        RestartExitButtons(
                          restartButton: _OverlayButton(
                            label: 'Restart',
                            onPressed: () => _completeThen(widget.onRestart),
                          ),
                          exitButton: widget.showExitButton
                              ? _OverlayButton(
                                  label: 'Exit',
                                  onPressed: () => _completeThen(widget.onExit),
                                )
                              : null,
                        ),
                      const SizedBox(height: 16),
                      Flexible(child: ScoreDistribution(rowLabels: rowLabels)),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: LeaderboardPanel(
                    runEndedEvent: widget.runEndedEvent,
                    scoreTuning: widget.scoreTuning,
                    tickHz: widget.tickHz,
                    revealCurrentRunScore:
                        _feedController.feedState == ScoreFeedState.complete,
                    leaderboardStore: widget.leaderboardStore,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _buildSubtitleDeathReason(RunEndedEvent? event) {
  if (event == null) return null;
  switch (event.reason) {
    case RunEndReason.gaveUp:
      return 'You gave up the run.';
    case RunEndReason.fellBehindCamera:
      return 'You fell behind.';
    case RunEndReason.fellIntoGap:
      return 'You fell into a gap.';
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
