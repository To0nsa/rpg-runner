import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/ui_routes.dart';
import '../../components/app_button.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../profile/display_name_policy.dart';
import '../../state/app_state.dart';
import '../../state/profile_flag_keys.dart';
import '../../theme/ui_tokens.dart';

class ProfileNameSetupPage extends StatefulWidget {
  const ProfileNameSetupPage({super.key});

  @override
  State<ProfileNameSetupPage> createState() => _ProfileNameSetupPageState();
}

class _ProfileNameSetupPageState extends State<ProfileNameSetupPage> {
  final _controller = TextEditingController();
  final _policy = const DisplayNamePolicy();

  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete({required bool skipped}) async {
    if (_saving) return;
    setState(() => _saving = true);

    final appState = context.read<AppState>();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await appState.updateProfile((p) {
      final flags = Map<String, bool>.from(p.flags);
      flags[ProfileFlagKeys.namePromptCompleted] = true;

      if (skipped) {
        return p.copyWith(flags: flags);
      }

      final raw = _controller.text;
      final shouldSetCooldown = p.displayName.isNotEmpty;
      return p.copyWith(
        displayName: raw.trim(),
        displayNameLastChangedAtMs: shouldSetCooldown
            ? nowMs
            : p.displayNameLastChangedAtMs,
        flags: flags,
      );
    });

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(UiRoutes.hub);
  }

  Future<void> _confirm() async {
    final err = _policy.validate(_controller.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    await _complete(skipped: false);
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return MenuScaffold(
      showAppBar: false,
      child: MenuLayout(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose your name',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is optional. You can change it later in Profile.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Display name',
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppButton(
                      label: 'Skip',
                      width: 120,
                      height: 44,
                      textStyle: ui.text.label.copyWith(fontSize: 14),
                      variant: AppButtonVariant.secondary,
                      onPressed: _saving
                          ? null
                          : () => _complete(skipped: true),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: 'Confirm',
                      width: 160,
                      height: 44,
                      textStyle: ui.text.label.copyWith(fontSize: 14),
                      onPressed: _saving ? null : _confirm,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
