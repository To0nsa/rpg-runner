# Willow Double Dash — 2026-11-08

Local source prepared on Windows from `4531dd82`, preserving the preceding
Willow and character-builder work. Gameplay compatibility is `2026.11.8.5`.
No deployment, remote ownership migration, account reset or device acceptance
is included.

## Delivered behavior

- Willow has 24 abilities. Double Dash replaces Roll and Slide in Core,
  selection, store/gift catalogs and the generated Admin fixture.
- Double Dash matches Éloïse's existing recast: eight ticks at 515.625 units/s
  per burst, 2 stamina per tap, a 30-tick follow-up window and one 120-tick
  cooldown from the first tap. These are authored 60 Hz values, scaled by Core.
- Direction can change between bursts; ground and air activation work. Shared
  expiry, interruption, resource checks and `+1` HUD behavior remain authoritative.
  No additional invulnerability is granted. Ordinary Dash remains the starter.
- Developer Practice replaces retired selections with Dash in all three saved
  builds. Double Dash can then be equipped and survives reconstruction. Online
  authorization rejects retired IDs even when ownership retains them; current
  skills still require ownership. The unreleased Willow roster has no remote
  migration, matching its existing content-removal policy.
- Client, issuer and worker compatibility agree; ranked route seeds and the
  Admin catalog/hash were refreshed through their offline producers.

## Local checks

Commands used Dart 3.13.1 from `C:/Users/Toonsa/flutter/bin/cache/dart-sdk/bin/dart.exe`.
Flutter commands used that executable with `C:/Users/Toonsa/flutter/bin/cache/flutter_tools.snapshot`.
Reviewed execution outside the sandbox permitted SDK cache access.

| Directory | Command/check | Result |
| --- | --- | --- |
| `packages/runner_core` | `dart test test/combat/mobility_recast_test.dart test/combat/bounty_hunter_test.dart --reporter expanded` | 255 passed, including 60/120 Hz recasts and retired-loadout rejection |
| `packages/runner_core` | `dart test test/anim/willow_dash_visual_test.dart --reporter expanded` (in the initial combined run) | All 19 existing animation cases passed |
| Root | `flutter test --no-pub test/core/dash_range_test.dart --reporter expanded` | Final 8 passed: both characters, ground/air travel, gear scaling and HUD lifecycle |
| Root | `flutter test --no-pub test/ui/text/ability_damage_tooltip_test.dart test/ui/pages/select_character/ability_picker_presenter_test.dart test/ui/state/developer_practice_test.dart test/ui/state/firebase_run_session_api_test.dart test/ui/icons/ability_skill_icon_test.dart --reporter expanded` (initially combined with range tests) | All 45 UI/state/API/icon cases passed |
| Root | `dart analyze` with changed Core, presentation, UI and test paths | No issues |
| `services/replay_validator` | `dart test test/double_dash_replay_test.dart test/validator_worker_test.dart --reporter expanded`; `dart analyze` | 103 passed; no analysis issues |
| Root / `functions` | `corepack pnpm --dir functions build`; `build:test`; compiled Node tests for `ownership/bounty_hunter`, `ownership/double_dash`, `runs/compatibility`, `runs/practice_routes`, `abuse/app_check_diagnostics` | Builds and 22 pure local tests passed; no emulator/cloud writes |
| `tools/admin` | `flutter test --no-pub test/admin_page_test.dart --reporter expanded` | 2 passed, including every backend catalog entry and its artwork |
| Root | `node tools/admin/service/catalog.mjs --check-fixture`; `dart run tool/sync_assets.dart --check`; `dart run packages/runner_core/tool/update_navigation_revision.dart --check` | All current; navigation fingerprint unchanged |

Compiled with `dart --suppress-analytics compile exe bin/server.dart -o
../../.tmp/willow_double_dash_validator.exe`, then ran `benchmark --ticks=36000 --strict`.
All deterministic/progress/throughput gates passed: Forest 0.733s and Field
0.595s for 36,000 ticks each. This generated-terrain fixture has no combat
objectives and does not establish device or container performance.

Initial tests exposed an expected debug assertion when attempting to execute
an unknown ability; the final regression correctly checks loadout validation.
Movement fixtures now use complete starter gear: both offhands impose -5%
speed, so expected distances include that modifier. The original quantization
tolerance is unchanged. The compatibility future-candidate test was advanced
to `.6`, and its file-relative reads were run from `functions` as intended.

## Artwork

The built-in imagegen tool created the new
[64×64 transparent icon](../../assets/images/icons/skills-icons/willow/double_dash.png),
using Willow Dash and Éloïse Double Dash as references. The
[exact prompt, paths and SHA-256 hashes](willow-double-dash-icon-2026-11-08.json)
record provenance. Nearest-neighbor export preserves generated alpha. The
source and final icon were visually inspected, and bundled icon/consumer tests
passed. Retired source artwork remains on disk but is no longer mapped to skills.
