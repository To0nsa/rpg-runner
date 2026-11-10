# English source and first French translation — local verification

Source: the uncommitted localization worktree on base
`c1e0e9c0b9a2e445171e745d8692e8bf98474bb0`, 2026-11-09, Flutter 3.47.1 /
Dart 3.13.1. Existing Willow/build documentation and build-name interaction edits
were preserved. This records local implementation evidence, not deployment.

## Delivered scope

- English source/default/fallback; French using **tu**; device-wide persisted
  selection independent of account replacement and the active run.
- 625 app and 312 shared catalog messages per language, with typed generation,
  complete sentence/plural/select resources, explicit formatting and semantic
  resource variants. App, HUD, controls, Codex, achievement and error surfaces
  consume these resources; custom player strings are preserved.
- Optional versioned inbox translations with unchanged legacy hashing,
  immutable retry/claim/delete behavior, bilingual future level mail, Admin
  French authoring and translation-bound previews/receipts.
- Source/resource/generated checks, CI, contributor recipes, French glossary
  and agent ownership/handoff workflow. Core, run protocol and gameplay hashes
  were not changed by localization.

## Checks

All commands ran from the repository root unless specified. Long logs and local
screenshots are ignored under `build/`; they are not release artifacts.

| Command/scope | Result |
| --- | --- |
| `flutter pub get` (root workspace) | Passed; `flutter_localizations` and `intl` added, existing analyzer/YAML promoted to explicit tooling dependencies |
| `dart run tool/localization.dart check` | Passed: en/fr parity, placeholder/context validation, source literal audit, temporary generation versus checked-in outputs |
| `dart analyze lib/ui packages/game_presentation tools/admin/lib tools/admin/test test/ui test/tool/localization_checks_test.dart tool/localization.dart tool/localization_checks.dart` | No issues |
| `flutter test --no-pub test/ui test/tool/localization_checks_test.dart test/tool/level_definition_generation_test.dart` | 702 passed, one existing `DEVELOPER_PRACTICE`-gated skip |
| Final surface slice: localization lifecycle, profile-name setup, character selection, loadout Phase 4, achievements, profile; `--dart-define=CAPTURE_ACHIEVEMENTS=true` | 39 passed after final persistent-error locale handling and button sizing; includes the new save-error language-switch regression |
| `corepack pnpm --dir functions build` and `build:test` | Passed |
| `corepack pnpm --dir functions exec firebase emulators:exec --config ../firebase.test.json --project demo-rpg-runner-functions-tests --only firestore "node --test lib_test/test/inbox/*.test.js"` | 28 passed against local demo-project Firestore emulator |
| `corepack pnpm admin:test:service` | 12 passed, injected offline delivery only |
| Admin `flutter test --no-pub` from `tools/admin` | Initial six passed, including local child service and generated catalog rendering |
| Final Admin controller/page slices | Four controller and two page tests passed; translated drafts survive restore, altered translation receipts fail, French fields reach the real offline preview/send flow |
| `node tools/admin/service/catalog.mjs --check-fixture` | Passed; backend catalog unchanged |
| `node tools/agents/check.mjs` | Passed; largest instruction chain 28,640 / 28,672 bytes |
| `git diff --check` and affected documentation links | Passed after archiving the completed plan; all relative file links exist in 16 affected Markdown files |

## Failures found and resolved

Standalone achievement/date tests initially lacked `intl` date initialization;
widget hosts now load the actual localization delegates. Old test assertions
were updated for explicit resource arguments, canonical character display names,
English date order and grouped quantities. A retained Mana-to-Supplies word
replacement was removed in favor of semantic message selection; rich-tooltip
highlight checks were rerun.

The first rendered French achievement screen clipped reward actions despite no
layout-overflow exception. AppButton now treats dimensions as minima, measures
the inherited locale/style/text scale, and includes both border layers. The final
640×360 screenshot at 1.4 text scale was visually inspected: **Tout récupérer**
and **Récupérer** are fully visible. A `RenderParagraph.didExceedMaxLines` check
preserves this regression. The refreshed capture is
`build/achievements_review/french-expanded-640.png`.

## Acceptance limits

No live mail, rollout gate, cloud data, release artifact or deployment was
mutated. Backend rollout must precede new translated issuance; older backend
readers must not discard envelopes when removing localized mail. See the
[inbox contract](../tdd/system_inbox.md#localized-content).

The new CI workflow was prepared locally; hosted CI and branch protection were
not exercised. Android/iOS device acceptance, screen-reader listening and a
native-speaker editorial review of all French prose remain separate checks.
English-only historical/operator mail intentionally falls back to its original
text. Static source checks are not whole-program data-flow or linguistic proof.

Start future changes with the [authoring guide](../localization.md) and
[agent workflow](../../.agent/workflows/change-localization.md).
