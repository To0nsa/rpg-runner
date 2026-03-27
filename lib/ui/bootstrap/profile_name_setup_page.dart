import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/ui_routes.dart';
import '../components/app_button.dart';
import '../components/menu_layout.dart';
import '../components/menu_scaffold.dart';
import '../profile/display_name_save_error.dart';
import '../profile/display_name_policy.dart';
import '../state/app/app_state.dart';
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_saving) return;
    setState(() => _saving = true);

    final appState = context.read<AppState>();

    try {
      await appState.completeNamePrompt(displayName: _controller.text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = displayNameSaveErrorText(error);
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(UiRoutes.hub);
  }

  Future<void> _confirm() async {
    final err = _policy.validate(_controller.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    await _complete();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return MenuScaffold(
      showAppBar: false,
      useBodySafeArea: true,
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
                  'This is required. You can change it later in Profile.',
                  style: ui.text.body.copyWith(color: ui.colors.textMuted),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ui.space.lg),
                TextField(
                  controller: _controller,
                  style: ui.text.body.copyWith(color: ui.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Display name',
                    labelStyle: ui.text.body.copyWith(
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
                  onChanged: (_) {
                    if (_error == null) {
                      return;
                    }
                    setState(() => _error = null);
                  },
                ),
                SizedBox(height: ui.space.md + ui.space.xxs),
                AppButton(
                  label: 'Confirm',
                  size: AppButtonSize.md,
                  onPressed: _saving ? null : _confirm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
