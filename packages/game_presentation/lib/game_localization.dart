import 'package:flutter/widgets.dart';
import 'package:runner_core/players/player_character_definition.dart';

import 'l10n/generated/game_localizations.dart';

export 'l10n/generated/game_localizations.dart';

/// Presentation of the shared runtime mana pool; never changes resource costs.
enum ManaPresentation { mana, supplies }

ManaPresentation manaPresentationFor(PlayerCharacterId character) =>
    character == PlayerCharacterId.bountyHunter
    ? ManaPresentation.supplies
    : ManaPresentation.mana;

/// Resolves resources without process-global locale state. Non-widget consumers
/// (including Admin) choose their locale explicitly; unsupported languages use English.
GameLocalizations gameStringsFor(Locale? requested) {
  final supported = GameLocalizations.supportedLocales;
  final locale =
      requested == null ||
          !supported.any(
            (entry) => entry.languageCode == requested.languageCode,
          )
      ? const Locale('en')
      : basicLocaleListResolution([requested], supported);
  return lookupGameLocalizations(locale);
}

extension GameLocalizationContext on BuildContext {
  /// Inherited lookup keeps catalog labels reactive to language changes. Hosts
  /// without the delegate retain a bundled fallback for their inherited locale.
  GameLocalizations get gameL10n =>
      GameLocalizations.of(this) ??
      gameStringsFor(Localizations.maybeLocaleOf(this));
}
