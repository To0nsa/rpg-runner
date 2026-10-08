import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_services.dart';
import '../../app/ui_routes.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app/app_state.dart';
import '../../theme/ui_tokens.dart';

/// App options, including the local profile switch in development builds.
class OptionsPage extends StatelessWidget {
  const OptionsPage({super.key});

  Future<void> _switchProfile(BuildContext context, bool enabled) async {
    final services = context.read<AppServices>();
    try {
      await services.setDeveloperMode(enabled);
      if (!context.mounted) return;
      final route = services.appState.profile.namePromptCompleted
          ? UiRoutes.hub
          : UiRoutes.setupProfileName;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    } catch (error, stack) {
      debugPrint('Profile switch failed: $error\n$stack');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Could not open Developer mode. Please try again.' : 'Could not load your account. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.watch<AppServices>();
    final appState = context.watch<AppState>();
    final ui = context.ui;
    return PopScope(
      canPop: !services.isSwitchingProfile,
      child: MenuScaffold(
        title: 'Options',
        child: MenuLayout(
          child: services.developerModeAvailable
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: Text('Developer mode', style: ui.text.headline),
                      subtitle: Text(
                        'Local profile with all equipment and abilities. Practice only; no account rewards.',
                        style: ui.text.body,
                      ),
                      value: appState.isDeveloperMode,
                      onChanged: services.isSwitchingProfile
                          ? null
                          : (enabled) => _switchProfile(context, enabled),
                    ),
                    if (services.isSwitchingProfile)
                      const Center(child: CircularProgressIndicator()),
                  ],
                )
              : Text('No options available yet.', style: ui.text.body),
        ),
      ),
    );
  }
}
