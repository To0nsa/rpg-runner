# Localization authoring

English is the source, first-launch language and fallback. French is the first
translation and uses **tu**. Start with the [technical contract](tdd/localization.md)
and [French glossary](localization-glossary.md). Player text includes accessibility,
loading, failure and empty states, not only visible menu labels.

## Owners and daily commands

| Content | Authoritative source |
| --- | --- |
| App, HUD, controls, Codex prose, achievements, recovery | `lib/ui/l10n/app_en.arb` and sibling translations |
| Reusable character/enemy/item/ability names and descriptions | `packages/game_presentation/lib/l10n/game_en.arb` and siblings |
| Automatic delivered inbox prose | `functions/src/inbox/message_text.ts` |
| Operator-authored inbox prose | Admin English/French composer or versioned CLI JSON |
| Player names and custom build names | Player data; never translate |

From the repository root, with the supported Flutter SDK on PATH:

```powershell
flutter pub get --enforce-lockfile
dart run tool/localization.dart generate
dart run tool/localization.dart check
```

`generate` runs Flutter's generator for both owners. Review ARBs and generated
files together. `check` validates resources, locale parity and source literals,
then generates into disposable temporary projects and compares every generated
Dart file. It does not repair the checkout. `audit` runs only resource/source
checks for a faster editing loop; it does not establish generated freshness.
Do not hand-edit generated files or resolve dependencies in workspace members.

## Add or change a message

1. Choose a stable semantic lowerCamelCase key in the owning English ARB. Reuse
   a key only when its meaning and grammatical role really are the same.
2. Add `@key.description`: explain the screen, speaker, intent, limits and any
   ambiguous terminology. Explain units and give examples for dynamic values.
   Do not encode English word order into the API.
3. Add every supported translation. Translation metadata can inherit source
   metadata; if supplied, placeholder types and formatting must match. Keep
   placeholder identifiers unchanged. Do not translate ICU selectors or IDs.
4. Use complete ICU messages for sentences, plural rules and select variants.
   Do not concatenate translated clauses or perform word replacements on a
   finished sentence. Pass authoritative Core values, never duplicate balance.
5. Generate, update consumers and run the check plus the affected widget or
   presenter tests. Review both languages, compact screens and enlarged text.

Example English source:

```json
{
  "rewardCount": "{count, plural, one{One reward} other{{count} rewards}}",
  "@rewardCount": {
    "description": "Inbox attachment count; count is a non-negative whole number.",
    "placeholders": {"count": {"type": "int", "format": "decimalPattern"}}
  }
}
```

French: `"{count, plural, one{Une récompense} other{{count} récompenses}}"`.
Let ICU decide French plural categories; do not copy an English `count == 1`
branch into Dart. Named parameters make call sites reviewable.

Widgets use `context.l10n` (app) or `context.gameL10n` (shared). Non-widget
presenters receive `AppLocalizations`/`GameLocalizations` explicitly. Recompute
presentation when locale changes; retain semantic state instead of cached text.
Use explicit-locale `intl` formatting for quantities, percentages and dates.
Never set `Intl.defaultLocale`. Duration clocks deliberately retain `mm:ss` and
the device clock retains 24-hour `HH:mm`; these are display conventions, not dates.
Achievement dates are UTC; inbox dates retain the existing local-time convention.

Default saved build-name tokens are resolved by `buildDisplayName`. The old save
format cannot distinguish a user name exactly equal to its reserved default;
that exact slot token continues to be treated as default. Other player strings
remain byte-for-byte unchanged, including accents and names in another language.

## Add a language

1. Add a complete ARB in **both** owners with the same `@@locale` (Flutter uses
   underscore-separated regional tags in ARBs). Copy the English keys and use
   source metadata; do not copy the generated Dart. Set `languageName` to the
   language's autonym so the selector remains usable in any current language.
2. Translate using a reviewed glossary and grammatical register. Review all ICU
   branches, punctuation, number/date examples, font coverage and line wrapping.
3. Run `generate` and `check`. Supported locales are generated from resources;
   Options and device preference validation consume that generated list. English
   remains preferred/default/fallback. App/shared locale sets must match.
4. Extend the automatic inbox catalog for **future** messages and the Admin
   language composer as needed. CLI/draft envelopes already preserve additional
   canonical language/script/region tags. Never add translations to issued mail.
5. Exercise persistence, language switching while a run is active, fresh launch,
   unsupported/regional locale fallback, screen-reader labels, compact screens
   and larger text. A new script or RTL language also needs font/asset, direction
   and native-device review; adding an ARB alone does not prove that support.

## Delivered messages and operator recovery

Admin keeps English title/body as fallback. Supply both optional French fields,
using **tu**, or leave both empty. Review all translations before sending. Partial
French drafts can be saved, but preview rejects incomplete translations. Imported
additional language variants are preserved and shown in Review. The compatibility
browser rejects translated drafts; open them in Admin to avoid losing content.

The privileged CLI accepts this additional optional field:

```json
{
  "localization": {
    "schemaVersion": 1,
    "translations": {
      "fr": {"title": "Ton cadeau", "body": "Tu peux récupérer ta récompense."}
    }
  }
}
```

Root `title`/`body` remain required English fallback. One to eight translations,
120 characters per title and 2,000 per body are allowed. Tags use canonical
`language[-Script][-REGION]`, for example `fr`, `fr-CA`, `zh-Hant-TW`; `en` is
reserved for the root fallback. The client tries the exact locale, then removes
rightmost subtags, then uses the original English fields. Old mail without the
envelope keeps its original text. Translation changes are new contents: never
edit an attempted draft or reuse its delivery ID with changed translations.

See [inbox immutability and rollout](tdd/system_inbox.md#localized-content) and the
[Admin operator guide](../tools/admin/README.md). No generation/check command
sends mail, publishes a rollout gate or deploys anything.

## Enforcement and review

The source gate uses the Dart AST across UI, rendering and shared presentation.
It checks direct labels, helper returns, interpolated literal text and accessibility
copy. Imports, exceptions, diagnostics in recognized calls, map keys, comparisons,
font names and asset paths have technical syntax rules. Exact remaining literals
are listed with reasons in `tool/localization_exceptions.json`; unused exemptions
fail. Generated authoring metadata is excluded at three explicit paths: it is
not the player's localized name source. Do not whitelist a file or a new English
phrase to bypass migration. Keep technical exceptions tied to their actual owner.

This is a static guard, not full data-flow or linguistic analysis. Review indirect
backend text and Core metadata consumers; never render raw exception messages or
derive player-facing names from IDs. Do not pass prose through a technical field
to evade the guard. Tests must cover the actual affected surface and semantic
behavior, not merely assert that a key exists.

The [localization agent workflow](../.agent/workflows/change-localization.md)
routes ownership, integration and checks. Collaborators require separate session
authorization; this authoring workflow does not start agents automatically.
