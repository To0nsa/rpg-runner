import '../../campaign/campaign_results_panel.dart';

import 'package:game_presentation/enemy_text.dart';
import 'package:game_presentation/gear_text.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/scoring/run_score_breakdown.dart';
import 'package:runner_core/tuning/score_tuning.dart';
import 'package:runner_core/traps/trap_id.dart';

import '../../leaderboard/leaderboard_store.dart';
import '../../state/ownership/selection_state.dart';
import 'game_over_header.dart';
import 'leaderboard_panel.dart';
import 'restart_exit_buttons.dart';
import 'score_breakdown_formatter.dart';
import 'score_distribution.dart';
import 'score_feed_controller.dart';
import '../../components/app_button.dart';
import '../../components/play_button.dart';
import '../../components/gold_display.dart';
import '../../state/run/run_submission_status.dart';
import '../../state/ownership/player_progress.dart';
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
    this.campaignMissionId,
    this.onNextCampaignMission,
    required this.runEndedEvent,
    required this.scoreTuning,
    required this.tickHz,
    this.provisionalGoldEarned,
    this.displayedGold,
    this.rewardRevision,
    this.runSubmissionStatus,
    this.replaySubmissionJournaled = true,
    this.replaySubmissionJournalError,
    this.onRetryReplayJournal,
    this.leaderboardStore,
    this.isDeveloperPractice = false,
  });

  final bool visible;
  final VoidCallback onRestart;
  final bool restartInProgress;
  final VoidCallback? onExit;
  final bool showExitButton;
  final LevelId levelId;
  final RunMode runMode;
  final String? campaignMissionId;
  final ValueChanged<String>? onNextCampaignMission;
  final RunEndedEvent? runEndedEvent;
  final ScoreTuning scoreTuning;
  final int tickHz;
  final int? provisionalGoldEarned;

  /// Wallet presentation supplied by AppState, including journaled run rewards.
  /// This amount must never authorize spending.
  final int? displayedGold;
  final int? rewardRevision;
  final RunSubmissionStatus? runSubmissionStatus;
  final bool replaySubmissionJournaled;
  final String? replaySubmissionJournalError;
  final VoidCallback? onRetryReplayJournal;
  final LeaderboardStore? leaderboardStore;

  /// Keeps the score breakdown while excluding all reward and leaderboard UI.
  final bool isDeveloperPractice;

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
      rescuedNpcs: event.stats.rescuedNpcs,
      rescuePoints: event.stats.rescuePoints,
      excludedScoreTicks: event.stats.excludedScoreTicks,
      tuning: widget.scoreTuning,
      tickHz: widget.tickHz,
    );
  }

  Widget? _buildGoldPanel(BuildContext context) {
    if (widget.isDeveloperPractice) return null;
    if (!_enableGameOverRewardRow) {
      return null;
    }
    final ui = context.ui;
    final runRewardGold = _runRewardGold();
    final runRewardXp = _runRewardXp();
    final displayedGold = (widget.displayedGold ?? 0).clamp(
      0,
      9007199254740991,
    );
    if (runRewardGold <= 0 && displayedGold <= 0 && runRewardXp <= 0) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (displayedGold > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.uiWallet,
                    style: ui.text.body.copyWith(
                      color: ui.colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GoldDisplay(
                    gold: displayedGold,
                    rewardRevision: widget.rewardRevision,
                    rewardSurface: 'game_over',
                    variant: GoldDisplayVariant.body,
                  ),
                ],
              ),
            if (runRewardGold > 0) ...[
              if (displayedGold > 0) SizedBox(height: ui.space.xxs),
              Wrap(
                spacing: ui.space.sm,
                runSpacing: ui.space.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    context.l10n.uiRunReward,
                    style: ui.text.body.copyWith(
                      color: ui.colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GoldDisplay(
                    gold: runRewardGold,
                    variant: GoldDisplayVariant.body,
                  ),
                ],
              ),
            ],
            if (runRewardXp > 0) ...[
              SizedBox(height: ui.space.xxs),
              Text(
                context.l10n.runRewardXp(xp: runRewardXp),
                style: ui.text.body.copyWith(
                  color: ui.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _runRewardGold() {
    if (!_enableGameOverRewardRow) {
      return 0;
    }
    final status = widget.runSubmissionStatus;
    if (status?.isTerminal == true && status?.isRewardFinal != true) {
      return 0;
    }
    final fromReward = status?.isRewardFinal == true
        ? status?.reward?.effectiveGoldDelta
        : status?.reward?.provisionalGold;
    final raw = fromReward ?? widget.provisionalGoldEarned ?? 0;
    if (raw <= 0) {
      return 0;
    }
    return raw;
  }

  int _runRewardXp() {
    if (widget.runMode == RunMode.campaign) return 0;
    final status = widget.runSubmissionStatus;
    if (status?.isTerminal == true && status?.isRewardFinal != true) return 0;
    return PlayerProgress.xpForScore(
      status?.serverStatus?.validatedRun?.score ?? _breakdown.totalPoints,
    );
  }

  Widget? _buildSubmissionStatusPanel(BuildContext context) {
    if (widget.isDeveloperPractice) return null;
    if (!widget.replaySubmissionJournaled) {
      final ui = context.ui;
      final journalError = widget.replaySubmissionJournalError;
      final message = journalError == null
          ? context.l10n.uiSavingReplayKeepThisScreenOpenUntilItIsSaved
          : context
                .l10n
                .uiReplayCouldNotBeSavedRetryBeforeLeavingOrExitWithoutAVerifiedReward;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                journalError == null
                    ? context.l10n.uiSavingReplay
                    : context.l10n.uiReplaySaveFailed,
                style: ui.text.body.copyWith(
                  color: journalError == null
                      ? ui.colors.textPrimary
                      : ui.colors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: ui.space.xxs),
              Text(
                message,
                style: ui.text.body.copyWith(color: ui.colors.textMuted),
                textAlign: TextAlign.center,
              ),
              if (journalError != null &&
                  widget.onRetryReplayJournal != null) ...[
                SizedBox(height: ui.space.xs),
                AppButton(
                  label: context.l10n.uiRetrySaving,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.xs,
                  onPressed: widget.onRetryReplayJournal,
                ),
              ],
            ],
          ),
        ),
      );
    }
    final status = widget.runSubmissionStatus;
    if (status == null) {
      return null;
    }
    final shouldShow =
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
          Text(context.l10n.uiVerification, style: labelStyle),
          Text(
            _submissionStatusLabel(status.phase, context.l10n),
            style: valueStyle,
          ),
        ],
      ),
    ];
    if (status.verificationDelayed) {
      rows.add(SizedBox(height: ui.space.xxs));
      rows.add(
        Text(
          context.l10n.uiVerificationDelayed,
          style: ui.text.body.copyWith(color: ui.colors.danger),
        ),
      );
    }
    final statusMessage = status.message == null
        ? null
        : context.l10n.submissionFailureBody;
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
    final ui = context.ui;

    final subtitleDeathReason = _RunEndText(
      context.l10n,
      context.gameL10n,
    )._buildSubtitleDeathReason(widget.runEndedEvent);
    final showCollectButton =
        (_feedController.totalPoints > 0 &&
        _feedController.feedState != ScoreFeedState.complete);
    final showScoreInHeader =
        _feedController.feedState == ScoreFeedState.complete;
    final collectLabel = _feedController.feedState == ScoreFeedState.idle
        ? context.l10n.uiCollectScore
        : context.l10n.uiSkip;
    final goldPanel = _buildGoldPanel(context);
    final submissionPanel = _buildSubmissionStatusPanel(context);
    final mayLeaveGameOver =
        widget.isDeveloperPractice ||
        widget.replaySubmissionJournaled ||
        widget.replaySubmissionJournalError != null;
    final rowLabels = [
      for (var i = 0; i < _feedController.rows.length; i += 1)
        formatScoreRow(
          _feedController.rows[i].row,
          _feedController.rows[i].remainingPoints,
          enemyName: (id) => enemyDisplayName(id, strings: context.gameL10n),
          l10n: context.l10n,
        ),
    ];

    return PopScope<Object?>(
      canPop: mayLeaveGameOver,
      child: SizedBox.expand(
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
                          title: widget.runMode == RunMode.campaign
                              ? (widget.runEndedEvent?.reason ==
                                        RunEndReason.missionCompleted
                                    ? context.l10n.runMissionCompleted
                                    : context.l10n.runMissionFailed)
                              : null,
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
                              label: context.l10n.uiRestart,
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.xs,
                              isLoading: widget.restartInProgress,
                              onPressed: mayLeaveGameOver
                                  ? () => _completeThen(widget.onRestart)
                                  : null,
                            ),
                            exitButton: widget.showExitButton
                                ? AppButton(
                                    label: mayLeaveGameOver
                                        ? (widget.isDeveloperPractice ||
                                                  widget
                                                      .replaySubmissionJournaled
                                              ? context.l10n.uiExit
                                              : context
                                                    .l10n
                                                    .uiExitWithoutReward)
                                        : context.l10n.uiSavingReplayLabel,
                                    variant: AppButtonVariant.secondary,
                                    size: AppButtonSize.xs,
                                    onPressed: mayLeaveGameOver
                                        ? () => _completeThen(widget.onExit)
                                        : null,
                                  )
                                : null,
                          ),
                        SizedBox(height: ui.space.md),
                        Flexible(
                          child: ScoreDistribution(rowLabels: rowLabels),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: widget.campaignMissionId != null
                        ? CampaignResultsPanel(
                            missionId: widget.campaignMissionId!,
                            completed:
                                widget.runEndedEvent?.reason ==
                                RunEndReason.missionCompleted,
                            onNext:
                                mayLeaveGameOver &&
                                    widget.onNextCampaignMission != null
                                ? (id) => _completeThen(
                                    () => widget.onNextCampaignMission!(id),
                                  )
                                : null,
                          )
                        : widget.isDeveloperPractice
                        ? Text(
                            context.l10n.practiceNoRewards,
                            style: ui.text.body,
                            textAlign: TextAlign.center,
                          )
                        : LeaderboardPanel(
                            levelId: widget.levelId,
                            runMode: widget.runMode,
                            runEndedEvent: widget.runEndedEvent,
                            scoreTuning: widget.scoreTuning,
                            tickHz: widget.tickHz,
                            revealCurrentRunScore:
                                _feedController.feedState ==
                                ScoreFeedState.complete,
                            leaderboardStore: widget.leaderboardStore,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RunEndText {
  const _RunEndText(this.l10n, this.strings);
  final AppLocalizations l10n;
  final GameLocalizations strings;

  String? _buildSubtitleDeathReason(RunEndedEvent? event) {
    if (event == null) return null;
    switch (event.reason) {
      case RunEndReason.missionCompleted:
        return l10n.runMissionCompleted;
      case RunEndReason.missionFailed:
        return l10n.runMissionFailed;
      case RunEndReason.bossEncounterFailed:
        return l10n.runBossFailed;
      case RunEndReason.gaveUp:
        return l10n.runGaveUp;
      case RunEndReason.fellBehindCamera:
        return l10n.runFellBehind;
      case RunEndReason.fellIntoGap:
        return l10n.runFellIntoGap;
      case RunEndReason.playerDied:
        return _buildDeathSubtitle(event.deathInfo);
    }
  }

  String _buildDeathSubtitle(DeathInfo? info) {
    if (info == null) return l10n.runDied;
    final trap = info.sourceTrap;
    if (trap != null) {
      if (info.kind == DeathSourceKind.statusEffect) {
        return l10n.runPoisonTrap;
      }
      return switch (trap.trapId) {
        TrapId.spike => l10n.runSpikeTrap,
        TrapId.swingingAxe => l10n.runAxeTrap,
        TrapId.poisonDarts => l10n.runPoisonDart,
      };
    }
    switch (info.kind) {
      case DeathSourceKind.projectile:
        return _buildProjectileDeath(info);
      case DeathSourceKind.meleeHitbox:
        return _buildMeleeDeath(info);
      case DeathSourceKind.statusEffect:
        return l10n.runStatusDeath;
      case DeathSourceKind.unknown:
        return l10n.runDied;
      case DeathSourceKind.spellImpact:
        return _buildSpellImpactDeath(info);
      case DeathSourceKind.trap:
        return l10n.runTrapDeath;
    }
  }

  String _buildProjectileDeath(DeathInfo info) {
    final projectileId = info.projectileId;
    if (projectileId == null) return l10n.runDied;
    final projectileName = _projectileName(projectileId);
    return l10n.runProjectileDeath(
      projectile: projectileName,
      source: info.enemyId == null ? 'none' : 'enemy',
      enemy: info.enemyId == null ? '' : _enemyName(info.enemyId!),
    );
  }

  String _buildMeleeDeath(DeathInfo info) {
    if (info.enemyId == null) return l10n.runDied;
    return l10n.runMeleeDeath(enemy: _enemyName(info.enemyId!));
  }

  String _buildSpellImpactDeath(DeathInfo info) {
    final enemyId = info.enemyId;
    if (enemyId == null) {
      return l10n.runSpellDeath;
    }
    if (enemyId == EnemyId.derf) {
      return l10n.runDerfDeath;
    }
    return l10n.runEnemySpellDeath(enemy: _enemyName(enemyId));
  }

  String _enemyName(EnemyId id) => enemyDisplayName(id, strings: strings);

  String _projectileName(ProjectileId id) {
    switch (id) {
      case ProjectileId.hunterPistol:
      case ProjectileId.hunterRoadsidePistol:
      case ProjectileId.hunterLongbarrelPistol:
        return l10n.impactBullet;
      case ProjectileId.hunterCrossbow:
      case ProjectileId.hunterLongwatchCrossbow:
      case ProjectileId.hunterHeavyLimbCrossbow:
        return l10n.impactCrossbow;
      case ProjectileId.hunterShotgun:
      case ProjectileId.hunterBrushgun:
        return l10n.impactPellet;
      default:
        return projectileDisplayName(id, strings: strings);
    }
  }
}

String _submissionStatusLabel(RunSubmissionPhase phase, AppLocalizations l10n) {
  return switch (phase) {
    RunSubmissionPhase.queued => l10n.submissionQueued,
    RunSubmissionPhase.requestingUploadGrant =>
      l10n.submissionRequestingUploadGrant,
    RunSubmissionPhase.uploading => l10n.submissionUploading,
    RunSubmissionPhase.finalizing => l10n.submissionFinalizing,
    RunSubmissionPhase.retryScheduled => l10n.submissionRetryScheduled,
    RunSubmissionPhase.pendingValidation => l10n.submissionPendingValidation,
    RunSubmissionPhase.validating => l10n.submissionValidating,
    RunSubmissionPhase.settlementPending => l10n.submissionSettlementPending,
    RunSubmissionPhase.validated => l10n.submissionValidated,
    RunSubmissionPhase.rejected => l10n.submissionRejected,
    RunSubmissionPhase.expired => l10n.submissionExpired,
    RunSubmissionPhase.cancelled => l10n.submissionCancelled,
    RunSubmissionPhase.internalError => l10n.submissionInternalError,
  };
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
