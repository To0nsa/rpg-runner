import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/scoring/run_score_breakdown.dart';
import 'package:runner_core/tuning/score_tuning.dart';
import '../../leaderboard/leaderboard_store.dart';
import '../../state/selection_state.dart';
import 'game_over_header.dart';
import 'leaderboard_panel.dart';
import 'restart_exit_buttons.dart';
import 'score_breakdown_formatter.dart';
import 'score_distribution.dart';
import 'score_feed_controller.dart';
import '../../components/app_button.dart';
import '../../components/play_button.dart';
import '../../components/gold_display.dart';
import '../../state/run_submission_status.dart';
import '../../theme/ui_tokens.dart';
// import '../../../core/spells/spell_id.dart';

const _enableGameOverRewardRow = bool.fromEnvironment(
  'RUNNER_GAMEOVER_REWARD_ROW_ENABLED',
  defaultValue: true,
);

class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({
    super.key,
    required this.visible,
    required this.onRestart,
    this.restartInProgress = false,
    required this.onExit,
    required this.showExitButton,
    required this.levelId,
    required this.runMode,
    required this.runEndedEvent,
    required this.scoreTuning,
    required this.tickHz,
    this.provisionalGoldEarned,
    this.verifiedGold,
    this.runSubmissionStatus,
    this.leaderboardStore,
  });

  final bool visible;
  final VoidCallback onRestart;
  final bool restartInProgress;
  final VoidCallback? onExit;
  final bool showExitButton;
  final LevelId levelId;
  final RunMode runMode;
  final RunEndedEvent? runEndedEvent;
  final ScoreTuning scoreTuning;
  final int tickHz;
  final int? provisionalGoldEarned;
  final int? verifiedGold;
  final RunSubmissionStatus? runSubmissionStatus;
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
  static const double _goldCollectDurationSeconds = 0.35;
  double _goldCollectProgress = 0;
  late int _verifiedGoldBaseline;

  @override
  void initState() {
    super.initState();
    _breakdown = _buildBreakdown();
    _feedController = ScoreFeedController(
      rows: _breakdown.rows,
      totalPoints: _breakdown.totalPoints,
    );
    _verifiedGoldBaseline = _resolvedVerifiedGold();
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

  Widget? _buildGoldPanel(BuildContext context) {
    if (!_enableGameOverRewardRow) {
      return null;
    }
    final ui = context.ui;
    final earnedTotal = _resolvedEarnedGold();
    final remaining = _remainingEarnedGold();
    final actualGold = _displayedActualGold();
    if (earnedTotal <= 0 && actualGold <= 0) {
      return null;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ui.colors.shadow.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(ui.radii.sm),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ui.space.sm,
          vertical: ui.space.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gold earned: $remaining + ',
              style: ui.text.body.copyWith(
                color: ui.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            GoldDisplay(
              gold: actualGold,
              variant: GoldDisplayVariant.body,
            ),
          ],
        ),
      ),
    );
  }

  int _resolvedVerifiedGold() {
    final raw = widget.verifiedGold ?? 0;
    return raw < 0 ? 0 : raw;
  }

  int _resolvedEarnedGold() {
    if (!_enableGameOverRewardRow) {
      return 0;
    }
    final fromReward = widget.runSubmissionStatus?.reward?.provisionalGold;
    final raw = fromReward ?? widget.provisionalGoldEarned ?? 0;
    if (raw <= 0) {
      return 0;
    }
    if (widget.runSubmissionStatus?.isRewardRevoked == true) {
      return 0;
    }
    return raw;
  }

  int _collectedEarnedGold() {
    final total = _resolvedEarnedGold();
    final progress = _goldCollectProgress.clamp(0, 1);
    return (total * progress).round();
  }

  int _remainingEarnedGold() => _resolvedEarnedGold() - _collectedEarnedGold();

  int _displayedActualGold() => _verifiedGoldBaseline + _collectedEarnedGold();

  bool _hasUncollectedGold() => _remainingEarnedGold() > 0;

  Widget? _buildSubmissionStatusPanel(BuildContext context) {
    final status = widget.runSubmissionStatus;
    if (status == null) {
      return null;
    }
    final shouldShow =
        status.verificationDelayed ||
        status.phase == RunSubmissionPhase.rejected ||
        status.phase == RunSubmissionPhase.expired ||
        status.phase == RunSubmissionPhase.cancelled ||
        status.phase == RunSubmissionPhase.internalError;
    if (!shouldShow) {
      return null;
    }
    final ui = context.ui;
    final labelStyle = ui.text.body.copyWith(
      color: ui.colors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = ui.text.body.copyWith(
      color: _submissionStatusColor(status.phase, ui),
      fontWeight: FontWeight.w700,
    );

    final rows = <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Verification: ', style: labelStyle),
          Text(_submissionStatusLabel(status.phase), style: valueStyle),
        ],
      ),
    ];
    if (status.verificationDelayed) {
      rows.add(SizedBox(height: ui.space.xxs));
      rows.add(
        Text(
          'Verification delayed',
          style: ui.text.body.copyWith(color: ui.colors.danger),
        ),
      );
    }
    final statusMessage = _normalizeSubmissionStatusMessage(status.message);
    if (statusMessage != null) {
      rows.add(SizedBox(height: ui.space.xxs));
      rows.add(
        Text(
          statusMessage,
          style: ui.text.body.copyWith(color: ui.colors.textMuted),
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ui.colors.shadow.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(ui.radii.sm),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ui.space.sm,
          vertical: ui.space.xs,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
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
    if (_ticker != null) {
      return;
    }
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
    final dt = (elapsed - _lastElapsed).inMicroseconds.toDouble() / 1000000.0;
    _lastElapsed = elapsed;
    if (dt <= 0) return;

    var changed = false;
    if (_feedController.feedState == ScoreFeedState.feeding) {
      changed = _feedController.tick(dt) || changed;
    }

    if (_goldCollectProgress < 1 && _resolvedEarnedGold() > 0) {
      final next = (_goldCollectProgress + (dt / _goldCollectDurationSeconds))
          .clamp(0, 1)
          .toDouble();
      if (next != _goldCollectProgress) {
        _goldCollectProgress = next;
        changed = true;
      }
    }

    if (_feedController.feedState == ScoreFeedState.complete &&
        _goldCollectProgress >= 1) {
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
      if (_hasUncollectedGold()) {
        _startTicker();
      }
      return;
    }
    if (_feedController.feedState == ScoreFeedState.feeding) {
      _completeFeed();
      if (_hasUncollectedGold()) {
        _goldCollectProgress = 1;
      }
      setState(() {});
      return;
    }
    if (_hasUncollectedGold()) {
      _goldCollectProgress = 1;
      setState(() {});
    }
  }

  void _completeThen(VoidCallback? action) {
    if (_feedController.feedState != ScoreFeedState.complete ||
        _hasUncollectedGold()) {
      _completeFeed();
      _goldCollectProgress = 1;
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
    final ui = context.ui;

    final subtitleDeathReason = _buildSubtitleDeathReason(widget.runEndedEvent);
    final showCollectButton =
        (_feedController.totalPoints > 0 &&
            _feedController.feedState != ScoreFeedState.complete) ||
        _hasUncollectedGold();
    final showScoreInHeader =
        _feedController.feedState == ScoreFeedState.complete;
    final collectLabel = _feedController.feedState == ScoreFeedState.idle
        ? 'Collect Score'
        : 'Skip';
    final goldPanel = _buildGoldPanel(context);
    final submissionPanel = _buildSubmissionStatusPanel(context);
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
        color: ui.colors.scrim.withValues(alpha: 0.53),
        child: SafeArea(
          minimum: EdgeInsets.all(ui.space.md),
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
                        SizedBox(height: ui.space.xs + ui.space.xxs / 2),
                        goldPanel,
                      ],
                      if (submissionPanel != null) ...[
                        SizedBox(height: ui.space.xs),
                        submissionPanel,
                      ],
                      SizedBox(height: ui.space.sm + ui.space.xxs / 2),
                      if (showCollectButton)
                        AppButton(
                          label: collectLabel,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.md,
                          onPressed: _onCollectPressed,
                        )
                      else
                        RestartExitButtons(
                          restartButton: PlayButton(
                            label: 'Restart',
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.xs,
                            isLoading: widget.restartInProgress,
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
                      SizedBox(height: ui.space.md),
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
                    runMode: widget.runMode,
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
    case ProjectileId.waterBolt:
      return 'Water Bolt';
  }
}

String _submissionStatusLabel(RunSubmissionPhase phase) {
  return switch (phase) {
    RunSubmissionPhase.queued => 'Queued',
    RunSubmissionPhase.requestingUploadGrant => 'Requesting Upload Grant',
    RunSubmissionPhase.uploading => 'Uploading Replay',
    RunSubmissionPhase.finalizing => 'Finalizing',
    RunSubmissionPhase.retryScheduled => 'Retry Scheduled',
    RunSubmissionPhase.pendingValidation => 'Waiting For Verification',
    RunSubmissionPhase.validating => 'Validating',
    RunSubmissionPhase.validated => 'Validated',
    RunSubmissionPhase.rejected => 'Rejected',
    RunSubmissionPhase.expired => 'Expired',
    RunSubmissionPhase.cancelled => 'Cancelled',
    RunSubmissionPhase.internalError => 'Internal Error',
  };
}

String? _normalizeSubmissionStatusMessage(String? message) {
  if (message == null) {
    return null;
  }
  final normalized = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return null;
  }
  if (normalized.length <= 240) {
    return normalized;
  }
  return '${normalized.substring(0, 237)}...';
}

Color _submissionStatusColor(RunSubmissionPhase phase, UiTokens ui) {
  return switch (phase) {
    RunSubmissionPhase.validated => ui.colors.success,
    RunSubmissionPhase.rejected ||
    RunSubmissionPhase.expired ||
    RunSubmissionPhase.cancelled ||
    RunSubmissionPhase.internalError => ui.colors.danger,
    _ => ui.colors.accentStrong,
  };
}

/* String _spellName(SpellId id) {
  switch (id) {
    case SpellId.iceBolt:
      return 'Ice Bolt';
    case SpellId.thunderBolt:
      return 'thunder';
  }
} */
