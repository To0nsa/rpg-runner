import 'package:flutter/widgets.dart';
import 'package:game_presentation/game_localization.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Localization configuration for standalone and embedded game surfaces. Hosts
/// keep their own delegates and add these to MaterialApp.localizationsDelegates.
/// Locale selection is presentation-only; the host owns any preference storage.
abstract final class RunnerLocalizations {
  static const delegates = [
    GameLocalizations.delegate,
    ...AppLocalizations.localizationsDelegates,
  ];
  static const supportedLocales = AppLocalizations.supportedLocales;
}

/// Matches supported language variants and falls back to English. Does not read
/// or change process-wide Intl state, account state, or the device's settings.
Locale resolveAppLocale(Locale? requested) {
  if (requested == null ||
      !AppLocalizations.supportedLocales.any(
        (locale) => locale.languageCode == requested.languageCode,
      )) {
    return const Locale('en');
  }
  return basicLocaleListResolution([
    requested,
  ], AppLocalizations.supportedLocales);
}

extension AppLocalizationContext on BuildContext {
  /// Subscribes to locale changes. Hosts without the app delegate use bundled
  /// translations for their inherited locale, or English when none is supported.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ??
      lookupAppLocalizations(
        resolveAppLocale(Localizations.maybeLocaleOf(this)),
      );
}

/// Explicit resources for non-widget presenters and tests. Null means English.
AppLocalizations appStringsFor(Locale? locale) =>
    lookupAppLocalizations(resolveAppLocale(locale));
