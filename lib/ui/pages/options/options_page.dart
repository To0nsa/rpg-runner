import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_services.dart';
import '../../app/ui_routes.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../components/app_segmented_control.dart';
import '../../controls/movement_control_mode.dart';
import '../../state/settings/control_settings.dart';
import '../../state/app/app_state.dart';
import '../../theme/ui_tokens.dart';

/// App options, including the local profile switch in development builds.
class OptionsPage extends StatefulWidget {
  const OptionsPage({this.openUrl = _openExternal, super.key});

  final Future<bool> Function(Uri) openUrl;

  @override
  State<OptionsPage> createState() => _OptionsPageState();
}

Future<bool> _openExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

enum _OptionsTab { settings, controls }

class _OptionsPageState extends State<OptionsPage> {
  _OptionsTab _tab = _OptionsTab.settings;
  bool _openingLink = false;

  Future<void> _openLink(Uri uri) async {
    if (_openingLink) return;
    setState(() => _openingLink = true);
    var opened = false;
    try {
      opened = await widget.openUrl(uri);
    } catch (_) {
      // A missing browser/mail handler must leave account navigation usable.
    }
    if (!mounted) return;
    setState(() => _openingLink = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open $uri. You can open it manually.'),
        ),
      );
    }
  }

  Future<void> _setMovementMode(
    ControlSettings settings,
    MovementControlMode mode,
  ) async {
    try {
      await settings.setMovementMode(mode);
    } catch (error, stack) {
      debugPrint('Control settings save failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save controls. Please try again.'),
        ),
      );
    }
  }

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
        centerAppBarTitle: true,
        appBarTitle: AppSegmentedControl<_OptionsTab>(
          values: _OptionsTab.values,
          selected: _tab,
          size: AppSegmentedControlSize.sm,
          enabled: !services.isSwitchingProfile,
          onChanged: (tab) => setState(() => _tab = tab),
          labelBuilder: (_, tab) => Text(switch (tab) {
            _OptionsTab.settings => 'SETTINGS',
            _OptionsTab.controls => 'CONTROLS',
          }),
        ),
        child: MenuLayout(
          child: _tab == _OptionsTab.controls
              ? ListenableBuilder(
                  listenable: services.controlSettings,
                  builder: (context, _) {
                    final settings = services.controlSettings;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Movement', style: ui.text.headline),
                        SizedBox(height: ui.space.md),
                        AppSegmentedControl<MovementControlMode>(
                          values: MovementControlMode.values,
                          selected: settings.movementMode,
                          enabled: !settings.isSaving,
                          onChanged: (mode) => _setMovementMode(settings, mode),
                          labelBuilder: (_, mode) => Text(switch (mode) {
                            MovementControlMode.arrows => 'Arrows',
                            MovementControlMode.joystick => 'Floating joystick',
                            MovementControlMode.fixedJoystick =>
                              'Fixed joystick',
                          }),
                        ),
                        SizedBox(height: ui.space.md),
                        Text(
                          'Choose how to move backward and forward. All controls use the same movement speed.',
                          style: ui.text.body,
                        ),
                        SizedBox(height: ui.space.sm),
                        Text(switch (settings.movementMode) {
                          MovementControlMode.arrows =>
                            'Hold an arrow to move in that direction.',
                          MovementControlMode.joystick => 'The joystick follows your touch within the left third of the screen.',
                          MovementControlMode.fixedJoystick => 'The joystick stays in the lower-left corner. Drag its thumb left or right to move.',
                        }, style: ui.text.body),
                      ],
                    );
                  },
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    services.isPracticeOnly
                        ? Text(
                            'Developer Practice: local play with all equipment and abilities. Account features are unavailable in this build.',
                            style: ui.text.body,
                          )
                        : services.canSwitchProfiles
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                title: Text(
                                  'Developer mode',
                                  style: ui.text.headline,
                                ),
                                subtitle: Text(
                                  'Local profile with all equipment and abilities. Practice only; no account rewards.',
                                  style: ui.text.body,
                                ),
                                value: appState.isDeveloperMode,
                                onChanged: services.isSwitchingProfile
                                    ? null
                                    : (enabled) =>
                                          _switchProfile(context, enabled),
                              ),
                              if (services.isSwitchingProfile)
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            ],
                          )
                        : Text(
                            'No additional settings available.',
                            style: ui.text.body,
                          ),
                    SizedBox(height: ui.space.md),
                    Wrap(
                      spacing: ui.space.sm,
                      children: [
                        TextButton(
                          onPressed: _openingLink
                              ? null
                              : () => _openLink(
                                  Uri.https(
                                    'rpg-runner-d7add.web.app',
                                    '/privacy-policy.html',
                                  ),
                                ),
                          child: const Text('Privacy policy'),
                        ),
                        TextButton(
                          onPressed: _openingLink
                              ? null
                              : () => _openLink(
                                  Uri(
                                    scheme: 'mailto',
                                    path: 'lothringen.rpg@gmail.com',
                                  ),
                                ),
                          child: const Text('Contact support'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
