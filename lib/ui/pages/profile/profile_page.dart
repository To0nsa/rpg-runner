import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/menu_button.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../profile/display_name_policy.dart';
import '../../state/app_state.dart';
import '../../state/profile_counter_keys.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _controller = TextEditingController();
  final _policy = const DisplayNamePolicy();
  String? _error;
  bool _saving = false;

  static const Duration _cooldown = Duration(hours: 24);

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppState>().profile;
    _controller.text = profile.displayName;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

  Future<void> _save() async {
    if (_saving) return;
    final appState = context.read<AppState>();
    final profile = appState.profile;

    final raw = _controller.text.trim();
    if (raw == profile.displayName) {
      setState(() => _error = 'Name is unchanged.');
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final active = _cooldownActive(profile.displayNameLastChangedAtMs, nowMs);
    if (active) {
      final rem = _cooldownRemaining(profile.displayNameLastChangedAtMs, nowMs);
      setState(() {
        _error =
            'You can change your name again in ${rem.inHours}h ${rem.inMinutes.remainder(60)}m.';
      });
      return;
    }

    final err = _policy.validate(raw);
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final shouldSetCooldown = profile.displayName.isNotEmpty;

    await appState.updateProfile((p) {
      return p.copyWith(
        displayName: raw,
        displayNameLastChangedAtMs: shouldSetCooldown
            ? nowMs
            : p.displayNameLastChangedAtMs,
      );
    });

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Name updated')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final profile = appState.profile;
    final gold = profile.counters[ProfileCounterKeys.gold] ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final cdActive = _cooldownActive(profile.displayNameLastChangedAtMs, nowMs);
    final cdText = cdActive
        ? _cooldownRemaining(profile.displayNameLastChangedAtMs, nowMs)
        : null;

    return MenuScaffold(
      showAppBar: false,
      child: MenuLayout(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _row('Display name', _fallbackName(profile.displayName)),
                      _row('Profile id', profile.profileId),
                      _row('Gold', gold.toString()),
                      if (cdText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Name change cooldown: ${cdText.inHours}h ${cdText.inMinutes.remainder(60)}m remaining',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Change display name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    errorText: _error,
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 12),
                MenuButton(
                  label: 'Save',
                  width: 160,
                  height: 44,
                  fontSize: 14,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            flex: 3,
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
