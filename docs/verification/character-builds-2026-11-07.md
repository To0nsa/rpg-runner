# Character builds: local verification, 2026-11-07

Source: the character-build milestone following `2bfcaffc`. Work was performed
from `C:\dev\Lothringen\long-run`; pre-existing `.gitignore`, root instruction and
README naming/path edits were preserved. This is local source/test evidence,
not deployment or live account verification.

## Delivered behavior

- Three independent named builds per character; Build 1 is initially available,
  Build 2 requires confirmed level 5 and Build 3 requires level 12.
- The same locks apply in Developer Practice. Locked saved selections restore
  Build 1; its catalog equipment and skills remain available for local testing.
- One-screen chooser with art/name on the left and three buttons on the right.
  Card taps select; an unlocked button opens its own build. No Change build
  button or builder character-switch action remains.
- Builder name/edit control, 12-grapheme input limit, Save/Cancel, validation and
  retry after save failure. Schema 2 and addressed edit queues preserve slot
  identity through switching, persistence and run issuance.

See the [implemented contract](../tdd/character_builds.md).

## Checks

All commands use the repository root unless noted.

- `corepack pnpm --dir functions test`: **355 passed** against the local Firestore
  emulator. Includes ownership revisions/idempotency, lock thresholds 4/5/11/12,
  full and individual command rejection, inactive-slot isolation, active gear
  projection and run-ticket selection. No Firebase project was deployed.
  `UPDATE_RUN_COMPLETION_FIXTURE=true` regenerated the transaction-produced
  `functions/test/fixtures/run_completion_receipt_v1.json`; Dart consumed that
  fixture in the client checks. Emulator transaction-lock retries recovered.
- `corepack pnpm --dir functions build` and `build:test`: passed.
- From `functions/`, `node --test` for compiled `character_builds`, `bounty_hunter`,
  `projectile_spells` and `double_dash`: **18 passed** on the final backend source.
  An initial root-directory invocation of the projectile test failed its relative
  source lookup; running from the owning directory and the full emulator run pass.
- `flutter test --no-pub` with `selection_state_test`, `developer_practice_test`,
  `firebase_loadout_ownership_api_test`, `ownership_outbox_store_test`,
  `app_state_hybrid_sync_test`, `app_state_loadout_mask_test`,
  `run_submission_response_test`, `character_selection_page_test` and
  `developer_mode_ui_test`: **93 passed**, with one launch-flag case intentionally
  skipped in the default configuration.
- `flutter test --no-pub --dart-define=DEVELOPER_PRACTICE=true
  test/ui/bootstrap/developer_mode_ui_test.dart`: **4 passed**, including that
  launch-flag case (94 distinct passing native cases across the two runs).
- Final chooser tests exercise 1200x720, 800x450, 800x360 and 568x320 Flutter views,
  card selection, blocked taps, build routing, Unicode-aware input limits, blank
  names, cancellation, failed-save retry and rename persistence. Keyboard-inset
  checks retain the regression for the underlying gear layout shrinking behind
  the modal and verify Save remains above the keyboard.

- Final `character_selection_page_test.dart` after keyboard refinements:
  **4 passed**. Actual Flutter view sizes drive MediaQuery and keyboard geometry;
  captures were inspected, including the complete editable field and both actions
  at 568x320 with a 140-pixel keyboard inset.
- Targeted `dart analyze` and `git diff --check`: clean.

The character-body geometry from `2bfcaffc` is unchanged; its Core, replay,
editor and grounded-render evidence remains in the
[scale verification](willow-scale-and-selection-2026-11-07.md).

## Captures and limitations

`BOUNTY_HUNTER_CAPTURE=true` writes ignored local PNG evidence to `.tmp/`:
`character_builds_<width>x<height>.png`,
`character_builds_builder_<width>x<height>.png`,
`character_builds_rename_<width>x<height>.png` and
`character_builds_rename_keyboard_<width>x<height>.png` for all four view sizes.
These are actual widget-tree renders, not mockups or phone captures. No new
phone APK was installed; the user's running debug session can hot restart.

The browser-specific startup command (`flutter test --no-pub --platform chrome
 test/ui/bootstrap/web_practice_startup_test.dart`) could not start its tests.
The isolated headless Chrome target reported HTTP 404 for local
`/canvaskit/chromium/canvaskit.js` and `.wasm`. The owned test process and its
Chrome/compiler children were stopped. Browser smoke remains unverified; no
passing browser result is inferred from native tests.

Context7 was unavailable. Flutter input/dialog behavior was checked against
[TextField.maxLength](https://api.flutter.dev/flutter/material/TextField/maxLength.html),
[showDialog](https://api.flutter.dev/flutter/material/showDialog.html) and
[MediaQuery.removeViewInsets](https://api.flutter.dev/flutter/widgets/MediaQuery/MediaQuery.removeViewInsets.html).
The schema replacement resets old local presets and discards obsolete
unaddressed queues; remote profile resets and backend rollout were not performed.

## Follow-up: lock labels and 28-character names

Local changes following `6574689c` put the lock icon and `Level 5`/`Level 12`
together inside each locked build button, replacing its build name. The shared
button supports a leading icon with the existing theme and disabled styling.
Build names now allow 28 grapheme clusters across the editor, client state and
Functions validation; the schema and level thresholds are unchanged.

- Root: `flutter test --no-pub` for `character_selection_page_test.dart`,
  `selection_state_test.dart` and `app_state_hybrid_sync_test.dart`: **38 passed**.
  Covers the 28-character input/persistence boundary, rejection at 29, grapheme
  normalization and existing save/retry/selection behavior.
- Root: final `flutter test --no-pub
  test/ui/pages/select_character/character_selection_page_test.dart`: **4 passed**
  after moving both the lock and level into the button and fixing narrow-button
  clipping. A text-layout regression checks that the level labels are not
  truncated. Captures at the existing four view sizes were regenerated with
  `BOUNTY_HUNTER_CAPTURE=true`; the largest and smallest chooser renders were
  visually checked.
- Root: `corepack pnpm --dir functions build` and `build:test`: passed.
- From `functions/`: `node --test
  lib_test/test/ownership/character_builds.test.js`: **10 passed**. The bounded
  callable parser and command application accept 28 plain-text or emoji
  graphemes and preserve them in canonical state; 29-grapheme names are rejected.
- Targeted `dart analyze` on the changed UI, client state and tests: clean;
  final button/page analysis after the layout refinement: clean.
- Local source and widget checks only; no phone installation or backend deployment.
