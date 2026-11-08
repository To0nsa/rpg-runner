# Willow Twin Cut revision - 2026-11-08

Source: task diff on `37209a6d`, prepared locally for gameplay compatibility
`2026.11.8.4`. No deployment, account reset, remote ownership migration or device
build was performed. See the [gameplay roster](../gdd/combat/abilities/willow.md)
and [technical contract](../tdd/willow.md).

## Behavior

- Threefold Cut is removed from Core, selectable skills, store offers, gift
  issuance and the generated Admin catalog. Willow has 25 abilities.
- Twin Cut uses cells 1-8 of the add-on combo's third row for all three weapon
  families. The ninth cell begins the weapon draw and is excluded.
- The low sweep and overhead slash have separate hit windows at zero-based
  frames 3 and 6. Frame 7 is harmless recovery. Damage, costs and 7/22/10 authored
  windup/active/recovery ticks remain unchanged; no projectile is created.
- The unused `tripleStrike` enum value remains to preserve enum ordering.
  Original source artwork and the unused icon file are preserved.
- Developer Practice repairs saved Threefold Cut selections to Quick Cut in all
  three builds. Online authorization rejects the removed ID even if retained
  ownership contains it; no online migration was executed.
- Client, issuer and validator compatibility move together. The existing offline
  producer regenerated ranked route seeds. Navigation geometry and its build
  fingerprint are unchanged.

## Local validation

Commands used Dart 3.13.1 and the installed Flutter SDK under
`C:/Users/Toonsa/flutter`. Portable tests used the existing compiled test runner;
no dependency or lockfile changes were needed. Flutter commands below included
`--no-version-check --suppress-analytics` before `test --no-pub` and used
`--reporter expanded`. Portable test commands also used that reporter.

| Directory | Command / check | Result |
| --- | --- | --- |
| `packages/runner_core` | `dart ../../.dart_tool/pub/bin/test/test.dart-3.13.1.snapshot test/combat/bounty_hunter_test.dart` | 238 passed; two hits on frames 3/6 at 30/60/120 Hz; removed ID rejected |
| Root | `flutter test --no-pub test/core` | 519 passed |
| `services/replay_validator` | `dart .dart_tool/pub/bin/test/test.dart-3.13.1.snapshot test/bounty_hunter_replay_test.dart` | 19 passed; all eight blade-only poses and exactly two hit windows at 30/60/120 Hz |
| `services/replay_validator` | `dart .dart_tool/pub/bin/test/test.dart-3.13.1.snapshot test/validator_worker_test.dart` | 101 passed |
| Root | `flutter test --no-pub test/game/willow_twin_cut_render_test.dart test/ui/icons/ability_skill_icon_test.dart test/ui/state/firebase_run_session_api_test.dart` | 12 passed |
| Root | `flutter test --no-pub test/ui/state/developer_practice_test.dart` | 17 passed, including saved removed-skill recovery |
| `tools/admin` | `flutter test --no-pub test/admin_page_test.dart` | 2 passed against regenerated catalog |
| Root | `corepack pnpm --dir functions build`; `corepack pnpm --dir functions build:test` | Passed; final build repeated after route generation |
| `functions` | `node --test lib_test/test/ownership/bounty_hunter.test.js lib_test/test/runs/compatibility.test.js lib_test/test/runs/practice_routes.test.js lib_test/test/abuse/app_check_diagnostics.test.js` | 18 passed without an emulator |
| Root | `node functions/tool/refresh_navigation_routes.mjs`; `node tools/admin/service/catalog.mjs --write-fixture`; `node tools/admin/service/catalog.mjs --check-fixture` | Generated and checked locally |
| Root | `dart --packages=.dart_tool/package_config.json packages/runner_core/tool/update_navigation_revision.dart --check` | Existing fingerprint is fresh |
| Root / worker | `dart --suppress-analytics analyze` on Core and changed client, presentation, renderer-test and worker/test paths | No issues |

The renderer test compares every emitted frame pixel-for-pixel with the first
eight source cells for pistol, crossbow and shotgun. The resulting contact sheet
at `.tmp/willow_twin_cut_review.png` was visually inspected: two blade swings,
with no weapon-draw or firing poses. This is local renderer verification, not
device acceptance.

Compiled the worker with `dart --suppress-analytics compile exe bin/server.dart
-o ../../.tmp/willow_twin_validator.exe`, then ran the executable with
`benchmark --ticks=36000 --strict`. All gates passed: Forest 1.644s and Field
1.357s for 36,000 ticks each, deterministic repeats and sustained progress.
The fixture has generated terrain and no combat objectives; it does not establish
container or device performance. Raw logs and images remain under `.tmp/`.

Initial test development exposed the existing debug assertion for an unknown
ability and a nullable snapshot-frame access in the new replay test. The final
removal regression exercises loadout validation, and the replay assertion uses
the required active-animation frame. The final runs above pass.
