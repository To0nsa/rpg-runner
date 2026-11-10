import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_services.dart';
import '../../app/ui_routes.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../components/app_segmented_control.dart';
import '../../controls/movement_control_mode.dart';
import '../../l10n/app_localization.dart';
import '../../state/settings/locale_settings.dart';
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
          content: Text(context.l10n.openLinkFailed(url: uri.toString())),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.controlsSaveFailed)));
    }
  }

  Future<void> _setLanguage(LocaleSettings settings, Locale locale) async {
    try {
      await settings.setLocale(locale);
    } catch (error, stack) {
      debugPrint('Language preference save failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.languageSaveFailed)));
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
            enabled
                ? context.l10n.developerModeFailed
                : context.l10n.accountLoadFailed,
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
        title: context.l10n.optionsTitle,
        centerAppBarTitle: true,
        appBarTitle: AppSegmentedControl<_OptionsTab>(
          values: _OptionsTab.values,
          selected: _tab,
          size: AppSegmentedControlSize.sm,
          enabled: !services.isSwitchingProfile,
          onChanged: (tab) => setState(() => _tab = tab),
          labelBuilder: (_, tab) => Text(switch (tab) {
            _OptionsTab.settings => context.l10n.optionsSettingsTab,
            _OptionsTab.controls => context.l10n.optionsControlsTab,
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
                        Text(
                          context.l10n.movementTitle,
                          style: ui.text.headline,
                        ),
                        SizedBox(height: ui.space.md),
                        AppSegmentedControl<MovementControlMode>(
                          values: MovementControlMode.values,
                          selected: settings.movementMode,
                          enabled: !settings.isSaving,
                          onChanged: (mode) => _setMovementMode(settings, mode),
                          labelBuilder: (_, mode) => Text(switch (mode) {
                            MovementControlMode.arrows =>
                              context.l10n.movementArrows,
                            MovementControlMode.joystick =>
                              context.l10n.movementFloatingJoystick,
                            MovementControlMode.fixedJoystick =>
                              context.l10n.movementFixedJoystick,
                          }),
                        ),
                        SizedBox(height: ui.space.md),
                        Text(context.l10n.movementHelp, style: ui.text.body),
                        SizedBox(height: ui.space.sm),
                        Text(switch (settings.movementMode) {
                          MovementControlMode.arrows =>
                            context.l10n.movementArrowsHelp,
                          MovementControlMode.joystick =>
                            context.l10n.movementFloatingHelp,
                          MovementControlMode.fixedJoystick =>
                            context.l10n.movementFixedHelp,
                        }, style: ui.text.body),
                      ],
                    );
                  },
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListenableBuilder(
                      listenable: services.localeSettings,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.languageLabel,
                            style: ui.text.headline,
                          ),
                          SizedBox(height: ui.space.sm),
                          AppSegmentedControl<Locale>(
                            values: AppLocalizations.supportedLocales,
                            selected: services.localeSettings.locale,
                            enabled: !services.localeSettings.isSaving,
                            onChanged: (locale) =>
                                _setLanguage(services.localeSettings, locale),
                            labelBuilder: (_, locale) => Text(
                              lookupAppLocalizations(locale).languageName,
                            ),
                          ),
                          SizedBox(height: ui.space.md),
                        ],
                      ),
                    ),
                    services.isPracticeOnly
                        ? Text(
                            context.l10n.developerPracticeHelp,
                            style: ui.text.body,
                          )
                        : services.canSwitchProfiles
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                title: Text(
                                  context.l10n.developerModeTitle,
                                  style: ui.text.headline,
                                ),
                                subtitle: Text(
                                  context.l10n.developerModeHelp,
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
                        : const SizedBox.shrink(),
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
                          child: Text(context.l10n.privacyPolicy),
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
                          child: Text(context.l10n.contactSupport),
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
