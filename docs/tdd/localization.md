# Localization

English/French resources cover app presentation and shared catalog text. The
[authoring guide](../localization.md) records daily commands and extension recipes;
the [glossary](../localization-glossary.md) records French terminology. Validation
and acceptance limits are recorded in the
[local verification](../verification/localization-2026-11-09.md).

## Locale ownership

English is the source language, first-launch default and unsupported-language
fallback. French is the first translation and addresses the player as **tu**.
Locale is a device preference, independent of authenticated ownership, account
selection and Developer Practice profiles. It never enters Core, replay data,
run tickets or gameplay hashes.

`AppServices` owns `LocaleSettings` beside `ControlSettings`. Production native
and web service factories supply `SharedPrefsLocaleSettingsStore`; embedding
and tests may omit storage for an in-memory preference. `ui.language.v1` stores
the selected supported BCP-47 tag. Missing, malformed or unsupported stored
values resolve to English. Loading does not rewrite invalid stored data.

Initialization restores the locale before control preferences and online service
initialization. Concurrent restores share one operation; failure can be retried.
Selection changes persist before publication. A failed save retains the previous
language, concurrent saves are rejected, and disposal fences late publication.
Profile replacement never replaces the locale owner.

`UiApp` listens to locale settings and supplies the selected locale to its existing
`MaterialApp`. Navigator keys, services and route identities remain stable.
Localization is a rebuild dependency, not a reason to recreate a run session,
recorder, controller, input state or gameplay route.

## Resources and access

Campaign movement lesson titles and per-control instructions are authored in
English/French in `chapter_defs.json`, validated by the content pipeline and
projected into the Campaign catalog. Their overlay resolves the host's supported
locale through `context.l10n`; editor presets are copied into editable source.

App messages live in `lib/ui/l10n/app_en.arb` and `app_fr.arb`. English messages
carry descriptions and typed placeholder metadata. `l10n.yaml` enables named
parameters and required resource attributes. `flutter gen-l10n` writes source
under `lib/ui/l10n/generated/` and the untranslated report beside the ARBs.
Source ARBs and generated Dart are checked in together; generated Dart is never
hand-edited. The root Pub workspace owns dependency resolution and its lockfile.

Campaign Journal titles and prose are bilingual authored content in
`chapter_defs.json`, decoded by `CampaignJournalEntry` and emitted by the existing
Campaign build. Library resolves the active locale from that catalog. The prior
fixed opening ARBs are removed; generic Journal labels/empty text remain app ARBs.

Widgets import `app_localization.dart` and read `context.l10n`. That lookup
subscribes to inherited localization changes. Non-widget presenters must receive
locale-bound resources explicitly, instead of retaining a mutable global locale.
Parameters carry authoritative values; localizations own sentences, punctuation,
plural rules and display formatting. Neither `Intl.defaultLocale` nor translated
text can be used as a persisted identifier or gameplay discriminator.

`RunnerLocalizations` is exported by `lib/runner.dart` for hosts to register
delegates and supported locales. Without the game delegate, `context.l10n` uses
the inherited supported language, falling back to English. Regional variants are
resolved through Flutter's matching algorithm after checking the language is
supported; an unrelated language always falls back to English. Hosts keep their
own delegates and own language preference persistence.

Shared message resources and descriptions live in `packages/game_presentation/lib/l10n/`.
Item names are authored in English/French in `assets/authoring/items/item_defs.json`
and compiled into `game_presentation/items.generated.dart`; they are no longer
duplicated in ARBs. The same locale-bound gear/projectile APIs resolve these names.
New items use their translated name as the fallback descriptive text, while
stats/effects remain Core-derived. See [item authoring](item_authoring.md).
The package has its own generator configuration and `GameLocalizations` delegate;
the app's `RunnerLocalizations.delegates` registers both message owners. Admin
registers shared resources with an explicit English locale. Catalog display APIs
require resources; generated item lookups cover all authored identities, with safe localized unknown
labels for retained string IDs. `ManaPresentation` selects mana or Willow's
Supplies before formatting, including complete descriptive sentences and stat
labels. Never replace words in a finished translation.

Ability and gear presenters receive both resource owners explicitly. Highlight
tokens use the same localized values as their messages. Projectile selection
legality uses Core IDs independently of its localized display model. Startup
failures retain diagnostic objects while rendering translated recovery messages;
remote diagnostic text is not a player-facing fallback.

## Layout, formatting and state

AppButton size tokens are minimum dimensions. Labels measure using the inherited
text direction and text scaler, then grow when parent constraints permit. Compact
action groups must wrap or otherwise constrain themselves; truncation is not
evidence that an action is readable. Native/device review is still required.

ICU owns plural/selector grammar; presenters pass fixed-point values converted
only for display. Rich tooltip highlighting uses the same locale-formatted values
and recognizes decimal commas and non-breaking spaces. Numeric clocks retain
`mm:ss`/24-hour `HH:mm`. Achievement dates use UTC; inbox dates use local time.
Material localization delegates load date symbols; standalone date-presenter
tests must explicitly initialize `intl` date data for their locale.

Only the reserved matching `Build N` default token is translated by
`buildDisplayName`; custom names and stored values are not rewritten. Synthetic
Developer Practice's default identity is localized at presentation, separately
from custom names. The legacy save schema cannot distinguish a user-authored
name exactly equal to its slot's reserved default, so its existing default-name
interpretation is retained.

## Inbox boundary

Delivered mail has optional versioned localized text, independent of reward
schema versions 1/2. Shared `MessageLocalization` validates the envelope and
resolves exact locale, less-specific tags, then original English fields. The
backend canonicalizes locale ordering before hashing; legacy five-field hashes
remain unchanged when the envelope is absent. See the
[inbox contract](system_inbox.md#localized-content) for immutable retries,
receipt retention, operator authoring and deployment order. Locale selection
never changes reward authority or requires a callable locale argument.

## Enforcement and verification

`dart run tool/localization.dart check` verifies exact keys, metadata/placeholder
parity, equal app/shared supported locales, generated freshness and source
literals. Generated output is compared against isolated temporary generation;
the check does not modify checked-in resources or generated files. The source
gate has AST rules for technical contexts and exact, justified exceptions with
staleness checking. It is not a whole-program data-flow or translation-quality
proof. The dedicated CI job runs this check and localization regressions.

Focused tests cover malformed saved preferences, French persistence, failed and
concurrent writes, disposal, inherited French variants, route/navigator identity,
French Options, compact achievements and inbox layout/switching, catalog tooltip
coverage, default/custom names and malformed localized mail. Backend emulator
tests exercise legacy hashes, translated-content retries and claims/deletions.
These are local widget/state/emulator checks, not Android or live deployment
acceptance. Human linguistic review remains separate from automated parity.
