# Campaign implementation checklist

Status: campaign platform and visual marker authoring implemented locally
November 11–12, 2026. The user's Reporting for Duty route is included in Build;
missions 2–4 remain drafts. Device and release acceptance remain open.
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

## M2 follow-up: visual marker authoring

Confirmed November 11: Campaign's Markers tab should offer Chunk Creator-style
tools for direct placement of enemies, traps, rescue encounters, gold coins,
restoration gems and blessing shrines, alongside start, exit and objectives.
New placements belong to a particular mission occurrence, so repeated uses of a
chunk can have different gameplay content without editing the shared source.
The implementation reuses Chunk inspectors, scene controls, actor previews and
Core pickup/interaction behavior. The user explicitly chose attaching blessing
fire to existing shrine/platform geometry, without placing a new base.

Planning commit: `4edfa4ce`. Implementation preserved the user's campaign source,
Core/UI/Functions generated catalogs and authored campaign terrain. Parallel hub
UI changes were also left untouched. No schema migration or production layout
edits were needed.

Affected owners: `tools/editor` owns commands, scene interaction and persistence;
`runner_content_pipeline` owns source decoding/composition; `runner_core` owns
placement, lifetime and mechanics; root `tool/campaign_generation.dart` owns
generated content. Rendering/captured assets and replay-worker consumers must
follow the same contract. Backend changes are needed only if digest/compatibility
or policy projections change; reward mechanics are outside this follow-up.

### Inspected constraints and intended behavior

- Before this follow-up, Campaign listed serialized values in a placement dialog.
  Its source stores gold points and objective references; enemies, traps and
  rescues come from chunk sources. Campaign disables procedural pickup spawning.
- The compiler and generator deduplicate chunks by source key. Occurrence-local
  content must survive compilation and generation instead of being collapsed
  back into one shared pattern or terrain record.
- Restoration gems reuse existing health/mana/stamina pickup types and tuning.
  Shrine fire reuses the existing top-contact, once-per-occurrence activation and
  nonstacking regeneration blessing; placing artwork alone is insufficient.
- Keep the assembled route visible while editing. Provide a labeled palette,
  Select/Place/Move tools, a placement preview, snapping, duplicate/delete, and
  a selected-object inspector. Use the shared Ctrl+drag pan, Ctrl+scroll zoom,
  cancellation and Undo/Redo behavior. Precise coordinates remain editable.
- Show existing chunk-owned gameplay as inherited content with an explicit
  shared-source edit action. Preserve it; do not silently remove it, duplicate it
  into mission data, or make an occurrence edit change every use of the chunk.
- Base terrain stays in Chunk Creator. Blessing fire attaches to an existing
  collidable flat top through shared Core support validation; it adds no geometry.

### V1: occurrence placement contract and compilation

- [x] Define typed mission placement records with stable placement IDs,
  occurrence-local coordinates and catalog references. Reuse Core enemy, trap,
  rescue, pickup and interaction definitions; do not introduce parallel mechanics.
  Start/exit stay singletons. Specify bounds, capacities, absent/null behavior,
  canonical ordering, and identity rules for move, duplicate and route reorder.
- [x] Specify how inherited chunk content and local placements compose, with
  disjoint runtime identities and no duplicate registration. Compile distinct
  occurrence content using the existing terrain/placement authority; preserve
  source provenance separately from any compiled occurrence key. Include shrine
  support references and binding in this contract and captured dependencies.
- [x] Bind required enemy/rescue objectives to stable placements, retaining
  existing source targets. Duplicate receives fresh IDs and remapped internal
  references; moving between occurrences preserves or rebinds references in one
  transaction. Referenced deletion must explicitly resolve dependencies.
- [x] Choose a compatible additive source change or an explicit versioned
  migration before changing strict schema 1. Preserve existing missions and user
  edits; never migrate implicitly during load. Update decoder, Core values,
  compiler, generator and their consumers together before calling this milestone
  complete. All gameplay inputs enter the content digest.
- [x] Prove two occurrences of the same chunk can compile different content,
  including a shrine in only one occurrence, with unchanged source chunk bytes.
  Check malformed catalogs, duplicate identities, broken references, and
  saveable incomplete drafts versus blocked Play/Build readiness.

### V2: gameplay and generated/captured Play parity

- [x] Instantiate local enemies, traps and complete rescue groups through the
  existing Core systems exactly once. Preserve placement validation, combat-free
  mission rules, guaranteed required targets, objective failure and death ordering.
- [x] Spawn authored coins and health/mana/stamina gems at their explicit positions
  while procedural spawning stays disabled. Keep current collection, restoration
  and gold accounting; consumed items remain consumed on return travel.
- [x] Make fire attachments placeable on existing collision, with fire appearance,
  activation surface and blessing binding. Reuse top-contact validation, offscreen
  persistence, nonstacking grants and restart reset. Include required assets in
  preview/captured Play; reject invalid bindings rather than granting on proximity.
- [x] Carry occurrence content through authored Play and generated production
  missions using the same compiler. Update snapshots/rendering only where needed;
  regenerate affected outputs and verify trusted worker replay/content-digest
  parity. Assess gameplay compatibility changes without deploying anything.

### V3: visual editor and persistence

- [x] Replace the raw marker list/dialog workflow with the palette, editable route
  canvas and contextual inspector. Offer enemies, traps, rescues, coins, three
  restoration gem types, shrine presets, start, exit and visit regions. Show
  sprites/icons, object extents, selected occurrence and actionable validation.
- [x] Reuse Chunk Creator catalogs, shared scene input/view transforms and
  rectangle gestures; extract only genuinely reusable behavior. Keep campaign
  commands in its domain and bounded presentation beside its route. Remove
  replaced UI paths rather than maintaining two competing placement workflows.
- [x] Support click-to-place, repeated placement, selection, drag-to-move,
  duplicate/delete, Escape cancellation and supported region/trigger resizing.
  Resolve the occurrence under the pointer, handle boundary crossings explicitly,
  and commit one semantic history entry per completed gesture.
- [x] Expose type-specific properties: enemy type/placement and required status;
  trap type/trigger; rescue participants/region and required status; gem resource;
  shrine preset; and start/exit/visit bounds. Incomplete rescue drafts remain
  editable and saveable but cannot Play/Build until valid.
- [x] Preserve revision checks, transactional Save, Undo after Save, Save/reopen,
  dependency drift, guarded Chunk Creator handoff, narrow layouts and view state.
  Save/Play must resolve valid inspector drafts and cancel or reject unfinished
  gestures consistently. Play uses a frozen capture and restores editing afterward.

### V4: acceptance and documentation

- [x] From Markers, create and adjust every requested object type without editing
  JSON or opening Chunk Creator for ordinary placement. Verify a repeated chunk
  can contain different objects in each occurrence and another mission is unchanged.
- [x] Automated coverage for create/move/duplicate/delete, cross-occurrence
  movement, route reorder/duplicate/remove, required-target edits, stale revision
  rejection, Undo/Redo, Save/reopen, source drift and narrow panels.
- [ ] Native-editor usability pass for pan/zoom, selection and gestures on the
  user's production route. Automated gesture/draft checks do not replace this pass.
- [ ] Play a finite fixture with real inputs across an actual route boundary and
  back, retaining continuous actor state: collect coins/gems, resolve enemy/rescue
  objectives, activate a trap and shrine, then verify nothing respawns or grants
  twice. Test invalid shrine contacts, independent shrine instances, restart and
  both playable characters. Follow the traversal workflow for composed geometry.
- [x] Verify generated missions against captured Play and trusted worker replay
  at 30/120 Hz, including occurrence-specific content. Retain existing compatibility
  checks and runner/Chunk Creator regressions for reused paths.
- [x] Update implemented campaign and world-interaction TDD/GDD, editor README
  and affected ownership instructions after delivery. Record exact commands,
  source, results and unrun manual/device checks here; keep production layouts
  and release acceptance under M4.

Validation starts with targeted pipeline `campaign_source_test.dart`, Core
`campaign/campaign_runtime_test.dart` and interaction tests, editor
`campaign_authoring_test.dart` plus gesture/Play tests, and the generator's
campaign-to-worker integration target. Add focused cases for the new contracts;
run analysis in each affected owner and generated freshness from the root.
Broaden checks only for shared impact or an unresolved concern. Use the
[validation routing](../../../.agent/README.md#validation) and
[traversal workflow](../../../.agent/workflows/test-level-traversal.md).
Historical evidence below does not validate this follow-up.

Planning validation (November 11): documentation-only diff review and
`git diff --check` passed; a local path/heading check passed all 78 relative links
in the four edited planning documents. No application tests or feature acceptance
checks were run for this planning change.

Local implementation evidence (November 11–12, 2026; current task worktree):

| Directory / check | Result and scope |
| --- | --- |
| `packages/runner_content_pipeline`: `campaign_placement_source_test.dart` using cached Dart test runner | 11 passed: strict additive source, distinct repeated occurrences, enemy identity, incomplete rescue readiness, trap/rescue composition, gold/gems and attached fires |
| Same runtime fixtures | Both characters, seed 42, 30/120 Hz, two repeated flat Training Field chunks; continuous travel 60→1100→80→1100 with a 20-second budget per leg. Pickups remain consumed, fires retain state, blessing does not stack, restart resets. Missing/moved/out-of-bounds support fails |
| `packages/runner_core`: `interactions/world_interaction_test.dart interactions/world_interaction_game_core_test.dart` | 25 passed, including actual prefab top contact, airborne/side/stale/enemy/dead negative controls, both characters, captured-Play parity and old manual bindings |
| `tools/editor`: `campaign_authoring_test.dart` | Existing chapter/reward/route/panel/Save/drift tests passed; the new coin/fire widget test passes place/drag, Escape cancellation, unfinished-gesture and invalid-field Save blocking, valid draft resolution, attach rejection, undo/redo, Save/reopen and untouched chunk bytes. The Windows image-I/O cleanup race was resolved by draining frames and real I/O after unmount |
| Same file: `--plain-name 'every palette brush'` | Passed all eight placement brushes, incomplete-to-complete rescue editing, cross-occurrence movement, duplicate/delete, undo/redo, stale-revision rejection, Save/reopen and another mission remaining unchanged. Its two-minute timeout covers repository I/O and repeated validation; simulation horizons are unchanged |
| `tools/editor`: `campaign_marker_edit_test.dart`, `chunk_marker_scene_gesture_test.dart`, `chunk_v2_marker_placement_projection_test.dart`, `chunk_trap_authoring_test.dart`, `chunk_encounter_authoring_test.dart` | 25 passed: objective remapping and occurrence duplication plus regressions for reused scene projections, gestures and inspectors |
| Root: `flutter test --no-pub test/tool/generate_chunk_runtime_data_test.dart --plain-name 'campaign generates' --reporter expanded` | Passed generated trusted registry and actual replay worker at 30/120 Hz with local coins/gem/fire and a local conditional enemy pattern |
| Root: generator `--dry-run` | Passed: 166 chunk files, 3 levels, 3 themes and 3 materials; authored and generated user files were not rewritten |
| Root/editor: targeted `dart analyze` on changed Core, pipeline, generator, Campaign UI, shared enemy form and new tests | No issues found |
| Root: `git diff --check` and relative Markdown link check | Passed; 101 local documentation links resolve |

These are local automated checks, not a native-editor manual pass or a production
chapter acceptance run. A combined combat/rescue/trap/fire playthrough through
production geometry and device performance remain under manual/M4 acceptance.

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

### Item authoring follow-up

Authorized November 11: create, duplicate and edit existing item categories in
the repository editor, with a single authored source and typed Core generation.
Worktree was clean at the start. No deployment or account mutations authorized.

- [x] Trace identity, presentation, equipment policies, exporter and save/build boundaries.
- [x] Capture original effective definitions, ordinals, starter state and backend output;
  initial migration matches SHA-256 `bde5d3a8f2954cb7dbe57bbd62808b5e4f90a3a7813ff027e8e3d95a9037d61a`.
- [x] Establish structured item source and typed generation without parallel handwritten catalogs.
- [x] Complete Items plugin/forms, source conflicts, history and rollback coverage.
- [x] Prove new item propagation through Core, presentation, backend and shared pickers.
- [x] Validate affected Core/game/editor/Admin/backend, including gift retry and campaign settlement.
- [x] Complete documentation, compatibility policy, freshness gates and full diff review.

Compatibility policy: existing IDs, ordinals, category, family/slot and two-handed
occupancy are immutable in ordinary authoring. Reject changes that can invalidate
saved loadouts; duplicate into a new identity. Ownership and retained gift readers
remain intact. Exceptional eligibility migrations require separate code and release
design; this implementation does not add account migrations.

Local item-authoring evidence (November 11, Flutter 3.47.1 / Dart 3.13.1):

| Directory / command | Result |
| --- | --- |
| Core: `dart --suppress-analytics test test/combat/willow_equipment_test.dart test/combat/bounty_hunter_test.dart test/combat/status_tuning_test.dart` | 299 passed |
| Root: `flutter test --no-pub test/tool/item_migration_test.dart` | Original 76 item definitions, ordinals, starter snapshot and complete backend bytes retain the digest above |
| Root: `flutter test --no-pub --no-test-assets test/tool/item_generation_test.dart test/tool/generate_backend_catalog_test.dart --reporter expanded` | 6 passed; isolated append/compile/recheck is deterministic; check failure writes nothing; actual shared picker selects each new category from Core and generated backend inputs |
| Root: item migration/generation plus `test/game/willow_muzzle_render_test.dart test/game/player_scale_render_test.dart` | 6 passed, including new projectile render/muzzle/character profile inheritance |
| Root: shared gear/localized catalogue and icon targets | 13 passed before final generator fixture extension; presentation inputs unchanged |
| Editor: item authoring, home-route switching, session/controller/recovery, Build service, entity pipeline/parser and campaign authoring targets | 87 passed; final Items-only rerun 9 passed, including inherited values versus explicit false and 520px layout |
| Root: `generate_chunk_runtime_data_test.dart` machine reporting, cancellation, input additions, missing outputs and writes | First 3 passed; 2 fixture expectations corrected for the mandatory item source and 10 added outputs, then both passed |
| Admin: `flutter test --no-pub --reporter expanded`; root `corepack pnpm admin:test:service` | 7 Flutter and 12 local service tests passed; catalogue fixture unchanged |
| Functions: `corepack pnpm --dir functions test` | 384/385 passed with local Firestore emulator, including retained-gift retry/hash, activation fixture and campaign once-only/concurrent settlement |
| Functions: `corepack pnpm --dir functions build`; Admin catalogue `--check-fixture` | Passed |
| Root: item/backend `--check`, content generator `--dry-run`, navigation revision `--check` | Passed; navigation revision remains `bd2274e0b71f13d538e131be959817d040eb11182da317b2db98903ed26a1e98` |
| Root/editor: focused analyzers, localization `check`, `corepack pnpm catalog:check`, `node tools/agents/check.mjs`, task diff and 124 relative links | Passed; all 76 English/French names also match the original HEAD resources |

The sole backend failure is pre-existing in HEAD: `practice_routes.test.ts`
expects the frozen route plan's compatibility `2026.11.10` to equal the current
`2026.11.11`. Both original files were inspected; no hash/fixture was blindly
updated. Generated item/backend bytes and retained activation hashes are unchanged.
Full content freshness passed before subsequent unrelated campaign source edits in
the shared worktree; those edits and their generation are outside this item commit.
Concurrent campaign UI/source work was preserved and excluded from staging.

Transient logs are under ignored `.tmp/item-*`. Fixture setup failures during the
new nested Flutter picker test were fixed and rerun; unchanged test assets were
reused after a concurrent Windows asset-copy collision. All claimed checks are
local automated checks, with no native manual pass, live accounts, deployment or
device acceptance claimed. See [item contract](../../tdd/item_authoring.md).

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
- [x] Obtain release authorization: on November 12 the owner requested current
  code deployed to dev backend and a matching Android build. This supersedes the
  implementation-only authorization above; staging/prod and data resets are excluded.
- [ ] Freeze the validated source and complete canonical preparation, reusing
  component and navigation evidence only when its inputs and artifact bytes match.
- [ ] Build and benchmark the worker image; build and inspect a matching dev APK.
- [ ] Inspect dev, pause issuance, review drain, deploy the coordinated candidate
  and verify readiness before resuming issuance. Record actual artifact identities.
  Source compatibility is 2026.11.11; no live compatibility/deployment is claimed yet.

November 12 content checkpoint: Reporting for Duty revision 26 includes sixteen
campaign-only Forest occurrences, supported start at (60, 224) and a final-chunk
exit at x=500. It remains combat-free with no additional required objectives.
Generated Core terrain/registry and UI/backend projections match canonical source
(`generate_chunk_runtime_data.dart --dry-run`). Focused Dart analysis, nine campaign
menu tests, Functions production/test builds and seven campaign progression tests
passed locally. The draft-issuance test now supplies an explicit unavailable
catalogue rather than assuming production missions are excluded. The existing
Core campaign/runtime and navigation matrix/control targets passed all 90 tests
(Forest/Field, seeds 7/42/2026, actual catalog capabilities and declared finite
horizons). These checks do not establish complete authored-route traversal or
signed-in device acceptance.

Release preparation checkpoint: candidate `de8d1464` stopped before cloud mutation
on the current production audit (GHSA-474x-hrwr-fgx4, low severity). Both workspace
and standalone Functions overrides now pin `fast-xml-parser` 5.12.0; only that
dependency family changed in the regenerated lockfile. The advisory's stated
minimum patched 5.11.3 was not published in the registry. Root pnpm production
audit and isolated production npm resolution/audit outside the workspace report
zero vulnerabilities. Functions build and all five production-inventory tests
passed. Freeze a replacement candidate; the failed preparation is not releasable.
Client navigation seeding verified all 3,750 graph hashes against the previously
inspected dev APK 7 manifest. The current producer must still validate exact keys.
No device is connected; dev APK 8 is the next locally allocated artifact code.

Candidate `662f533b` was superseded before expensive checks/cloud mutation when
inspection found ranked preparation still bound to 2026.11.10. The existing offline
route generator refreshed its six explicit November/December and ISO-week 46/47
seeds for 2026.11.11. Both Practice/production-seed contract tests and test build
passed. Runner levels, Practice seeds and navigation algorithm revision are
unchanged; exact-key graphs are reused and only missing ranked graphs are built.
The owner additionally authorized cancelling dev tickets found during the cutover.
Record any actual cancellations separately from terminal/settled history.

Candidate `390b8b30`: canonical backend checks passed all 385 emulator tests and
five inventory tests, plus the production build and fresh audit. Client production
analysis passed, but test analysis found four stale campaign mock contracts: one
missing `campaignMissionId` argument and three non-exhaustive mode switches. The
mock corrections and explicit unranked-board rejection checks passed targeted
analysis and all ten tests in `run_start_preparation_test.dart` and
`app_state_leaderboard_test.dart`. Preparation stopped and must resume from the
replacement frozen source; matching backend evidence remains reusable.
Read-only dev Inspect at 06:40 UTC found three issued 2026.11.10 tickets, 34
accepted runs and 34 settled grants, no settlement backlog and no invalid gold
or unauthorized selections. No cloud mutation or cancellation has happened yet.

Candidate `494b2bb9`: all client analyzers passed. The full client run found seven
failures: five proc integration assertions exposed weapon/spell-book `tryGet`
bypassing virtual `get`; the terrain boundary list omitted the documented campaign
terrain owners and shared interaction resolver; a stale-revision purchase fixture
selected Willow without canonical campaign clears. The lookup repair preserves
the previous injection contract and all original proc assertions. Focused checks:
11 proc/projectile tests, ten terrain tests and three ownership-command tests
passed. Catalog analysis, generated freshness and the unchanged navigation revision
check passed. Full-run completion and replacement-candidate preparation remain open.
Replay-validator analysis, 366 tests (one fixture-only skip) and the compiled AOT
protocol probe passed on `494b2bb9`. The catalog source repair changes its component
input hash, so replacement preparation must revalidate that component.

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

Next: native-editor usability and user-authored production layouts/M4 acceptance.
Keep content/device acceptance explicit;
archive this plan only once that remaining work is completed or replaced.
