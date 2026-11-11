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
- [x] Bidirectional independent chunk mode copies accept a custom name and keep
  geometry, scenery and water while omitting enemy markers, rescue encounters,
  boss arenas and traps. Campaign copies remain outside runner pools; runner
  copies start inactive. Ordinary Duplicate retains all content.
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

### Chapter completion rewards follow-up

Authorized November 11: editable chapter XP, gold and existing catalog unlocks.
Starting worktree is clean. Rewards grant once per stable chapter ID after all
missions clear, in the existing verified settlement transaction; repeated or
concurrent completions cannot pay twice. Existing Val rewards remain unchanged
until authored: additional chapter XP/gold default to zero and items to empty.
Items reuse Core identities, `game_presentation` names/icons and Admin catalog
presentation; skills retain explicit recipients and duplicate ownership is a no-op.
No live deployment or account mutation is part of this work.

- [x] Share catalog identity validation and the Admin/editor item picker without
  introducing a second item list or artwork mapping.
- [x] Extend chapter source, editor reward dialog, stale checks, Save/Undo and
  generated client/backend projections with bounded XP/gold and up to eight items.
- [x] Settle chapter completion receipts, gold, XP and ownership atomically with
  retry/concurrency coverage; preserve collected run gold and mission rewards.
- [x] Display authored chapter rewards in English/French using shared item art
  and labels, and preserve receipts through client state round trips.
- [x] Regenerate artifacts; validate all affected owners and update contracts,
  authoring guide and local evidence.

### Core catalogue generation follow-up

Authorized November 11: generate backend item/skill identities, slots and equipment
eligibility from Core, preserving catalogue bytes, activation hashes, starter
ownership and retained gift retries. Economy and account authorization stay in
Functions. Existing campaign/editor changes in the worktree are unrelated and
must remain untouched. No deployment or account mutation is authorized.

- [x] Export validated Core catalogues and equivalent starter semantics through
  deterministic repository tooling with read-only freshness checks.
- [x] Replace backend identity/eligibility duplication across store, loadouts,
  rewards and defaults; preserve account-wide gear rewards and retired recipients.
- [x] Integrate generation checks with build/CI and verify stale-output rejection,
  exact catalogue/hash/default parity, backend transactions and tool/game consumers.
- [x] Update implemented contracts/tooling docs, review the full diff and commit
  only this independently validated change.

Local evidence for this follow-up (November 11, source `a89abc68` plus this task's
diff; unrelated map/editor work is excluded from the catalogue change):

- Root: `flutter test --no-pub test/tool/generate_backend_catalog_test.dart
  --reporter expanded`: 3 passed. Complete Core identity/slot/equipment parity,
  deterministic repeated generation, isolated Core-change freshness failure
  without writes, duplicate projectile/ability rejection and unsupported ability
  definition rejection all passed. Focused `dart analyze` reports no issues.
- Root: `corepack pnpm functions:build` and
  `corepack pnpm --dir functions build:test` passed. The root build now checks
  catalogue freshness before TypeScript compilation; direct package builds stay
  Node-only. Initial sandbox output-write failures were resolved by running the
  same local build with the required filesystem access.
- Root: `corepack pnpm --dir functions exec firebase emulators:exec --config
  ../firebase.test.json --project demo-rpg-runner-functions-tests --only firestore`
  running `node --test` over `lib_test/test/ownership/*.test.js`,
  `inbox/*.test.js`, `campaign/*.test.js` and `runs/run_projection.test.js`:
  203 passed. Includes invalid IDs/slots/recipients, retained `eloiseWip`, removed
  Willow skills, revisions, idempotency, gift retries and concurrent once-only
  chapter settlement. All Firestore state was local demo-emulator state.
- Root: `corepack pnpm admin:test:service`: 12 passed;
  `node tools/admin/service/catalog.mjs --check-fixture` passed unchanged.
  `tools/admin`: `flutter test --no-pub test/admin_page_test.dart --reporter
  expanded`: 2 passed, covering all catalogue artwork and the shared picker.
- `tools/editor`: `flutter test --no-pub test/campaign_authoring_test.dart
  --reporter expanded`: 13 passed, including invalid/stale rewards, recipients,
  Save/reopen and Undo. Root `flutter test --no-pub --reporter expanded` over
  `test/core/meta/meta_service_test.dart`, `test/core/loadout/loadout_validator_test.dart`,
  `test/ui/state/town_catalogue_contract_test.dart`, `test/ui/pages/campaign_page_test.dart`,
  `test/ui/state/app_state_inbox_test.dart`, `test/ui/icons/ui_icon_coords_test.dart`
  and `test/ui/icons/ability_skill_icon_test.dart`: 54 passed.
- Root: `tools/release/test_release.ps1`, `test_release_integration.ps1` and
  `test_release_cache.ps1` under both Windows PowerShell and PowerShell 7:
  62/121/59 checks passed per shell. Cloud boundaries were mocked. Tests verify
  generated bytes invalidate cached freshness/client checks and the recipe runs
  the catalogue checker. Hosted CI itself was not run locally.
- Root: backend `--check`, chunk generator `--dry-run`, navigation revision
  `--check`, `node tools/agents/check.mjs`, diff checks and 58 local documentation
  links passed. Navigation revision remains unchanged. Complete fresh-account
  canonical bytes and all 121 ordered gift entries match the pre-change capture;
  activation hash remains
  `f4c42f855db359cbd3c4a461e0ae00e72136dee0309db31bcfcbc0b79d83e409`.
  Existing catalogue/receipt fixtures were not rewritten.

No deployment, live configuration, account mutation or native-device acceptance
was performed. Prices, reward amounts, purchase/availability rules, wire category
mapping and historical compatibility handling remain intentional backend policy;
new categories still require explicit support. Shared names/icons/picker are unchanged.

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

Chapter reward follow-up (local checks; no deployment or native manual pass):

- Pipeline: `dart test test/campaign_source_test.dart --reporter expanded`,
  5 passed, including strict bounds, catalogue identities/recipients and round-trip.
- Editor: `flutter test --no-pub test/campaign_authoring_test.dart --reporter expanded`,
  11 passed after correcting immutable command-map conversion. Covers numeric
  validation, item selection, cancellation, stale edits, Save/reopen and Undo/Redo.
- Admin: `flutter test --no-pub test/admin_page_test.dart --reporter expanded`,
  2 passed; complete catalogue identity parity and artwork, shared picker, mocked
  compose/preview/send. `node tools/admin/service/catalog.mjs --check-fixture` passed.
- Functions: `corepack pnpm --dir functions build` and `build:test` passed;
  `node --test functions/lib_test/test/campaign/progression.test.js`, 7 passed.
  The first local Firestore projection/gift run passed 55/56; the existing
  receipt fixture exposed an unnecessary empty `chapters` field in new accounts.
  The initializer retains its old shape; receipts add the optional map on use.
  A subsequent filtered invocation failed at shell parsing, before tests ran.
  The final local Firestore `run_projection.test.js` rerun passed all 50 tests,
  including the receipt fixture, duplicate delivery and simultaneous chapter
  completion with XP, gold, items and explicit skill recipients. The six Admin
  gift emulator tests passed in the initial combined run.
- Root: campaign menu/icon/inbox targets, 16 passed; added receipt and localized
  reward-display tests subsequently brought Campaign-only coverage to 9 passed.
- Root: generated campaign integration target in `generate_chunk_runtime_data_test.dart`
  passed nonzero XP/gold/item projection parity and the existing real-worker
  replay at 30/120 Hz. Generator `--dry-run` passed.
- Focused game/shared/editor analysis, formatting, full task diff and 24
  relative documentation link checks passed.
- Root: `dart run tool/localization.dart check` passed. The generated bilingual
  campaign catalogue joins the existing generated-source exclusions; exact
  English tool-control exemptions follow the Admin/editor localization boundary.


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
