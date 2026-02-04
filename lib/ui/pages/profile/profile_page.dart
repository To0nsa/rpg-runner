import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/app_inline_edit_text.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../profile/display_name_policy.dart';
import '../../state/app_state.dart';
import '../../state/profile_counter_keys.dart';
import '../../state/user_profile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _policy = const DisplayNamePolicy();

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

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDisplayNameRow(profile),
                      _row('Gold', gold.toString()),
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
    final currentName = profile.displayName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 80,
            child: Text('Name', style: TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: AppInlineEditText(
              text: currentName,
              displayText: _fallbackName(currentName),
              hintText: 'Enter name',
              validator: (value) => _validateDisplayName(profile, value),
              onCommit: _commitDisplayName,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
