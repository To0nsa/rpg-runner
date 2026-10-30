# Hall of Honour local verification

Date: 2026-10-30. Backend source: `8aae7711`. Client source: the Hall of Honour
implementation committed with this record. This is local/emulated evidence;
no deployment or physical-device acceptance was performed.

## Commands and results

From the repository root:

- `corepack pnpm --dir functions build` and
  `corepack pnpm --dir functions build:test`: passed.
- `dart analyze lib/ui test/ui test/support/achievement_fixtures.dart`: no issues.
- `flutter test --no-pub --dart-define=CAPTURE_ACHIEVEMENTS=true` with the ten
  files below and `--reporter expanded`: 74 passed; two achievement widget tests
  still used the previous button label/outer action hit target. After correcting
  those finders, `flutter test --no-pub test/ui/pages/meta/achievements_page_test.dart
  --reporter expanded` passed all six tests. The combined final evidence covers
  76 distinct passing tests; unchanged regression tests were not rerun.

```text
test/ui/pages/meta/achievements_page_test.dart
test/ui/pages/meta/codex_library_test.dart
test/ui/state/achievement_progress_test.dart
test/ui/state/app_state_achievements_test.dart
test/ui/state/firebase_loadout_ownership_api_test.dart
test/ui/pages/meta/town_page_test.dart
test/ui/pages/profile/profile_page_test.dart
test/ui/state/app_state_account_deletion_test.dart
test/ui/state/app_state_ownership_conflict_test.dart
test/ui/state/app_state_run_submission_test.dart
```

From `functions/`:

```text
corepack pnpm exec firebase emulators:exec --config ../firebase.test.json --project demo-rpg-runner-functions-tests --only firestore "node --test lib_test/test/ownership/achievements.test.js lib_test/test/runs/run_projection.test.js lib_test/test/ownership/ownership_callable.test.js"
```

All 100 tests passed against the local Firestore emulator. The final timestamp
range guard was then added to match Dart's date bounds; both TypeScript builds
and `node --test lib_test/test/ownership/achievements.test.js` passed again
(10 tests). Normal server timestamps and the settlement/claim integration are
unchanged; earlier emulator evidence remains applicable to those paths.

## Covered behavior

- The 10-metres OR 10-seconds boundary, natural end reasons, excluded quits,
  no historical backfill, best versus total metrics and multi-tier completion.
- Practice/Competitive/Weekly settlement, duplicate and concurrent delivery,
  atomic rollback on bad evidence, no automatic achievement gold payment.
- Row/bulk claims, fixed earned amounts, immutable completion dates, fresh-ID
  retries, concurrent claims, stale revisions, payload mismatch, spoofed amounts,
  UID mismatch, deletion barriers, overflow and malformed receipts.
- Shared TypeScript-produced fixture decoded in Dart and used by the menu.
- No optimistic wallet changes; duplicate taps, failed replies and retries;
  stale refresh, account replacement, disposal and accepted deletion fencing.
- Final-tier reward visibility, expanded dated/claimed history, account-scoped
  expansion, Developer Practice exclusion and actual Town-to-menu navigation.
- Existing Library progress animation/unlock behavior, Store, Profile, account
  deletion, ownership conflict and run-submission refresh regressions.

## Visual review and limitations

Widget rendering was inspected at 640x360 and 360x640 with 1.4x text, loading
the actual map, background and app/icon fonts. Town, collapsed and expanded
screens are reproducible with `CAPTURE_ACHIEVEMENTS=true`; transient PNGs are
under ignored `build/achievements_review/`.

The larger map name initially overflowed at narrow widths. Shared map labels
now wrap; existing Library/Town enlarged-text tests pass. Initial rendered
claim labels clipped the gold amount inside fixed-width buttons; the amount now
sits beside a short Claim/Claim all button and wraps when needed.

These checks establish local behavior with scripted client API responses and
emulated persistence. Live replay-to-menu acceptance, physical-device usability
and economy tuning remain release/playtest work. No new run protocol or Core
mechanics were introduced. The full repository suites were not run.
