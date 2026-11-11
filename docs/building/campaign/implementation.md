# Campaign implementation checklist

Status: campaign platform implemented locally November 11, 2026. Implementation, source review and local validation are complete. Production layouts remain the user's work.
This is the sole checklist; [technical contracts](../../tdd/campaign_runtime.md)
and [game behavior](../../gdd/campaign.md) describe the delivered systems.

## Scope and decisions

The user authorized full implementation, editable drafts for missions 2–4 and
Willow locked for all accounts with no legacy exception. Initial work began from
clean planning commits c45d796f/c95dff1d/1ee69a66; finite primitives were committed
as 5abb3017. No unrelated changes were found. No deployment, reset or cloud
mutation is authorized by this implementation task.

The chapter follows Le feu de joie with the user's cultist premise. Reporting
for Duty remains encounter-free and requires only basic jumping. Source defaults
are Reporting for Duty, Signs in the Grove, The Supply Trail and Holding the
Outpost. First-clear XP is 40/48/60/76 (224 total); gold is collected per accepted
attempt. Double Jump is Éloïse's existing skill; Willow unlocks on four clears.

## M0–M1: contracts and finite simulation

- [x] Trace forward-camera assumptions and mode/outcome consumers; retain
  runner behavior through separate finite-route and camera policies.
- [x] Settle schema-1 chapter/mission/occurrence identity, usage, source ownership,
  exact seams, guaranteed targets, content digest and reward policy 1.
- [x] Keep finite terrain and source actors resident, instantiate each occurrence
  once, retain state offscreen and allow continuous travel both directions.
- [x] Add bounds, objective/exit success, failure/death precedence, finite camera,
  local authored Play and objective HUD; exclude survival-time score.
- [x] Carry campaign binding through ticket, recorder, replay, worker and result;
  production Core resolves compiled content, authored Play uses captured input.
- [x] Demonstrate outward/return traversal across three occurrences for both
  characters with actual inputs, combat and consumed pickups. Prove generated
  production-worker parity at 30/120 Hz with two repeated source occurrences.
- [x] Run full Core package and replay-worker suites and the strict native replay
  benchmark; record local evidence separately from deployment/device acceptance.
- [ ] Measure startup/resident memory/frame cost on the target device after real
  routes exist. The 16-occurrence cap is an admission guard, not a measured budget.

## M2: mission authoring

- [x] Campaign library, exact route/occurrence ordering, duplicate/remove,
  continuous preview, typed markers, bilingual settings and inclusion controls.
- [x] Mission ability and chapter character reward selectors, including None,
  Cancel, stale-form rejection and Save/reopen/Undo coverage.
- [x] Expandable chapter bars, chapter creation/settings and additional mission
  drafts, with stable identity, selection and creation history coverage.
- [x] Align Campaign with Level Creator's responsive library/preview/settings
  layout; share preview sizing, chunk cards and visual rendering. Preserve tab,
  search and occurrence selection across panels, resizing and guarded return.
- [x] Semantic edits, revision/history, transactional Save, Undo after Save,
  dependency drift, shared-source navigation and captured F5 Play.
- [x] Bidirectional independent chunk copies preserve supported geometry,
  encounters and metadata. Campaign copies remain outside runner pools;
  runner copies start inactive. No encounter-removal preset/filter.
- [x] Validate references, source ownership, supported start, actual seams,
  required targets and encounter-free admission; reject referenced chunk deletion,
  rekeying or owner change until the mission is rebound.
- [x] Generate Core/UI/Functions catalogs atomically with freshness checks.
- [x] Document the copy/edit/assemble/Play/Build workflow in the editor README.
- [ ] Manual native-editor usability pass with production geometry, including a
  repaired reverse-traversal seam. Automated editor workflow checks are recorded below.

## M3: menus and verified progression

- [x] Three fitted hub cards, Val map crop, clickable regional map, independent
  chapter list, assignments/rewards/bests, selected build, retry/next and recovery.
- [x] English/French compact and wide menu checks with text scaling; clear locked
  Willow requirement and canonical availability across selection/Training Field.
- [x] Authenticated admission, prerequisite/build/character checks, exact binding,
  positive ranked-mode gates and no campaign boards/ghosts.
- [x] Transactional first clears, attempts/versioned bests, once-only XP/skill
  rewards, concurrent settlement, receipts, deletion fences and durable submissions.
- [x] Explicit Double Jump equip action; preserve builds and normalize locked
  Willow selection. Developer mode remains local with no account progression.
- [x] Exclude campaign score-to-XP previews and runner achievements; retain verified
  gold, player counters and discoveries. Keep campaign out of runner preferences.
- [x] Update implemented TDD/GDD, public embedding API, setup and owner guidance.

## M4: user-authored content and release acceptance

- [x] Supply four localized editable mission drafts and reward defaults.
- [ ] User assembles production layouts and objectives, beginning with independent
  Forest rocky_grove easy/normal and trainingcamp copies for Reporting for Duty.
- [ ] Validate all four actual routes, basic-jump arrival, subsequent Double Jump,
  post-unlock Willow, required encounters and continuous return traversal.
- [ ] Complete device performance/input/accessibility and signed-in end-to-end
  acceptance on a deliberately prepared compatible app/backend/worker release.
- [ ] Obtain release authorization and follow coordinated deployment separately.
  Source compatibility is 2026.11.11; no live compatibility/deployment is claimed.

## Local evidence (November 11)

All checks below use this worktree, not deployed services. Transient logs are in
ignored `.tmp/campaign_*`. Pure Dart package tests used the cached test runner
with the owning package config to avoid pub.dev advisory lookups; worker/editor
retain their independent package configs. Flutter checks use `--no-pub`.

| Directory / command | Result and scope |
| --- | --- |
| `packages/runner_core`: cached test runner `test --reporter expanded` | 2,655 passed, including navigation matrix and harness controls |
| Root: `flutter test test/core` | 525 passed |
| `packages/run_protocol`: cached runner `test` | 136 passed; old runner digest fixtures unchanged |
| Worker: AOT `tool/aot_protocol_probe.dart` | Compiled and ran successfully with campaign malformed binding/board controls |
| `packages/runner_content_pipeline`: `campaign_source_test.dart training_field_source_test.dart` | 8 passed |
| `tools/editor`: `flutter test test/campaign_authoring_test.dart` | 4 passed: Save/Undo/drift/captured Play, bidirectional copy, reference deletion, workspace controls |
| `tools/editor`: reward-controls follow-up `flutter test --no-pub test/campaign_authoring_test.dart --reporter expanded` | 7 passed, including reward selection/clearing/Cancel, Save/reopen/Undo/Redo and unsupported/stale edit rejection; local automated checks, no native manual pass |
| `tools/editor`: reward-controls `dart analyze lib/src/app/pages/campaign lib/src/campaign test/campaign_authoring_test.dart` | No issues; formatting and task diff checks passed. Sandboxed checks stalled and were stopped; successful checks used normal SDK/cache access |
| `tools/editor`: chapter-authoring follow-up, same focused analyzer and `flutter test --no-pub test/campaign_authoring_test.dart --reporter expanded` | No analysis issues; 10 tests passed. Covers expandable sections, creation/settings, unique draft IDs, mission append limits, Save/reopen, selection fallback and saved-identity history boundaries. UI test interactions wait for scrolling/layout; no native manual pass claimed |
| `tools/editor`: layout follow-up, targeted `dart analyze` on Campaign, shared chunk card, changed Level files, home routes and Campaign tests | No issues; view state remains outside source/history |
| `tools/editor`: `flutter test --no-pub test/campaign_authoring_test.dart test/home_route_plugin_switch_test.dart --reporter expanded` | 30 passed; final Campaign-only rerun 11 passed after focus/ticker and handoff checks. Covers responsive panels, retained preview/search/selection, return context, marker dialogs, route edits and chapter/reward regressions |
| `tools/editor`: `test/level_creator_page_test.dart` in the initial combined layout run | All 32 Level tests passed. Initial Campaign widget waits timed out on continuous terrain animation; bounded UI-frame advancement replaced those waits. A newly covered narrow marker-dropdown overflow was fixed and Campaign reruns passed |
| `packages/tool_ui`: `dart analyze packages/tool_ui` from root; `flutter test --no-pub --reporter expanded` from package | No issues; 12 passed, including short-window/larger-text preview layout and mounted panel state |
| `tools/admin`: `flutter test --no-pub test/admin_page_test.dart --reporter expanded` | 2 passed against local fixture services; no cloud sends. Layout checks are automated, with no native manual pass claimed |
| `tools/editor`: chunk-v2, Play preparation and home-plugin-switch targets | 47 passed |
| `services/replay_validator`: cached runner `test` | 367 passed before the added campaign integration cases; final focused rejection cases 2 passed |
| Root: generator campaign-to-worker target | Passed generated trusted registry, continuous return and exact outcome/tick/gold at 30 and 120 Hz |
| Root: full `generate_chunk_runtime_data_test.dart` | 28/29 initially passed; expected missing-output count updated for campaign registry and focused retry passed |
| Worker: compile `bin/server.dart`, then `benchmark --ticks=36000 --strict` | Passed both levels and determinism/progress gates; local native executable, not a Cloud/container/device measurement |
| `functions`: full emulator suite | Initial 371/375 passed; four failures were expected-shape fixture changes, corrected with actual receipt regeneration and campaign counters |
| `functions`: focused emulator projection/session/compatibility/retirement/campaign suites | 78 passed after corrections, including concurrent first-clear settlement and replayed delivery |
| Root: campaign menu widgets | 6 passed: compact locked Willow plus 568×320/1280×720 campaign menus, en/fr, text scale 1.2 |
| Root: submission/API client targets | 49 passed; two other targets initially had a nullable-result compile error, fixed |
| Root: loadout/availability and game-over score-feed retry | 36 passed; final loadout/start target 15 passed after regional availability separation |
| Root: campaign reward-preview target | Passed: local gold without score-derived XP or a clear |
| Root: existing hub/character and bootstrap/adapter targets | 11 and 13 passed respectively |
| Root: generator `--dry-run`; asset manifest `--check` | Passed after final generation |
| Root: navigation revision `--check` | Unchanged `bd2274e0b71f13d538e131be959817d040eb11182da317b2db98903ed26a1e98` |
| Root: `node tools/agents/check.mjs`; diff/link checks | Passed; 216 relative documentation links checked |
| Focused App/Core/pipeline/editor and worker/protocol analyzers | No errors or warnings; final changed sources have no diagnostics |
| `functions`: `corepack pnpm build` | Production TypeScript build passed |

Initial campaign fixture failures were malformed region JSON and mismatched
client/ticket equipment, both corrected without relaxing parity assertions.
Editor deletion correctly raised the guarded Save exception; its test now checks
that outcome and source retention. No real chapter traversal, native editor
manual pass, phone performance or live authenticated campaign flow is claimed.

Next: user-authored production layouts, then the explicit M4 acceptance above. Keep content/device acceptance
explicit; archive this plan only once that remaining work is completed or replaced.
