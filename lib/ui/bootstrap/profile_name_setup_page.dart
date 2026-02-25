import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/ui_routes.dart';
import '../components/app_button.dart';
import '../components/menu_layout.dart';
import '../components/menu_scaffold.dart';
import '../profile/display_name_policy.dart';
import '../state/app_state.dart';
import '../state/profile_flag_keys.dart';
import '../theme/ui_tokens.dart';

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
                Text(
                  'Choose your name',
                  style: ui.text.title.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: ui.space.xs),
                Text(
                  'This is optional. You can change it later in Profile.',
                  style: ui.text.body.copyWith(color: ui.colors.textMuted),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ui.space.lg),
                TextField(
                  controller: _controller,
                  style: ui.text.body.copyWith(color: ui.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Display name',
                    labelStyle: ui.text.caption.copyWith(
                      color: ui.colors.textMuted,
                    ),
                    errorText: _error,
                    filled: true,
                    fillColor: ui.colors.cardBackground.withValues(alpha: 0.8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ui.radii.md),
                      borderSide: BorderSide(color: ui.colors.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ui.radii.md),
                      borderSide: BorderSide(color: ui.colors.outlineStrong),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ui.radii.md),
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                SizedBox(height: ui.space.md + ui.space.xxs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppButton(
                      label: 'Skip',
                      size: AppButtonSize.xs,
                      variant: AppButtonVariant.secondary,
                      onPressed: _saving
                          ? null
                          : () => _complete(skipped: true),
                    ),
                    SizedBox(width: ui.space.sm),
                    AppButton(
                      label: 'Confirm',
                      size: AppButtonSize.md,
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
