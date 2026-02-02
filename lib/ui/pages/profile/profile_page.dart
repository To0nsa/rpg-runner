import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  bool _isEditing = false;

  static const Duration _cooldown = Duration(hours: 24);

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
    setState(() {
      _saving = false;
      _isEditing = false;
    });
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
                      _buildDisplayNameRow(profile.displayName),
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

  Widget _buildDisplayNameRow(String currentName) {
    if (_isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const SizedBox(
              width: 80,
              child: Text('Name', style: TextStyle(color: Colors.white70)),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 8,
                        ),
                        border: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        hintText: 'Enter name',
                        hintStyle: const TextStyle(color: Colors.white24),
                        errorText: _error,
                      ),
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  IconButton(
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.check,
                            color: Colors.greenAccent,
                            size: 20,
                          ),
                    onPressed: _saving ? null : _save,
                    tooltip: 'Save',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: _saving ? null : _cancelEditing,
                    tooltip: 'Cancel',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 80,
            child: Text('Name', style: TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _fallbackName(currentName),
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white54, size: 16),
                  onPressed: _startEditing,
                  tooltip: 'Edit name',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startEditing() {
    final profile = context.read<AppState>().profile;
    _controller.text = profile.displayName;
    setState(() {
      _isEditing = true;
      _error = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _error = null;
    });
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
