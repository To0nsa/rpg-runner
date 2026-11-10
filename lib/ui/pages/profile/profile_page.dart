import '../../text/number_format.dart';

import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../components/app_button.dart';
import '../../components/app_dialog.dart';
import '../../components/app_inline_edit_text.dart';
import '../../components/gold_display.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../components/player_level_bar.dart';
import '../../profile/display_name_save_error.dart';
import '../../profile/display_name_policy.dart';
import '../../state/profile/account_deletion_api.dart';
import '../../state/app/app_state.dart';
import '../../state/auth/auth_api.dart';
import '../../state/profile/user_profile.dart';
import '../../state/ownership/player_progress.dart';
import '../../theme/ui_tokens.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _policy = const DisplayNamePolicy();
  bool _deleteInFlight = false;
  bool _playGamesLinkInFlight = false;
  static const Key _deleteProgressIndicatorKey = Key(
    'profile-delete-progress-indicator',
  );

  static const Duration _cooldown = Duration(hours: 24);

  String _fallbackName(String displayName) => displayName.isEmpty
      ? context.l10n.uiGuest
      : context.read<AppState>().isDeveloperMode && displayName == 'Developer'
      ? context.l10n.developerIdentity
      : displayName;

  bool _cooldownActive(int lastChangedAtMs, int nowMs) {
    if (lastChangedAtMs <= 0) return false;
    return nowMs - lastChangedAtMs < _cooldown.inMilliseconds;
  }

  Duration _cooldownRemaining(int lastChangedAtMs, int nowMs) {
    final elapsed = nowMs - lastChangedAtMs;
    final remainingMs = _cooldown.inMilliseconds - elapsed;
    final clampedMs = remainingMs.clamp(0, _cooldown.inMilliseconds).toInt();
    return Duration(milliseconds: clampedMs);
  }

  String? _validateDisplayName(UserProfile profile, String raw) {
    final trimmed = raw.trim();
    if (trimmed == profile.displayName) return context.l10n.uiNameIsUnchanged;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final active = _cooldownActive(profile.displayNameLastChangedAtMs, nowMs);
    if (active) {
      final rem = _cooldownRemaining(profile.displayNameLastChangedAtMs, nowMs);
      return context.l10n.nameChangeCooldown(
        hours: rem.inHours,
        minutes: rem.inMinutes.remainder(60),
      );
    }

    return _policy.validate(trimmed)?.message(context.l10n);
  }

  Future<void> _commitDisplayName(String raw) async {
    final appState = context.read<AppState>();
    final profile = appState.profile;
    final trimmed = raw.trim();
    if (trimmed == profile.displayName) {
      return;
    }
    await appState.updateDisplayName(trimmed);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.uiNameUpdated)));
  }

  String _accountDeletionFailureMessage(AccountDeletionResult result) {
    switch (result.status) {
      case AccountDeletionStatus.requested:
      case AccountDeletionStatus.inProgress:
      case AccountDeletionStatus.retrying:
        return context.l10n.uiAccountDeletionIsInProgress;
      case AccountDeletionStatus.requiresRecentLogin:
        return context.l10n.uiPleaseSignInAgainAndRetryAccountDeletion;
      case AccountDeletionStatus.unauthorized:
        return context.l10n.uiSessionExpiredPleaseRestartTheGameAndTryAgain;
      case AccountDeletionStatus.unsupported:
        return context.l10n.uiAccountDeletionIsNotAvailableInThisEnvironment;
      case AccountDeletionStatus.failed:
        return context.l10n.uiAccountDeletionFailedPleaseTryAgain;
      case AccountDeletionStatus.deleted:
        return context.l10n.uiAccountDeleted;
    }
  }

  String _playGamesLinkResultMessage(AuthLinkResult result) {
    switch (result.status) {
      case AuthLinkStatus.linked:
        return context.l10n.uiPlayGamesAccountLinked;
      case AuthLinkStatus.alreadyLinked:
        return context.l10n.uiPlayGamesIsAlreadyLinked;
      case AuthLinkStatus.canceled:
        return context.l10n.uiPlayGamesSignInCanceled;
      case AuthLinkStatus.unsupported:
        return context.l10n.uiPlayGamesSignInIsNotAvailableOnThisDevice;
      case AuthLinkStatus.failed:
        return context.l10n.uiCouldNotLinkPlayGamesAccountPleaseTryAgain;
    }
  }

  bool _shouldShowPlayGamesUpgrade(AuthSession session) {
    return session.isAuthenticated &&
        session.isAnonymous &&
        !session.isProviderLinked(AuthLinkProvider.playGames);
  }

  Future<void> _linkPlayGames() async {
    if (_playGamesLinkInFlight) {
      return;
    }
    setState(() {
      _playGamesLinkInFlight = true;
    });
    try {
      final appState = context.read<AppState>();
      final result = await appState.linkAuthProvider(
        AuthLinkProvider.playGames,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_playGamesLinkResultMessage(result))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.uiCouldNotLinkPlayGamesAccountPleaseTryAgain,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _playGamesLinkInFlight = false;
        });
      }
    }
  }

  Future<bool> _confirmDeletionStepOne() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        title: context.l10n.uiDeleteAccountAndData,
        message: context.l10n.deleteAccountBody,
        cancelLabel: context.l10n.uiCancel,
        confirmLabel: context.l10n.uiContinue,
        confirmVariant: AppButtonVariant.secondary,
      ),
    );
    return confirmed ?? false;
  }

  Future<bool> _confirmDeletionStepTwo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        title: context.l10n.uiFinalConfirmation,
        message:
            context.l10n.uiThisActionCannotBeUndoneDeleteThisAccountPermanently,
        cancelLabel: context.l10n.uiKeepAccount,
        confirmLabel: context.l10n.uiDeleteAccount,
        confirmVariant: AppButtonVariant.danger,
        buttonSize: AppButtonSize.md,
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteAccountAndData() async {
    if (_deleteInFlight) {
      return;
    }
    final stepOneConfirmed = await _confirmDeletionStepOne();
    if (!stepOneConfirmed || !mounted) {
      return;
    }
    final stepTwoConfirmed = await _confirmDeletionStepTwo();
    if (!stepTwoConfirmed || !mounted) {
      return;
    }

    setState(() {
      _deleteInFlight = true;
    });

    try {
      final appState = context.read<AppState>();
      final result = await appState.deleteAccountAndData();
      if (!mounted) return;
      if (!result.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_accountDeletionFailureMessage(result))),
        );
        return;
      }
      await _finishAccountDeletion(result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.uiAccountDeletionFailedPleaseTryAgain),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deleteInFlight = false;
        });
      }
    }
  }

  Future<void> _finishAccountDeletion(AccountDeletionResult result) async {
    if (!mounted) return;
    if (!result.localCleanupSucceeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .l10n
                .uiAccountDeletionWasAcceptedDeviceCleanupNeedsAnotherAttempt,
          ),
          action: SnackBarAction(
            label: context.l10n.uiRetryCleanup,
            onPressed: () async {
              final retry = await context
                  .read<AppState>()
                  .retryAccountDeletionLocalCleanup();
              if (mounted) await _finishAccountDeletion(retry);
            },
          ),
        ),
      );
      return;
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final appState = context.watch<AppState>();
    final profile = appState.profile;
    final authSession = appState.authSession;
    final gold = appState.displayedGold;
    final progression = appState.progression;

    return MenuScaffold(
      title: context.l10n.uiProfile,
      child: MenuLayout(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProfileCardPanel(
                  child: Column(
                    children: [
                      _buildDisplayNameRow(profile),
                      _buildGoldRow(gold),
                    ],
                  ),
                ),
                SizedBox(height: ui.space.md),
                _ProfileCardPanel(
                  width: double.infinity,
                  child: _buildStatsPanel(
                    appState.displayedPlayerProgress,
                    progression.enemyDefeats.total,
                  ),
                ),
                SizedBox(height: ui.space.md),
                if (_shouldShowPlayGamesUpgrade(authSession)) ...[
                  _buildPlayGamesUpgradeCard(),
                  SizedBox(height: ui.space.md),
                ],
                _buildDangerZoneCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayNameRow(UserProfile profile) {
    final ui = context.ui;
    final currentName = profile.displayName;
    final labelStyle = ui.text.label.copyWith(color: ui.colors.textMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(context.l10n.uiName, style: labelStyle),
          ),
          Expanded(
            child: AppInlineEditText(
              text: currentName,
              displayText: _fallbackName(currentName),
              hintText: context.l10n.uiEnterName,
              validator: (value) => _validateDisplayName(profile, value),
              errorTextFromError: (error) =>
                  displayNameSaveErrorText(error, context.l10n),
              onCommit: _commitDisplayName,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldRow(int gold) {
    final ui = context.ui;
    final labelStyle = ui.text.label.copyWith(color: ui.colors.textMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(context.l10n.uiGold, style: labelStyle),
          ),
          Expanded(
            child: GoldDisplay(gold: gold, variant: GoldDisplayVariant.body),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(PlayerProgress progress, int enemyKills) {
    final ui = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.uiPlayerStats, style: ui.text.headline),
        SizedBox(height: ui.space.sm),
        PlayerLevelBar(progress: progress),
        SizedBox(height: ui.space.sm),
        _statRow(
          context.l10n.uiLifetimeXp,
          formatCount(progress.totalXp, l10n: context.l10n),
        ),
        _statRow(
          context.l10n.uiPracticeRunsPlayed,
          formatCount(progress.runsInMode('practice'), l10n: context.l10n),
        ),
        _statRow(
          context.l10n.uiCompetitiveRunsPlayed,
          formatCount(progress.runsInMode('competitive'), l10n: context.l10n),
        ),
        _statRow(
          context.l10n.uiEnemiesDefeated,
          formatCount(enemyKills, l10n: context.l10n),
        ),
        _statRow(context.l10n.uiDamageDealt, _hp(progress.damageDealt100)),
        _statRow(context.l10n.uiDamageTaken, _hp(progress.damageTaken100)),
      ],
    );
  }

  Widget _statRow(String label, String value) {
    final ui = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui.space.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: ui.text.body)),
          SizedBox(width: ui.space.sm),
          Text(
            value,
            style: ui.text.body.copyWith(color: ui.colors.accentStrong),
          ),
        ],
      ),
    );
  }

  String _hp(int hundredths) =>
      context.l10n.healthPoints(hp: (hundredths / 100).round());

  Widget _buildDangerZoneCard() {
    final ui = context.ui;
    return _ProfileCardPanel(
      width: double.infinity,
      borderColor: ui.colors.danger.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.uiDangerZone,
            style: ui.text.headline.copyWith(color: ui.colors.danger),
          ),
          SizedBox(height: ui.space.xs),
          Text(
            context.l10n.uiDeleteYourAccountAndAllLinkedPlayerDataPermanently,
            style: ui.text.body.copyWith(color: ui.colors.textMuted),
          ),
          SizedBox(height: ui.space.sm),
          Align(
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AppButton(
                  label: context.l10n.uiDeleteAccount,
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.sm,
                  onPressed: _deleteInFlight ? null : _deleteAccountAndData,
                ),
                if (_deleteInFlight)
                  SizedBox(
                    width: ui.sizes.iconSize.sm,
                    height: ui.sizes.iconSize.sm,
                    child: CircularProgressIndicator(
                      key: _deleteProgressIndicatorKey,
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ui.colors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayGamesUpgradeCard() {
    final ui = context.ui;
    return _ProfileCardPanel(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.uiUpgradeGuestAccount,
            style: ui.text.headline.copyWith(color: ui.colors.textPrimary),
          ),
          SizedBox(height: ui.space.xs),
          Text(
            context.l10n.uiLinkPlayGamesToKeepProgressAcrossDevices,
            style: ui.text.body.copyWith(color: ui.colors.textMuted),
          ),
          SizedBox(height: ui.space.sm),
          Align(
            alignment: Alignment.center,
            child: AppButton(
              label: _playGamesLinkInFlight
                  ? context.l10n.uiLinking
                  : context.l10n.uiLinkPlayGames,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.lg,
              onPressed: _playGamesLinkInFlight ? null : _linkPlayGames,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCardPanel extends StatelessWidget {
  const _ProfileCardPanel({required this.child, this.width, this.borderColor});

  final Widget child;
  final double? width;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      width: width,
      padding: EdgeInsets.all(ui.space.md),
      decoration: BoxDecoration(
        color: UiBrandPalette.cardBackground,
        border: Border.all(
          color: borderColor ?? ui.colors.outline,
          width: ui.sizes.borderWidth,
        ),
        borderRadius: BorderRadius.circular(ui.radii.md),
      ),
      child: child,
    );
  }
}
