import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/app_button.dart';
import '../../components/app_inline_edit_text.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../profile/display_name_policy.dart';
import '../../state/app_state.dart';
import '../../state/auth_api.dart';
import '../../state/profile_counter_keys.dart';
import '../../state/user_profile.dart';
import '../../theme/ui_tokens.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _policy = const DisplayNamePolicy();

  static const Duration _cooldown = Duration(hours: 24);
  AuthLinkProvider? _linkingProvider;

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

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final shouldSetCooldown = profile.displayName.isNotEmpty;

    await appState.updateProfile((p) {
      return p.copyWith(
        displayName: trimmed,
        displayNameLastChangedAtMs: shouldSetCooldown
            ? nowMs
            : p.displayNameLastChangedAtMs,
      );
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Name updated')));
  }

  String? _displayNameSaveError(Object error) {
    final raw = '$error'.toLowerCase();
    if (raw.contains('already-exists') || raw.contains('already exists')) {
      return 'That name is already taken.';
    }
    return null;
  }

  bool _isLinking(AuthLinkProvider provider) => _linkingProvider == provider;

  Future<void> _linkAccount(AuthLinkProvider provider) async {
    if (_linkingProvider != null) return;
    setState(() => _linkingProvider = provider);
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await appState.linkAuthProvider(provider);
      if (!mounted) return;
      final providerName = _providerDisplayName(provider);
      final message = _linkResultMessage(result, providerName);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not link ${_providerDisplayName(provider)} account.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _linkingProvider = null);
      }
    }
  }

  String _providerDisplayName(AuthLinkProvider provider) {
    return switch (provider) {
      AuthLinkProvider.google => 'Google',
      AuthLinkProvider.playGames => 'Play Games',
    };
  }

  String _linkResultMessage(AuthLinkResult result, String providerName) {
    return switch (result.status) {
      AuthLinkStatus.linked => '$providerName account linked.',
      AuthLinkStatus.alreadyLinked => '$providerName is already linked.',
      AuthLinkStatus.canceled => '$providerName sign-in canceled.',
      AuthLinkStatus.unsupported =>
        result.errorMessage ?? '$providerName sign-in is not available here.',
      AuthLinkStatus.failed =>
        result.errorCode == null
            ? 'Could not link $providerName account.'
            : 'Could not link $providerName account (${result.errorCode}).',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final appState = context.watch<AppState>();
    final profile = appState.profile;
    final gold = profile.counters[ProfileCounterKeys.gold] ?? 0;

    return MenuScaffold(
      title: 'Profile',
      showAppBar: true,
      child: MenuLayout(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(ui.space.md),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ui.colors.outline,
                      width: ui.sizes.borderWidth,
                    ),
                    borderRadius: BorderRadius.circular(ui.radii.md),
                  ),
                  child: Column(
                    children: [
                      _buildDisplayNameRow(profile),
                      _buildAccountRow(appState.authSession),
                      _row('Gold', gold.toString()),
                      _buildManageLinkedAccounts(appState.authSession),
                    ],
                  ),
                ),
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
              errorTextFromError: _displayNameSaveError,
              onCommit: _commitDisplayName,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountRow(AuthSession session) {
    final linkedCount = session.linkedProviders.length;
    final value = session.isAnonymous
        ? 'Guest (Anonymous)'
        : linkedCount == 0
        ? 'Registered'
        : 'Registered ($linkedCount linked)';
    return _row('Account', value);
  }

  Widget _buildManageLinkedAccounts(AuthSession session) {
    final ui = context.ui;
    return Padding(
      padding: EdgeInsets.only(top: ui.space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage linked accounts',
            style: ui.text.label.copyWith(color: ui.colors.textMuted),
          ),
          SizedBox(height: ui.space.xs),
          _buildProviderLinkRow(session, AuthLinkProvider.google),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            _buildProviderLinkRow(session, AuthLinkProvider.playGames),
        ],
      ),
    );
  }

  Widget _buildProviderLinkRow(AuthSession session, AuthLinkProvider provider) {
    final ui = context.ui;
    final isLinked = session.isProviderLinked(provider);
    final canLink = !isLinked && _linkingProvider == null;
    final providerName = _providerDisplayName(provider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              providerName,
              style: ui.text.label.copyWith(color: ui.colors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              isLinked ? 'Linked' : 'Not linked',
              style: ui.text.body.copyWith(color: ui.colors.textPrimary),
            ),
          ),
          AppButton(
            label: _isLinking(provider)
                ? 'Linking...'
                : isLinked
                ? 'Linked'
                : 'Link $providerName',
            size: AppButtonSize.xs,
            onPressed: canLink ? () => _linkAccount(provider) : null,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    final ui = context.ui;
    final labelStyle = ui.text.label.copyWith(color: ui.colors.textMuted);
    final valueStyle = ui.text.body.copyWith(color: ui.colors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: labelStyle)),
          Expanded(
            child: Text(
              value,
              style: valueStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
