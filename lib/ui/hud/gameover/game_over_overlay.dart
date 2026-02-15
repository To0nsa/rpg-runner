import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/enemies/enemy_id.dart';
import '../../../core/events/game_event.dart';
import '../../../core/levels/level_id.dart';
import '../../../core/projectiles/projectile_id.dart';
import '../../../core/scoring/run_score_breakdown.dart';
import '../../../core/tuning/score_tuning.dart';
import '../../leaderboard/leaderboard_store.dart';
import '../../state/selection_state.dart';
import 'game_over_header.dart';
import 'leaderboard_panel.dart';
import 'restart_exit_buttons.dart';
import 'score_breakdown_formatter.dart';
import 'score_distribution.dart';
import 'score_feed_controller.dart';
import '../../components/app_button.dart';
// import '../../../core/spells/spell_id.dart';

class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({
    super.key,
    required this.visible,
    required this.onRestart,
    required this.onExit,
    required this.showExitButton,
    required this.levelId,
    required this.runType,
    required this.runEndedEvent,
    required this.scoreTuning,
    required this.tickHz,
    this.goldEarned,
    this.totalGold,
    this.leaderboardStore,
  });

  final bool visible;
  final VoidCallback onRestart;
  final VoidCallback? onExit;
  final bool showExitButton;
  final LevelId levelId;
  final RunType runType;
  final RunEndedEvent? runEndedEvent;
  final ScoreTuning scoreTuning;
  final int tickHz;
  final int? goldEarned;
  final int? totalGold;
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

  Widget? _buildGoldPanel() {
    final goldEarned = widget.goldEarned;
    if (goldEarned == null) return null;
    final totalGold = widget.totalGold;

    const labelStyle = TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    const valueStyle = TextStyle(
      color: Color(0xFFFFD54F),
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );

    Widget buildRow(String label, String value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: labelStyle),
          Text(value, style: valueStyle),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildRow('Gold earned', '+$goldEarned'),
            if (totalGold != null) ...[
              const SizedBox(height: 4),
              buildRow('Total gold', '$totalGold'),
            ],
          ],
        ),
      ),
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

    final dt = (elapsed - _lastElapsed).inMicroseconds.toDouble() / 1000000.0;
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
    final collectLabel = _feedController.feedState == ScoreFeedState.idle
        ? 'Collect score'
        : 'Skip';
    final goldPanel = _buildGoldPanel();
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
                        displayScore: showScoreInHeader
                            ? _feedController.displayScore
                            : null,
                      ),
                      if (goldPanel != null) ...[
                        const SizedBox(height: 10),
                        goldPanel,
                      ],
                      const SizedBox(height: 14),
                      if (showCollectButton)
                        AppButton(
                          label: collectLabel,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.xs,
                          onPressed: _onCollectPressed,
                        )
                      else
                        RestartExitButtons(
                          restartButton: AppButton(
                            label: 'Restart',
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.xs,
                            onPressed: () => _completeThen(widget.onRestart),
                          ),
                          exitButton: widget.showExitButton
                              ? AppButton(
                                  label: 'Exit',
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.xs,
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
                    levelId: widget.levelId,
                    runType: widget.runType,
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
    case DeathSourceKind.statusEffect:
      return 'You succumbed to a status effect.';
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
    case EnemyId.unocoDemon:
      return 'Unoco Demon';
    case EnemyId.grojib:
      return 'Ground enemy';
  }
}

String _projectileName(ProjectileId id) {
  switch (id) {
    case ProjectileId.unknown:
      return 'Unknown Projectile';
    case ProjectileId.iceBolt:
      return 'Ice Bolt';
    case ProjectileId.thunderBolt:
      return 'thunder Bolt';
    case ProjectileId.fireBolt:
      return 'Fire Bolt';
    case ProjectileId.acidBolt:
      return 'Acid Bolt';
    case ProjectileId.darkBolt:
      return 'Dark Bolt';
    case ProjectileId.earthBolt:
      return 'Earth Bolt';
    case ProjectileId.holyBolt:
      return 'Holy Bolt';
    case ProjectileId.throwingAxe:
      return 'Throwing Axe';
    case ProjectileId.throwingKnife:
      return 'Throwing Knife';
  }
}

/* String _spellName(SpellId id) {
  switch (id) {
    case SpellId.iceBolt:
      return 'Ice Bolt';
    case SpellId.thunderBolt:
      return 'thunder';
  }
} */
