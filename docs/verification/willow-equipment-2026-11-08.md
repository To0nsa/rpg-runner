# Willow equipment verification — 2026-11-08

## Source and scope

Local Windows working tree, initially clean at `8438ff4c`, with the equipment
changes described in the [roster](../gdd/combat/gears/willow_equipment_roster.md).
A concurrent builder-state commit advanced HEAD to `d9049e98`. Concurrent Codex
and muzzle changes were preserved, including overlapping Willow source/tests.
The Core and replay results below exercised that combined working tree.
Equipment changes remain uncommitted to avoid capturing overlapping work.

Sandboxed command startup hung. Reviewed commands outside that sandbox completed;
no app configuration, credential configuration or permission settings were changed.
`dart` below denotes `C:/Users/Toonsa/flutter/bin/cache/dart-sdk/bin/dart.exe`.
No dependency changes were needed. All commands are local unless marked emulator;
Admin service/compose sends use fixtures, never real accounts.

## Checks

| Directory | Command | Result |
| --- | --- | --- |
| `packages/runner_core` | `dart test test/combat/bounty_hunter_test.dart test/combat/willow_equipment_test.dart test/combat/status_tuning_test.dart` | 233 passed; includes concurrent muzzle checks |
| Repository root | `flutter test --no-pub test/core/gear_authoring_constraints_test.dart test/core/reactive_proc_system_test.dart test/core/meta/meta_service_test.dart test/core/projectile_catalog_test.dart test/core/weapons/weapon_catalog_test.dart test/ui/pages/select_character/gear_stats_presenter_test.dart test/ui/pages/select_character/character_selection_page_test.dart test/ui/state/firebase_run_session_api_test.dart` | 61 passed |
| Repository root | `flutter test --no-pub test/ui/icons/ui_icon_coords_test.dart test/ui/state/firebase_inbox_api_test.dart test/ui/state/app_state_inbox_test.dart` | 18 passed |
| `services/replay_validator` | `dart test test/bounty_hunter_replay_test.dart` | 8 passed; recorded inputs for all ranged items and new gear |
| `services/replay_validator` | `dart test test/validator_worker_test.dart` | 99 passed; worker boundary dependencies mocked |
| `functions` | `corepack pnpm build:test`, then `node --test lib_test/test/ownership/bounty_hunter.test.js lib_test/test/ownership/character_builds.test.js lib_test/test/runs/compatibility.test.js` | Build and 19 tests passed |
| `functions` | `node --test lib_test/test/runs/practice_routes.test.js lib_test/test/runs/compatibility.test.js lib_test/test/ownership/bounty_hunter.test.js lib_test/test/abuse/app_check_diagnostics.test.js` | 17 passed after seed refresh |
| `functions` | `corepack pnpm exec firebase emulators:exec --config ../firebase.test.json --project demo-rpg-runner-functions-tests --only firestore 'node --test lib_test/test/inbox/gifts.test.js'` | 6 passed in Firestore emulator; new gear/field kit/ranged grants are idempotent and character-correct |
| Repository root | `corepack pnpm admin:test:service` | Functions build and 11 offline service tests passed |
| `tools/admin` | `flutter test --no-pub test/admin_page_test.dart` | 2 passed; all backend entries resolve and wide/narrow compose succeeds |
| Repository root | `dart analyze packages/runner_core packages/game_presentation lib/ui/pages/selectCharacter/gear lib/ui/pages/selectCharacter/gears_tab.dart lib/ui/pages/town/town_store_widgets.dart lib/game/components/projectiles/projectile_render_registry.dart lib/ui/hud/gameover/game_over_overlay.dart` | No issues |
| `services/replay_validator` | `dart analyze lib/src/validator_worker.dart test/bounty_hunter_replay_test.dart test/validator_worker_test.dart` | No issues |
| Repository root | `python tools/combat/generate_projectile_profiles.py --check --dart C:/Users/Toonsa/flutter/bin/cache/dart-sdk/bin/dart.exe` | Generated projectile capsules current |
| Repository root | `node tools/admin/service/catalog.mjs --check-fixture` | Generated catalog current |
| Repository root | `git diff --check` | Passed |

Generators ran before freshness checks: projectile profile generator without
`--check`; Functions build followed by `node tools/admin/service/catalog.mjs
--write-fixture`; and `node functions/tool/refresh_navigation_routes.mjs` followed
by Functions production/test builds. Ranked windows are unchanged; seeds now
match compatibility `2026.11.8`. Navigation topology/algorithms did not change.

The Admin composition test initially failed because its fixed-position Waspfang
lookup no longer reached the item. Searching by item ID fixed selection. A
subsequent image-readiness assertion exposed its fixed 400ms disk/decode wait;
it now waits for actual loaded images with a finite 5s bound and keeps the same
assertion. The focused composition rerun and final full file (2 tests) passed. Its wide fixture screenshot
was visually inspected at `build/admin-proof/admin-wide.png`: labels, selection,
preview and existing artwork are legible; Willow illustration slots are empty.

Local relative Markdown targets were checked for all changed documentation and
the new roster/evidence; none were missing. Final whitespace check passed.

## Boundaries

Subsequent work completed the 34 dedicated equipment illustrations; see the
[item-art verification](willow-item-art-2026-11-08.md). The checks and empty
illustration observations above describe the earlier equipment-only milestone.

Automated checks prove roster parity (8/10/8/8 plus 8 shared), character gating,
starter ownership, 150-gold purchasing, catalog grants, proc payload isolation,
real critical-blast status effects, Backtrail's threshold crossing and 30-second
cooldown at 30/60/120 Hz, Supplies display, art-family coverage and replay parity.
They do not establish live balance or device acceptance.

Dedicated item illustrations, player balance sessions, native release builds,
new ranked navigation packs and live deployment were not run. Existing art
families are reused. Release tooling must prepare navigation packs for the chosen
candidate; current development fallback remains supported. Compatible client,
issuer and worker rollout, and any new gift-catalog activation, remain separate
release actions. No live gift delivery, board mutation or account reset occurred.
