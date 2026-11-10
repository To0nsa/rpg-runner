# English source and French localization

Status: local implementation complete and archived on 2026-11-09. Native-device
acceptance and a full French editorial review remain separate checks; see the
[verification record](../../../verification/localization-2026-11-09.md).

## Requested outcome

English remains the source, first-launch default and unsupported-language fallback.
French is the first complete translation. Player-facing app text must come from
typed localization resources; technical identifiers, protocol fields, asset paths,
diagnostics and user-authored content are not translated. Future contributors and
agents need one documented path for adding messages, catalogs and languages.

No deployment or live player-data mutation is authorized by this workstream.
Admin/editor shell translation is outside the player-game scope, but shared
presentation consumers must remain compatible and use an explicit locale.

## Worktree to preserve

At the start on 2026-11-09, unrelated edits were present in:

- `docs/gdd/combat/abilities/willow.md`
- `docs/tdd/character_builds.md`
- `lib/ui/pages/selectCharacter/build_name_action.dart`
- untracked `.flutter_tool_state`

Retain these changes. Localization of the build-name surface must preserve the
existing uncommitted behavior and player-authored names.

## Acceptance criteria

- English and French resources cover menus, bootstrap/error states, HUD, controls,
  dialogs, tooltips, names/descriptions, achievements, Codex and accessibility text.
- Language is device-wide, persisted independently of account/profile switching;
  English is the default. Locale changes rebuild presentation without replacing
  the active gameplay session, recorder or navigation state.
- Shared catalog presentation accepts locale-bound resources; no mutable global
  locale and no Flutter/localization dependency enters Core or run protocol.
- Dynamic descriptions preserve authoritative values and highlighting; templates
  support complete sentences, plural rules and locale-aware numeric formatting.
- Catalog IDs and saved identities remain stable. Generated files remain generated.
- Legacy inbox hashes/retries/claims remain valid. Future automatic/operator
  messages have explicit versioned localization and legacy fallback behavior.
- Localization checks reject missing keys, incompatible placeholders and new
  hardcoded player text; exclusions are narrow, justified and reviewable.
- Focused tests cover language lifecycle, formatting, catalog completeness, legacy
  compatibility and representative compact layouts. Device acceptance is recorded
  separately from widget or local browser evidence.
- Implemented contracts, contributor recipes, glossary and agent routing are kept
  current, with one repeatable validation entry point and honest evidence limits.

## Milestones

- [x] M1: Inventory player text and settle resource ownership, locale lifecycle,
  generated-source policy, translator metadata and shared-consumer contracts.
- [x] M2: Implement English/French generation, locale settings and app/embedding
  integration; verify persistence, fallback and lifecycle behavior.
- [x] M3: Migrate shared catalog text and dynamic descriptions, then app surfaces,
  Codex, formatters and accessibility. Preserve all existing gameplay values.
- [x] M4: Implement compatible server-message localization and update every
  affected producer, decoder, operator consumer and test.
- [x] M5: Add enforcement, contributor/translator documentation, glossary and
  localization-specific agent workflow/routing; verify their failure cases.
- [x] M6: Review the full task diff, run affected checks and visual acceptance,
  record limitations, then archive this plan with repaired incoming links.

## Initial decisions and historical evidence

- French uses **tu**, explicitly selected by the user. Keep this register across
  onboarding, instructions, errors and narrative addresses to the player.

- Use Flutter `gen-l10n` with English ARB templates and generated source imports.
  Context7 was unavailable; current official Flutter internationalization docs
  were consulted instead. Do not use the removed synthetic `flutter_gen` package.
- App-only text belongs to the app; shared item/ability presentation remains in
  `game_presentation`. Resources are passed explicitly to non-widget presenters.
- Existing `ControlSettings` provides the device-owned persistence/lifetime pattern.
- Existing inbox title/body bytes participate in immutable delivery hashes. Never
  translate those persisted legacy bytes in place or change old hashing semantics.
- Existing tooltip code composes English fragments and substitutes resource names;
  migration must replace that with complete messages and typed parameters.
- `flutter pub get` at the root: passed; added only `flutter_localizations` and
  `intl` to the shared lockfile. Initial generation failed because its untranslated
  report targeted a missing directory; the report now lives beside its ARBs.
- Root `flutter test test/ui/state/locale_settings_test.dart
  test/ui/bootstrap/localization_test.dart test/ui/pages/options/options_page_test.dart
  test/ui/bootstrap/ui_app_startup_test.dart test/ui/bootstrap/app_services_test.dart`:
  21 passed, one Options failure because the temporary error snackbar covered the
  next link on the compact viewport. The test now waits for normal dismissal.
- Root `flutter test --no-pub test/ui/bootstrap/localization_test.dart
  test/ui/pages/options/options_page_test.dart`: all 4 passed, including the added
  French Options compact layout check. These are local tests, not device evidence.
- App locale infrastructure, generated resources, Options and an initial HUD
  slice are implemented. Shared catalogs, remaining app text, inbox compatibility,
  full enforcement and complete French review remain open.
- Additional unrelated animation/training edits appeared in the shared checkout
  during this work. Preserve those Core, test and documentation changes too.
- The instruction checker initially rejected the expanded UI instruction chain;
  localization detail now lives in its linked workflow rather than the short
  subtree rule. Recheck the actual byte budget after this reduction.

## Integration checkpoint (2026-11-09)

- Shared catalog resources and explicit game/Admin callers are implemented.
  Ability tooltips, gear stat comparisons and resource variants use locale-bound
  resources and complete messages. Numeric charge/projectile values come from Core.
- 277 further literal uses on 41 UI surfaces are migrated. Remaining dynamic
  sentences, Codex prose, achievement/date presentation, indirect names, some
  errors/accessibility labels and server inbox content are still open.
- Root `flutter test --no-pub` for gear stats presenter, ability tag resolver,
  ability damage tooltip, gear text and ability picker presenter: **70 passed**.
  The first run exposed a lost positive-effect highlight; restored localized
  status tokens and reran the entire slice successfully.
- French catalog coverage initially exposed a retained Mana-to-Supplies word
  replacement. Replaced it with typed resource selection before formatting;
  every catalog tooltip now resolves with matching highlight tokens in en/fr.
- Root `flutter test --no-pub` for localized catalog, loader page, localization
  lifecycle and profile page: **18 passed**. Root `dart analyze lib/ui
  test/ui/text/localized_catalog_test.dart test/ui/bootstrap test/ui/run`: passed.
  These are local tests, not complete translation, device or live inbox evidence.
- Bootstrap/run errors resolve resources at presentation; known remote profile
  failures map to local recovery messages instead of exposing server diagnostics.
  Ranked leaderboard state stores returned data rather than localized text.
- `node tools/agents/check.mjs` passed after reducing the instruction-chain size
  to 28,640 of 28,672 bytes. Put additional details in linked workflows/docs.

## Completion checkpoint (2026-11-09)

All six milestones are complete locally. English and French each contain 625 app
and 312 shared messages. The source/resource/generated check and affected analysis
pass. The broad UI/tool run passed 702 tests with one existing skip; the final
surface regression slice passed 39. Backend inbox tests passed 28 against the
local emulator, and offline Admin service tests passed 12. Final controller/page
checks passed, including French authoring and receipt matching. French achievement
actions were visually checked at 640×360 and 1.4 text scale after fixing clipping.

The [verification record](../../../verification/localization-2026-11-09.md)
contains commands, findings and remaining acceptance limits. No deployment or live
delivery occurred. Future changes start with the
[authoring guide](../../../localization.md) and
[agent workflow](../../../../.agent/workflows/change-localization.md).

Scratch migration scripts under ignored `build/` are one-time aids, not shipped
tools; do not rerun them blindly. The AST inventory includes technical literals,
so its totals are not untranslated-message counts. Preserve unrelated work when
formatting or reviewing the task diff.
