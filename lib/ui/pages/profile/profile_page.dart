import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../components/app_button.dart';
import '../../components/app_dialog.dart';
import '../../components/app_inline_edit_text.dart';
import '../../components/gold_display.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../profile/display_name_save_error.dart';
import '../../profile/display_name_policy.dart';
import '../../state/account_deletion_api.dart';
import '../../state/app_state.dart';
import '../../state/auth_api.dart';
import '../../state/user_profile.dart';
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

  String _fallbackName(String displayName) =>
      displayName.isEmpty ? 'Guest' : displayName;

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
    if (trimmed == profile.displayName) return 'Name is unchanged.';

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final active = _cooldownActive(profile.displayNameLastChangedAtMs, nowMs);
    if (active) {
      final rem = _cooldownRemaining(profile.displayNameLastChangedAtMs, nowMs);
      return 'You can change your name again in ${rem.inHours}h ${rem.inMinutes.remainder(60)}m.';
    }

    return _policy.validate(trimmed);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Name updated')));
  }

  String _accountDeletionFailureMessage(AccountDeletionResult result) {
    switch (result.status) {
      case AccountDeletionStatus.requiresRecentLogin:
        return 'Please sign in again and retry account deletion.';
      case AccountDeletionStatus.unauthorized:
        return 'Session expired. Please restart the game and try again.';
      case AccountDeletionStatus.unsupported:
        return 'Account deletion is not available in this environment.';
      case AccountDeletionStatus.failed:
        final message = result.errorMessage?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        return 'Account deletion failed. Please try again.';
      case AccountDeletionStatus.deleted:
        return 'Account deleted.';
    }
  }

  String _playGamesLinkResultMessage(AuthLinkResult result) {
    switch (result.status) {
      case AuthLinkStatus.linked:
        return 'Play Games account linked.';
      case AuthLinkStatus.alreadyLinked:
        return 'Play Games is already linked.';
      case AuthLinkStatus.canceled:
        return 'Play Games sign-in canceled.';
      case AuthLinkStatus.unsupported:
        final unsupportedMessage = result.errorMessage?.trim();
        if (unsupportedMessage != null && unsupportedMessage.isNotEmpty) {
          return unsupportedMessage;
        }
        return 'Play Games sign-in is not available on this device.';
      case AuthLinkStatus.failed:
        final failureMessage = result.errorMessage?.trim();
        if (failureMessage != null && failureMessage.isNotEmpty) {
          return failureMessage;
        }
        return 'Could not link Play Games account. Please try again.';
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
        const SnackBar(
          content: Text('Could not link Play Games account. Please try again.'),
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
      builder: (dialogContext) => const AppConfirmDialog(
        title: 'Delete account and data?',
        message:
            'This will permanently delete your account, profile, and cloud '
            'progress for this user.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Continue',
        confirmVariant: AppButtonVariant.secondary,
      ),
    );
    return confirmed ?? false;
  }

  Future<bool> _confirmDeletionStepTwo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const AppConfirmDialog(
        title: 'Final confirmation',
        message:
            'This action cannot be undone. Delete this account permanently?',
        cancelLabel: 'Keep account',
        confirmLabel: 'Delete account',
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
      await SystemNavigator.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deletion failed. Please try again.'),
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

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final appState = context.watch<AppState>();
    final profile = appState.profile;
    final authSession = appState.authSession;
    final gold = appState.displayGold;

    return MenuScaffold(
      title: 'Profile',
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
          SizedBox(width: 80, child: Text('Name', style: labelStyle)),
          Expanded(
            child: AppInlineEditText(
              text: currentName,
              displayText: _fallbackName(currentName),
              hintText: 'Enter name',
              validator: (value) => _validateDisplayName(profile, value),
              errorTextFromError: displayNameSaveErrorText,
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
          SizedBox(width: 80, child: Text('Gold', style: labelStyle)),
          Expanded(
            child: GoldDisplay(gold: gold, variant: GoldDisplayVariant.body),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    final ui = context.ui;
    return _ProfileCardPanel(
      width: double.infinity,
      borderColor: ui.colors.danger.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danger zone',
            style: ui.text.headline.copyWith(color: ui.colors.danger),
          ),
          SizedBox(height: ui.space.xs),
          Text(
            'Delete your account and all linked player data permanently.',
            style: ui.text.body.copyWith(color: ui.colors.textMuted),
          ),
          SizedBox(height: ui.space.sm),
          Align(
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AppButton(
                  label: 'Delete account',
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
            'Upgrade guest account',
            style: ui.text.headline.copyWith(color: ui.colors.textPrimary),
          ),
          SizedBox(height: ui.space.xs),
          Text(
            'Link Play Games to keep progress across devices.',
            style: ui.text.body.copyWith(color: ui.colors.textMuted),
          ),
          SizedBox(height: ui.space.sm),
          Align(
            alignment: Alignment.center,
            child: AppButton(
              label: _playGamesLinkInFlight ? 'Linking...' : 'Link Play Games',
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
