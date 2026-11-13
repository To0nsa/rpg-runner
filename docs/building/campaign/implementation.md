# Campaign implementation checklist

Status: campaign platform and visual marker authoring implemented locally
November 11–12, 2026. The user's Reporting for Duty route is included in Build;
missions 2–4 remain drafts. Device and release acceptance remain open.
This is the sole checklist; [technical contracts](../../tdd/campaign_runtime.md)
and [game behavior](../../gdd/campaign.md) describe the delivered systems.

## Scope and decisions

### Ordinary enemy activation (November 13)

Authorized scope: ordinary Campaign enemy markers wait at their resolved homes,
activate on approach or positive damage, and optionally return when the player
retreats. A per-marker editor switch chooses return (default) or persistent pursuit.
Rescue participants and bosses retain their existing lifecycles. Preserve the
existing uncommitted campaign, tutorial, Journal, UI and generated-content work.

- [x] Add lifecycle state, deterministic activation/damage gates and terrain-based
      return motion, preserving actor identity, damage and death.
- [x] Carry the return/follow switch through strict source, editor history,
      captured Play and generated runtime catalogs.
- [x] Verify waiting, both approach directions, damage wake, return/follow,
      ground/flying movement, lifecycle cleanup and unchanged Runner/rescue paths.
- [x] Validate generated freshness, focused editor/pipeline/Core/replay checks,
      traversal controls and update implemented gameplay/technical documentation.

Implemented locally; [validation and inherited failures](../../verification/campaign-enemy-activation-2026-11-13.md)
record 525 Core integration passes, 86 traversal passes, 48 validator passes,
the source/editor/generated-policy checks and two unchanged pre-existing combat
test failures. The Windows editor was subsequently rebuilt at the user's request;
the linked evidence records the successful build. No release is implied.

### Campaign Journal (November 13)

Authorized scope: author an English/French campaign opening, chapter introductions,
and mission-completion updates in Campaign; preview the accumulated Journal after
any selected mission; show it in Library from confirmed mission clears.
Preserve the existing working tree, stable mission IDs and settlement authority.

- [x] Add strict optional bilingual Journal content to source and generated metadata.
- [x] Add guarded editor forms and a read-only accumulated Journal preview.
- [x] Render confirmed story progress in Library; replays cannot duplicate entries.
- [x] Author the post–Le feu de joie opening and conservative Val mission updates.
- [x] Preserve the complete initial Val Outpost location description before the
      investigation setup and mission updates in both languages.
- [x] Order the authored entries as Val Outpost, After Le feu de joie, then
      mission outcomes in the preview and Library.
- [x] Validate source/export/history, generated parity, editor forms and Library
      progress/locale/account/compact-layout behavior; update implemented docs.

The opening introduces Val Outpost. After Le feu de joie follows it: the tabletop
survivors are in Théodonis, Éloïse is called to Val, and the new cultists appear
different from the undead goddess’s followers. Their timing is suspicious;
a connection remains unproven.
Only Reporting for Duty is currently included; later mission entries stay hidden.

Focused tests, source comparisons and build evidence are recorded in
[Journal verification](../../verification/campaign-journal-2026-11-13.md).
All 43 focused tests, root/editor analysis, localization enforcement, generated
freshness and backend compilation passed. The Windows release editor was rebuilt.

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
- [x] Settle schema-1 chapter/mission/mission chunk identity, usage, source ownership,
  exact seams, guaranteed targets, content digest and reward policy 1.
- [x] Keep finite terrain and source actors resident, instantiate each mission chunk
  once, retain state offscreen and allow continuous travel both directions.
- [x] Add bounds, objective/exit success, failure/death precedence, finite camera,
  local authored Play and objective HUD; exclude survival-time score.
- [x] Carry campaign binding through ticket, recorder, replay, worker and result;
  production Core resolves compiled content, authored Play uses captured input.
- [x] Demonstrate outward/return traversal across three mission chunks for both
  characters with actual inputs, combat and consumed pickups. Prove generated
  production-worker parity at 30/120 Hz with two repeated source mission chunks.
- [x] Run full Core package and replay-worker suites and the strict native replay
  benchmark; record local evidence separately from deployment/device acceptance.
- [ ] Measure startup/resident memory/frame cost on the target device after real
  routes exist. The 16-mission chunk cap is an admission guard, not a measured budget.

## M2: mission authoring

- [x] Add one campaign's bilingual name and native map-file selection, image
  dimensions/preview, Undo/Save and generated game metadata. Keep multi-campaign
  creation/selection outside this change; organize supplied map files under
  `assets/images/maps/` with portable names.
- [x] Campaign library, exact route/mission chunk ordering, duplicate/remove,
  continuous preview, typed markers, bilingual settings and inclusion controls.
- [x] Mission ability and chapter character reward selectors, including None,
  Cancel, stale-form rejection and Save/reopen/Undo coverage.
- [x] Expandable chapter bars, chapter creation/settings and additional mission
  drafts, with stable identity, selection and creation history coverage.
- [x] Align Campaign with Level Creator's responsive library/preview/settings
  layout; share preview sizing, chunk cards and visual rendering. Preserve tab,
  search and mission chunk selection across panels, resizing and guarded return.
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
New placements belong to a particular mission chunk, so repeated uses of a
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
- The compiler and generator deduplicate chunks by source key. Mission chunk-local
  content must survive compilation and generation instead of being collapsed
  back into one shared pattern or terrain record.
- Restoration gems reuse existing health/mana/stamina pickup types and tuning.
  Shrine fire reuses the existing top-contact, once-per-mission chunk activation and
  nonstacking regeneration blessing; placing artwork alone is insufficient.
- Keep the assembled route visible while editing. Provide a labeled palette,
  Select/Place/Move tools, a placement preview, snapping, duplicate/delete, and
  a selected-object inspector. Use the shared Ctrl+drag pan, Ctrl+scroll zoom,
  cancellation and Undo/Redo behavior. Precise coordinates remain editable.
- Show existing chunk-owned gameplay as inherited content with an explicit
  shared-source edit action. Preserve it; do not silently remove it, duplicate it
  into mission data, or make a mission chunk edit change every use of the chunk.
- Base terrain stays in Chunk Creator. Blessing fire attaches to an existing
  collidable flat top through shared Core support validation; it adds no geometry.

### V1: mission chunk placement contract and compilation

- [x] Define typed mission placement records with stable placement IDs,
  mission chunk-local coordinates and catalog references. Reuse Core enemy, trap,
  rescue, pickup and interaction definitions; do not introduce parallel mechanics.
  Start/exit stay singletons. Specify bounds, capacities, absent/null behavior,
  canonical ordering, and identity rules for move, duplicate and route reorder.
- [x] Specify how inherited chunk content and local placements compose, with
  disjoint runtime identities and no duplicate registration. Compile distinct
  mission chunk content using the existing terrain/placement authority; preserve
  source provenance separately from any compiled mission chunk key. Include shrine
  support references and binding in this contract and captured dependencies.
- [x] Bind required enemy/rescue objectives to stable placements, retaining
  existing source targets. Duplicate receives fresh IDs and remapped internal
  references; moving between mission chunks preserves or rebinds references in one
  transaction. Referenced deletion must explicitly resolve dependencies.
- [x] Choose a compatible additive source change or an explicit versioned
  migration before changing strict schema 1. Preserve existing missions and user
  edits; never migrate implicitly during load. Update decoder, Core values,
  compiler, generator and their consumers together before calling this milestone
  complete. All gameplay inputs enter the content digest.
- [x] Prove two mission chunks of the same chunk can compile different content,
  including a shrine in only one mission chunk, with unchanged source chunk bytes.
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
- [x] Carry mission chunk content through authored Play and generated production
  missions using the same compiler. Update snapshots/rendering only where needed;
  regenerate affected outputs and verify trusted worker replay/content-digest
  parity. Assess gameplay compatibility changes without deploying anything.

### V3: visual editor and persistence

- [x] Replace the raw marker list/dialog workflow with the palette, editable route
  canvas and contextual inspector. Offer enemies, traps, rescues, coins, three
  restoration gem types, shrine presets, start, exit and visit regions. Show
  sprites/icons, object extents, selected mission chunk and actionable validation.
- [x] Reuse Chunk Creator catalogs, shared scene input/view transforms and
  rectangle gestures; extract only genuinely reusable behavior. Keep campaign
  commands in its domain and bounded presentation beside its route. Remove
  replaced UI paths rather than maintaining two competing placement workflows.
- [x] Support click-to-place, repeated placement, selection, drag-to-move,
  duplicate/delete, Escape cancellation and supported region/trigger resizing.
  Resolve the mission chunk under the pointer, handle boundary crossings explicitly,
  and commit one semantic history entry per completed gesture.
- [x] Expose type-specific properties: enemy type/placement and required status;
  trap type/trigger; rescue participants/region and required status; gem resource;
  shrine preset; and start/exit/visit bounds. Incomplete rescue drafts remain
  editable and saveable but cannot Play/Build until valid.
- [x] Preserve revision checks, transactional Save, Undo after Save, Save/reopen,
  dependency drift, guarded Chunk Creator handoff, narrow layouts and view state.
  Save/Play must resolve valid inspector drafts and cancel or reject unfinished
  gestures consistently. Play uses a frozen capture and restores editing afterward.

### V3b: Chunk Creator workspace reuse

Requested November 12, 2026: give Markers the main canvas, move its library and
properties into one sidebar, share the scene tools, and include Visual preview
and Actor terrain. Campaign commands and mission chunk ownership remain the source
boundary. Existing ghost-test and plan changes were present at task start and
were committed independently during this work; they are not part of this slice.

- [x] Expand the Markers canvas; keep Contents/Route shelves and the overview
  mounted across tabs. Reuse section cards, placement controls, actor selector,
  zoom input, Core terrain projection and its painter.
- [x] Gate editing in Visual preview while retaining pan/zoom. Preserve tool,
  selection, grid and actor preferences; keep Show grid independent from snapping.
  Invalid properties and active gestures block entry into preview.
- [x] Verify the Campaign interaction/persistence tests and focused Chunk Creator
  regressions, including wide/narrow layouts and retained drafts.
- [x] Inspect actual campaign artwork in rendered wide/narrow workspaces and
  record the final check results below. Native production-route interaction and
  gameplay acceptance remain the separate V4 gates.

Local validation on November 12, 2026, against this source change over
`4a9df290`, from `tools/editor`:

| Command/check | Result |
| --- | --- |
| `dart analyze lib/src/app/pages/campaign lib/src/app/pages/shared/editor_actor_terrain_controls.dart lib/src/app/pages/shared/editor_placement_tools.dart lib/src/app/pages/chunkCreator/v2/chunk_authoring_workspace.dart test/campaign_authoring_test.dart` | No issues |
| `dart analyze lib/src/app/pages/campaign/campaign_workspace.dart lib/src/app/pages/campaign/campaign_marker_editing.dart test/campaign_authoring_test.dart test/chunk_authoring_workspace_test.dart` | No issues after the final layout and fixture changes |
| `flutter test test/campaign_authoring_test.dart test/campaign_marker_edit_test.dart --reporter expanded` | 19 passed |
| `flutter test test/campaign_authoring_test.dart --name 'marker scene shares tools\|route preview fills\|campaign preserves view context' --reporter expanded` | 3 passed after fixing the narrow canvas clipping; verifies the canvas bottom is within the 800x700 window |
| `flutter test test/chunk_authoring_workspace_test.dart --name 'visual enemy library\|direct marker\|direct prefab move\|chunk scene shows its tile grid\|wide chunk workspace\|chunk creation scene and sidebar remain usable' --reporter expanded` | 6 passed initially; one stale sprite fixture failed because it loaded `derf.png` rather than the current catalog source. The fixture now derives paths from the catalog and the failing test passed on its focused rerun |
| `flutter test .dart_tool/campaign_ux_probe_test.dart --reporter expanded` | 1 passed; local render probe loaded real campaign sources/art plus Windows fonts, wrote ignored PNGs and asserted no document mutation. Inspected 1920x1080 authoring/actor-terrain/visual modes and 800x700 workspace/sidebar. Probe cleanup was corrected before the final pass |
| Root `git diff --check` | Passed |

The SDK executables required access to their installed cache/telemetry directory.
Context7 was unavailable; Flutter's official Offstage/IndexedStack documentation
was used for mounted-state, hidden-focus and animation behavior. No native editor
restart, source-content save, generated runtime change or gameplay traversal
claim is included in these checks.

### V3c: shared viewport behavior

Requested November 12, 2026 after the centering fix: replace the separate
Campaign and Chunk viewport mechanics with a common owner. The earlier V3b
reuse covered controls and render components, not the viewport implementation.

- [x] Share zoom state, reset/restore, centering, coordinate conversion and
  free/bounded pan policies. Preserve Chunk navigation snapshots and Campaign's
  fitted-height, lazily rendered route and scrollbar.
- [x] Share pointer ownership, Ctrl+drag and Ctrl+wheel routing; keep terrain
  and mission edit commands with their existing owners. Cover empty canvas
  space and prevent navigation from changing coordinates during an edit drag.
- [x] Verify shared behavior and both consumers, including zoomed-out placement,
  cancellation, Visual preview, route scrolling and existing draft/history gates.
- [x] Record validation and update the implemented viewport contract.

Starting source: `05720278`. Existing localized Campaign forms, chapter tests,
Contents/page changes, README/TDD edits and map-asset renames belong to unrelated
work and must be preserved. No source geometry or gameplay contracts change.

Implemented in `EditorSceneViewportController` and `EditorScenePointerRegion`;
both consumers remove their old centering, zoom/reset and pan/wheel paths.
Campaign retains its scrollbar and lazy renderer, with one viewport-wide input
surface and fresh scroll-coordinate conversion for each edit event. Chunk keeps
its centered free canvas and existing navigation snapshots.

Local validation on November 12, 2026, from `tools/editor`, against this viewport
change over `c6421041` and the concurrent unrelated worktree changes:

| Command/check | Result |
| --- | --- |
| `flutter test test/editor_scene_viewport_test.dart test/chunk_polygon_authoring_controller_test.dart test/campaign_authoring_test.dart --reporter expanded` | 62 passed |
| `flutter test test/chunk_authoring_workspace_test.dart test/campaign_authoring_test.dart --name 'shared viewport\|blessing fire feedback\|route preview fills\|Connections opens\|direct marker\|direct prefab move\|chunk scene shows its tile grid\|wide chunk workspace\|chunk creation scene and sidebar remain usable' --reporter expanded` | Both added Campaign cases passed (empty-margin navigation/placement and pan across 16 mission chunks); Chunk target failed to compile due to a missing import in its new test |
| `flutter test test/chunk_authoring_workspace_test.dart --name 'shared viewport\|Connections opens\|direct marker\|direct prefab move\|chunk scene shows its tile grid\|wide chunk workspace\|chunk creation scene and sidebar remain usable' --reporter expanded` | 8 passed after correcting the test import |
| `dart analyze lib/src/app/pages/shared/editor_scene_viewport.dart lib/src/app/pages/campaign/campaign_overview.dart lib/src/app/pages/campaign/campaign_scene_controls.dart lib/src/app/pages/chunkCreator/v2/chunk_authoring_workspace.dart lib/src/app/pages/chunkCreator/v2/chunk_scene_surface.dart test/editor_scene_viewport_test.dart test/campaign_authoring_test.dart test/chunk_authoring_workspace_test.dart` | No issues after the import correction |
| Task diff whitespace check | Passed |

These are local automated checks, not a native-editor restart or gameplay
traversal acceptance. Context7 was unavailable; Flutter's official
[pointer-signal resolver](https://api.flutter.dev/flutter/gestures/PointerSignalResolver-class.html)
and [hit-test behavior](https://api.flutter.dev/flutter/rendering/HitTestBehavior.html)
documentation supplied the event arbitration contract. Existing V4 native and
gameplay gates remain open.

### V4: acceptance and documentation

- [x] From Markers, create and adjust every requested object type without editing
  JSON or opening Chunk Creator for ordinary placement. Verify a repeated chunk
  can contain different objects in each mission chunk and another mission is unchanged.
- [x] Automated coverage for create/move/duplicate/delete, cross-mission chunk
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
  at 30/120 Hz, including mission chunk-specific content. Retain existing compatibility
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
| `packages/runner_content_pipeline`: `campaign_placement_source_test.dart` using cached Dart test runner | 11 passed: strict additive source, distinct repeated mission chunks, enemy identity, incomplete rescue readiness, trap/rescue composition, gold/gems and attached fires |
| Same runtime fixtures | Both characters, seed 42, 30/120 Hz, two repeated flat Training Field chunks; continuous travel 60→1100→80→1100 with a 20-second budget per leg. Pickups remain consumed, fires retain state, blessing does not stack, restart resets. Missing/moved/out-of-bounds support fails |
| `packages/runner_core`: `interactions/world_interaction_test.dart interactions/world_interaction_game_core_test.dart` | 25 passed, including actual prefab top contact, airborne/side/stale/enemy/dead negative controls, both characters, captured-Play parity and old manual bindings |
| `tools/editor`: `campaign_authoring_test.dart` | Existing chapter/reward/route/panel/Save/drift tests passed; the new coin/fire widget test passes place/drag, Escape cancellation, unfinished-gesture and invalid-field Save blocking, valid draft resolution, attach rejection, undo/redo, Save/reopen and untouched chunk bytes. The Windows image-I/O cleanup race was resolved by draining frames and real I/O after unmount |
| Same file: `--plain-name 'every palette brush'` | Passed all eight placement brushes, incomplete-to-complete rescue editing, cross-mission chunk movement, duplicate/delete, undo/redo, stale-revision rejection, Save/reopen and another mission remaining unchanged. Its two-minute timeout covers repository I/O and repeated validation; simulation horizons are unchanged |
| `tools/editor`: `campaign_marker_edit_test.dart`, `chunk_marker_scene_gesture_test.dart`, `chunk_v2_marker_placement_projection_test.dart`, `chunk_trap_authoring_test.dart`, `chunk_encounter_authoring_test.dart` | 25 passed: objective remapping and mission chunk duplication plus regressions for reused scene projections, gestures and inspectors |
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
- [x] Freeze the validated source and complete canonical preparation, reusing
  component and navigation evidence only when its inputs and artifact bytes match.
- [x] Build and benchmark the worker image; build and inspect a matching dev APK.
- [x] Inspect dev, pause issuance, review drain, deploy the coordinated candidate
  and verify readiness before resuming issuance. Record actual artifact identities.
  Dev now serves 2026.11.11; device and signed-in Play Games acceptance remain unrun.

November 12 content checkpoint: Reporting for Duty revision 26 includes sixteen
campaign-only Forest mission chunks, supported start at (60, 224) and a final-chunk
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

Candidate `72b0cea3`: all client analyzers passed; the full suite completed with
1,529 passed, one existing skip and two custom polygon-generator fixture failures.
Both omitted the item source required by the captured Build snapshot. Initializing
them through the existing source-fixture helper adds that source before their
custom prefab definitions. Both focused cases passed (16 seconds); production
snapshot validation is unchanged. Replay checks again passed 366 tests, the
fixture-only skip and AOT probe. Fresh read-only Inspect at 07:31 UTC retained the
same three issued tickets and 34 accepted/settled runs without consistency errors.

The remaining build/Core/protocol/content/terrain/freshness components are being
validated with `validate_release.ps1` in clean `72b0cea3`, using the shared cache.
The replacement changes only two root test lines and this checklist: those
components' input sets are unchanged and canonical Prepare must verify that match
before reuse. Client checks require fresh evidence for the repaired fixture source.

The content component found one additional stale assumption: its editable-draft
round-trip test read the included production mission as a draft. The test now
constructs an explicit excluded, incomplete draft before checking round-trip,
rewards and readiness rejection. All five campaign-source tests pass locally;
runtime and authored content are unchanged. The full content component remains
required. The client integration test also hit its existing four-minute timeout
while web artifacts were being copied; remaining SDK checks will run serially,
without changing that timeout or claiming the interrupted suite passed.

Candidate `e44171b2`: content analysis and all 119 tests passed; terrain analysis
and all 25 tests passed; generated freshness passed with the same navigation
revision. On `5e9ddb08`, the isolated item-generation case passed in 1m28s with
its four-minute timeout unchanged, and every client analyzer passed. The full
client run exposed a separate ghost widget fixture race: a concurrent account
cleanup removed the default app spool directory while its recorder opened a
file. The fixture now injects a real file recorder in a private temporary
directory and awaits session stop before deletion. No runtime code or readiness
assertions changed. The `5e9ddb08` run completed with 1,530 passes, one existing
skip and only that ghost failure; both polygon-generator repairs passed. The
focused `flutter test --no-pub test/ui/runner_game_widget_ghost_test.dart
--reporter expanded` passed both cases in 31 seconds. Teardown pumps the fake
microtask queue while real file IO completes; awaiting it solely inside runAsync
stalled an initial focused attempt, which was stopped and corrected. Replacement
full-suite verification remains required in canonical Prepare.
Matching web/Core/protocol/worker/backend evidence remains reusable after input
verification; this test edit changes only the client-checks component.

Candidate `4a9df290`: every client analyzer and all 1,531 client tests passed
(one existing skip), including both ghost lifecycles and both polygon repairs.
Content analysis/119 tests and terrain analysis/25 tests also passed. Canonical
Prepare then correctly rejected three campaign projections at generated freshness.
The main worktree retained 174 CRLF lines in `terrain_material_defs.json`, despite
the existing authored-JSON LF rule; its byte hash had entered the campaign digest.
The Git/LF source and the rendered catalogs therefore disagreed.

An isolated repair branch from `4a9df290` regenerates from canonical authored
bytes. Only the three campaign digest constants change to
`5bdd08b07d1c044a2c5ca11ddc3eb22ec6d64a6c57eb469e7813c62fc40115b9`;
geometry, mission policy, terrain and navigation revision are unchanged. Campaign
generated outputs are now explicitly pinned to LF. A replacement candidate must
pass freshness first and rebuild/revalidate every component whose input hash
changed. Existing navigation graphs remain reusable by exact key. The later
editor commit `b7c6fe10` is preserved in the main worktree and excluded from this
repair branch/release. No cloud mutations have occurred.

### November 12 canonical release evidence

Frozen candidate `88c040600dcbc557c9b78dc3c16fb6b110262a3f` passed canonical
`Prepare -Environment dev` at 11:20 UTC. Its source digest is
`2cb25bab646df93e4b9d85afab3f155a214a9fce633d384e73589b067064e6bd`.
The LF repair is integrated on the main branch as `ea1f0856`; later editor and
campaign-authoring work is preserved separately and excluded from this candidate.

All required components passed: 1,531 client tests (one existing skip), 2,645 Core
tests, 136 protocol tests, 119 content tests, 25 terrain tests, 366 worker tests
(one fixture-only skip), 385 Functions emulator tests and five inventory tests.
Analyzers, generated freshness, the worker AOT probe, optimized web build and
Chrome artifact smoke passed; the fresh production dependency audit reported no
known vulnerabilities. Canonical evidence retains the original provenance for
matching cached protocol, terrain and freshness components. Client navigation
reused all 3,740 exact-key graphs; the navigation algorithm revision is unchanged.

The read-only 11:26 UTC dev inventory contained 70 sessions: 16 cancelled, 19
expired, one issued past its expiry and 34 validated. All 34 grants were settled;
canonical gold remained 3,604, with no settlement backlog or consistency errors.
This inspection predates cutover and does not establish a completed deployment.
Worker Cloud Build `5887afd2-8465-4a96-9551-dc831a0a4224` succeeded, including the
strict 36,000-tick final-container benchmark for Field and Forest. Its immutable
image is `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:16ddacc34c3ad4ec244dd4130fdd2f39145c74233eb592faf0fcc96bd2108519`.
Navigation reused 79,310 graphs from the verified previous immutable image and
built 14,650 graphs for the six changed ranked seeds; runner geometry is unchanged.

Canonical `BuildAndroid -Environment dev -AndroidVersionCode 8` completed at
12:06 UTC from the same frozen source. Inspection verified package
`com.example.rpg_runner.dev`, version `1.0.0-dev`/8, dev Firebase/Play resources,
signing, all 3,740 navigation graphs, three ABIs, twelve native libraries and
16-KiB native alignment. All three Dart symbol files are retained; dev symbol
upload is intentionally disabled. APK SHA-256 is
`36bf68878ac0d648e939054c44e9ca1381ae28d45a633ea0c675aec2c3a78b19`;
the delivery copy `.tmp/dev-release-20261112/app-dev-release-v8.apk` matches it.
No device was connected at 12:02 UTC; device and signed-in Play Games acceptance
remain unrun.

The refreshed 12:03 UTC inventory showed zero active tickets: 16 cancelled,
20 expired and 34 validated, with all 34 grants still settled and gold unchanged.
The remaining issued ticket expired naturally; no owner-requested cancellation
has been performed. PauseIssuance found the old issuer image removed by managed
cleanup and used the canonical prepared-source rebuild with its explicit pause
gate. The first Firebase discovery attempt exceeded its local ten-second timeout
before deployment. Retrying with the documented process-only
`FUNCTIONS_DISCOVERY_TIMEOUT=120` succeeded; the original environment was restored.
The healthy paused issuer was verified at 12:18 UTC.

Canonical `Deploy -Environment dev -CutoverReady` completed at 12:33 UTC: all 34
non-issuer Functions updated, Firestore rules/indexes deployed, worker revision
`replay-validator-00068-q28` became ready with 100% traffic, board maintenance ran,
and Hosting published. The live web JavaScript matched prepared SHA-256
`11a3958a98c0c9a58c4db732fc95dae2a2c4d0f62dc5855280b08ce7ae540637`.

The 12:36 UTC resume inventory had all three expected 2026.11.11 boards active,
the three 2026.11.10 boards disabled, zero active tickets and no settlement
backlog. All 34 accepted runs/settled grants and canonical gold 3,604 were
preserved. `ResumeIssuance -Environment dev -CutoverReady` completed at 12:40 UTC
after exact live worker/Hosting checks. It resumed both queues, deployed the
matching issuer, removed the temporary pause gate, saved the verified dev
baseline and cleared the source-bound cutover record. The release locks were
released normally. No tickets needed owner-requested cancellation.

Independent 12:41 UTC live readback confirmed issuer revision
`runsessioncreate-00101-qzq` Ready with 100% traffic and no pause override;
`replay-validation` and `replay-projection` were both RUNNING. Evidence is retained
in the frozen checkout's source-digest directory, including the post-resume
receipt, release/Android manifests and worker/benchmark logs. Later working-tree
campaign/settings/editor changes are outside this deployed candidate.

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

Campaign settings follow-up, November 12 (local working-tree source): supplied
JPEGs moved to `assets/images/maps/lothringen_bonfire.jpg` and `theodonis.jpg`
with identical Git blob hashes; Town references and the asset manifest were updated.
Validation used the installed SDK binaries directly to bypass Windows wrapper/cache
permissions; equivalent commands and working directories are recorded below.

| Directory | Check | Result |
| --- | --- | --- |
| `tools/editor` | `flutter test --no-pub --concurrency=1 --timeout=2m test/campaign_settings_test.dart` | 3 passed: guarded Save/reopen/Undo, picker/Apply/Cancel, image/path validation |
| `packages/runner_content_pipeline` | `dart test test/campaign_settings_source_test.dart` | 2 passed on the final path policy |
| Root | `flutter test --no-pub test/tool/campaign_map_generation_test.dart test/tool/content_build_snapshot_test.dart` | 3 passed: source/game metadata, map capture and invalid/missing/changed images |
| Root | `flutter test --no-pub test/ui/pages/campaign_page_test.dart test/ui/pages/meta/codex_library_test.dart` | 23 passed, including campaign and Town maps |
| Root | `dart tool/generate_chunk_runtime_data.dart --dry-run`; `dart tool/sync_assets.dart --check`; `git diff --check` | Passed after generation |
| Root | `corepack pnpm --dir functions build` | Passed with regenerated metadata |
| Root and `tools/editor` | Targeted `dart analyze` for campaign sources/UI, map generation, build capture and new tests | No issues |

Earlier combined editor runs hit Windows I/O timeouts and were interrupted; they
do not establish a full editor-suite pass. The final settings checks ran serially.
Native explorer interaction remains a manual acceptance check; widget tests inject
the picker result. Concurrent editor changes were preserved; task edits remain
uncommitted alongside that work. No deployment or device acceptance is claimed.

### Campaign editor usability follow-up (November 12)

Current scope preserves the pre-existing uncommitted campaign/map work. Acceptance:

- [x] Campaign spacing and Completion skills/items summaries above the selector.
- [x] Shared geographic placement with zoom/pan and actual game callout preview;
      measured labels avoid pins/one another where space allows, and leaders
      terminate at measured label edges. Campaign consumes the same layout.
- [x] Confirm selected-mission deletion by exact name, guard stale commands,
      retain at least one mission per chapter, reserve deleted IDs across Save,
      and preserve Undo/Redo, selection and source-drift protection.
- [x] Share the 48-chunk cap across Core, source validation and editor controls;
      reject 49 and verify a compiled 48-chunk route.
- [x] Route selection reveals its chunk in the preview; action tooltips use chunk.
- [x] Focused editor/pipeline/game checks, generator freshness and diff review.

Local evidence (November 12):

- `tools/editor`: `flutter test --no-pub --concurrency=1
  test/campaign_chapter_dialog_test.dart test/campaign_settings_test.dart
  test/campaign_chapter_section_test.dart` passed 8 tests. Coverage includes
  language drafts, placement/numeric sync, zoom/pan, actual game preview and
  cancellation.
- `tools/editor`: targeted `test/campaign_authoring_test.dart` invocations passed
  deletion guards/Save/history, typed-name confirmation/cancellation, unsaved
  chapter history, reward selection, chapter navigation, route preview selection
  across 48 chunks, existing view-context/route controls and appending through
  the 48-chunk boundary (including Undo). These are focused checks, not a claim
  that the full editor suite ran. Initial failures from test scroll settling,
  animation timing and the renamed Mission Settings panel were corrected and
  their focused reruns passed.
- `packages/runner_content_pipeline`: `dart test test/campaign_source_test.dart
  --reporter expanded` passed 7 tests, including the compiled 48-chunk route,
  rejection of 49, reserved-ID validation and existing traversal regression.
  This does not establish traversal or device performance for a 48-chunk mission.
- Root: focused `flutter test` coverage in
  `test/ui/pages/meta/map_callout_test.dart` and `test/ui/pages/campaign_page_test.dart`
  passed 11 tests. Clustered-label fixture bounds were corrected to allow the
  measured enlarged labels to fit; impossible dense layouts retain the documented
  least-overlap fallback.
- Before concurrent reward/combat contract edits, targeted root/editor
  `dart analyze` passed with no issues. Root
  `dart run tool/generate_chunk_runtime_data.dart --dry-run` passed freshness
  validation for 166 chunks, 3 levels, 3 parallax definitions and 3 materials.
  `git diff --check` and `node tools/agents/check.mjs` passed.

A later analysis overlapped the concurrent reward migration and reported stale
`rewardAbilityId` test references; those references were subsequently migrated
by the concurrent work. Initial follow-up test runs also overlapped generation
and failed on the removed `combatAllowed` constructor argument. After the shared
source/catalog aligned, the pipeline command above passed all 8 current tests.
The final editor run of `test/campaign_authoring_test.dart` with
`--name 'mission deletion guards|delete mission requires|reward selectors|route preview fills|appending chunks retains'`
also passed all 5 selected tests against those concurrent updates.
These transient failures do not establish a clean final whole-tree analysis.

Concurrent uncommitted work remains preserved. No native interactive session,
deployment or device performance acceptance is claimed for this follow-up.

Next: native-editor usability and user-authored production layouts/M4 acceptance.
Keep content/device acceptance explicit;
archive this plan only once that remaining work is completed or replaced.


### Mission rewards and combat-policy cleanup (November 12)

Acceptance for this follow-up preserves the existing uncommitted campaign/map work:

- [x] Replace the mission XP/ability controls with a first-clear reward modal,
      sharing Chapter rewards' XP/gold/catalogue picker and cancellation behavior.
- [x] Preserve authored XP and Double Jump; support explicit skill recipients and
      account-wide equipment through generation, results and canonical settlement.
- [x] Remove the combat toggle, source field and runtime permission check; content
      alone determines combat, while existing placement/readiness checks remain.
- [x] Verify focused editor, pipeline, Core, generation and settlement checks;
      review the final diff and record local evidence.

Local verification on November 12 (uncommitted current sources):

- `packages/runner_content_pipeline`: `dart test test/campaign_source_test.dart
  test/campaign_placement_source_test.dart --reporter expanded` passed 19 tests.
- `packages/runner_core`: `dart test test/campaign/campaign_runtime_test.dart
  --reporter expanded` passed 4 tests, including authored combat admission and
  continuous outward/return state.
- `tools/editor`: `flutter test --no-pub --concurrency=1 --timeout=2m
  test/campaign_authoring_test.dart --plain-name "reward"` passed 3 tests. After
  extending picker/nested-draft coverage, the same command with
  `--plain-name "reward selectors"` passed its selected test. Coverage includes
  gear/skill selection, XP/gold, Apply/Cancel, Save/reopen, Undo and source drift.
- Root: `flutter test --no-pub test/tool/generate_chunk_runtime_data_test.dart
  --plain-name "campaign generates"` passed, generating both reward projections
  and replaying the real worker at 30/120 Hz. Its first attempt exposed a missing
  map asset in the test fixture; the fixture now captures that dependency. The
  interrupted broad generator run is not a whole-suite pass.
- Root: `flutter test --no-pub --concurrency=1
  test/tool/campaign_map_generation_test.dart test/ui/pages/campaign_page_test.dart`
  passed 11 tests, including real generated reward metadata decoded by the client
  and English/French compact campaign views.
- Root: `corepack pnpm --dir functions build` and `build:test` passed;
  `node --test functions/lib_test/test/campaign/progression.test.js` passed 9
  local unit tests. No emulator or live Firestore transaction check is claimed.
  Mission/chapter grants, recipients, repeat suppression and combined-wallet
  overflow are covered.
- Targeted root/editor `dart analyze` passed with no issues. Root
  `dart run tool/generate_chunk_runtime_data.dart --dry-run`,
  `dart run tool/localization.dart check` and `git diff --check` passed.

The sandbox initially blocked SDK cache/build-output access; approved local reruns
completed the checks. Existing overlapping campaign/map edits remain uncommitted.
Native editor smoke, device performance and deployment remain unrun.

No deployment or device acceptance is authorized or claimed.


### Inline mission settings (November 12)

- [x] Move title/assignment language tabs, region, theme and Build inclusion into
      the Mission Settings sidebar; remove the old settings dialog and opener.
- [x] Keep first-clear mission rewards in their shared reward modal.
- [x] Join field drafts to Save/Play, Undo/Redo, mission/tab selection and guarded
      source edits; keep revision checks and plugin-owned writes.
- [x] Run focused inline-field, reward and responsive navigation checks and analysis.

Native editor interaction remains unrun; this follow-up changes no runtime policy.

Local checks from `tools/editor`: targeted `dart analyze` of the settings form,
inspector, page, remaining marker dialog and authoring tests passed. Focused
`test/campaign_authoring_test.dart` checks for workspace fields, responsive view
context and reward selectors passed (3 tests). The new inline-settings lifecycle
test passed separately with `--plain-name "inline mission settings"`, covering
bilingual validation, blocked tab changes, Save, Build inclusion, Undo and mission
switching. Its first two runs completed assertions but failed Windows cleanup
while unrelated atlas previews held fixture images open. The final test uses an
empty authored draft and a no-match chunk search to isolate metadata behavior;
preview coverage remains in the existing workspace tests. `git diff --check`
passed. This follow-up changes no generated/runtime contracts and does not claim
native editor acceptance or a full-suite run.

### Mission chunk terminology (November 12)

- [x] Rename campaign route instances to mission chunks across authoring, Core,
      editor selection, placement/objective bindings and generator templates.
- [x] Rename existing authored IDs to `mission_chunk_N` and JSON references to
      `missionChunkId` directly, without compatibility aliases or migration.
- [x] Regenerate catalogs and verify source round trips, editor marker/route
      behavior, finite streaming, campaign runtime and worker replay parity.
- [x] Audit remaining terminology and record focused validation evidence.

Local verification for the terminology rename (uncommitted sources):

- `packages/runner_content_pipeline`: `dart test test/campaign_source_test.dart
  test/campaign_placement_source_test.dart --reporter expanded` passed 19 tests.
- `packages/runner_core`: `dart test test/track/finite_chunk_pattern_source_test.dart
  test/track/finite_track_streamer_test.dart test/campaign/campaign_runtime_test.dart
  test/interactions/world_interaction_test.dart --reporter expanded` passed 29
  tests, including continuous return travel and independently bound placements.
- Root: `flutter test --no-pub test/tool/generate_chunk_runtime_data_test.dart
  --plain-name "campaign generates"` passed real generated-catalog/worker parity
  at 30/120 Hz.
- `tools/editor`: `flutter test --no-pub --concurrency=1 --timeout=2m
  test/campaign_marker_edit_test.dart test/campaign_authoring_test.dart` passed
  24 cases and exposed ambiguous French-tab/Apply selectors in the chapter test
  after the concurrent inline settings change. Both selectors now target the
  chapter dialog; rerunning `--plain-name "chapters collapse, create and reveal
  selected missions"` passed the remaining case. All 25 targeted cases have
  passing evidence; the entire editor suite was not run.
- Targeted root/editor `dart analyze` and `corepack pnpm --dir functions build`
  passed. Generation and its `--dry-run` passed; Core, client and backend share
  the same final content digest. An initial generation attempt correctly rejected
  concurrent source drift; a fresh run completed without bypassing that guard.
- The authored-source comparison found only the intended ID/field rename and
  catalog/mission revision increments. All references resolve. The campaign
  terminology audit, `node tools/agents/check.mjs` and `git diff --check` passed.

Unrelated concurrent campaign/settings edits were preserved. Native editor smoke,
device acceptance and deployment remain unrun.

### Mobile HUD in mission Play (November 12)

- [x] Enable the real mobile game HUD by default in captured mission Play, with
      a pre-launch Show mobile HUD toggle and arrows/floating/fixed joystick selection.
- [x] Keep accepted choices local to the Campaign page and retain them through Restart;
      preserve frozen source, backend isolation and keyboard controls.
- [x] Neutralize held input across pause and teardown.
- [x] Verify all three styles with pointer-driven movement and frameless
      pause/resume, disabled HUD, restart, and editor default-host selection.
- [x] Use the character catalog's starter equipment, restoring the shield slot;
      verify shield hold/release and preserve explicit scenario overrides.
- [x] Fill the simulated mission display with pixel-perfect cover; share rendering,
      pointer aim and HUD indicator geometry. Remove running setup controls.
- [x] Open setup from Play mission/F5 before capture; Cancel preserves the
      document and does not create a runtime. Remember only accepted choices.

Initial verification before the launch-setup correction: root
`flutter test --no-pub test/playtest/runner_chunk_playtest_host_test.dart
test/ui/hud/game/hud_layout_test.dart` passed 13 tests using the real Core/Flame
host with fixture sprite images. From `tools/editor`,
`flutter test --no-pub test/authored_playtest_session_test.dart
test/campaign_authoring_test.dart --name "Save/reopen|capture locks|source replacement|capture failure"`
passed four captured-Play/session tests. Targeted implementation analysis and
diff checks passed. Native editor interaction and device acceptance were not run.
See the [playtest contract](../../tdd/editor_chunk_playtest_host.md#presentation-and-input).

Follow-up verification on the uncommitted working tree (November 12):

- Root `flutter test test/playtest/runner_chunk_playtest_host_test.dart
  test/ui/hud/game/hud_layout_test.dart --reporter expanded` passed 15 tests.
  The host-only rerun after visual-review font setup passed 13 tests. Most tests
  use fixture images with real Core/Flame; the viewport test loads real repository
  images and writes `build/test/campaign_playtest_hud.png`. The 1770×797 review
  confirms the shield control and filled game area; layout also checks 1.25 DPI.
- From `tools/editor`, `flutter test --no-pub
  test/campaign_playtest_dialog_test.dart test/authored_playtest_session_test.dart
  test/campaign_authoring_test.dart --name "Play returns|HUD can be|Cancel discards|mission Play and F5|Save/reopen|capture locks|source replacement|capture failure"
  --reporter expanded` passed 10 focused setup/capture tests.
- Targeted root and editor analysis passed. Native editor interaction, physical
  device acceptance and deployment remain unrun.
- Broader editor integration checks exposed separate failures: Level Play and
  sample preview reject `forest_boss_easy_cmp_001` with
  `level_playtest_unmatched_terrain` because the captured terrain includes
  campaign chunks outside the runner pool. Chunk tests had undersized synthetic
  sprite atlases; reusing the catalog-derived fixture bounds resolves that load
  error, but the capture test still expects six rocky-grove chunks while the
  current repository supplies eighteen. The Chunk rerun finished with four
  passes and two failures: that stale count and a 49-pixel horizontal overflow
  in the focused-metadata form. The separate Level run had two pool failures.
  These failures are not mission HUD
  acceptance evidence and remain explicit rather than weakening assertions.

Device preview follow-up (November 12):

- [x] Add one shared display value/catalog using Chrome DevTools landscape sizes
      and DPR, plus validated Custom dimensions in the launch modal.
- [x] Lay out the whole game/HUD at device dimensions before uniformly fitting
      it into the editor. Preserve proportions and runtime through window resize.
- [x] Share viewport metrics across rendering, indicators and mouse aiming;
      transform the aim-cancel target correctly when the display is scaled.
- [x] Verify preset/custom selection, invalid-input recovery, resize/DPI isolation,
      scaled movement, aim cancellation and rendered mobile layout.

Device-preview verification on the uncommitted working tree:

- Root `flutter test --no-pub test/playtest/runner_playtest_display_frame_test.dart
  test/playtest/runner_chunk_playtest_host_test.dart
  test/ui/controls/directional_action_button_test.dart --reporter expanded`
  passed 23 tests. All seven device layouts preserve their dimensions/DPR and
  map scaled taps correctly. Real Core/Flame tests cover all movement styles,
  shield hold, pause/restart, desktop aiming and aim cancellation after resize.
  The viewport case uses repository sprites at 1770×797 and 640×480 with monitor
  DPR 1 and 1.25; other host cases use fixture images.
- From `tools/editor`, `flutter test --no-pub
  test/campaign_playtest_dialog_test.dart test/campaign_authoring_test.dart
  test/authored_playtest_session_test.dart --name "Play returns|HUD can be|Cancel discards|launch captures|custom dimensions|compact launch|mission Play and F5|Save/reopen|capture locks|source replacement|capture failure"
  --reporter expanded` passed 19 tests, including preset/custom validation,
  compact-dialog scrolling, Cancel/F5 isolation and captured-session lifecycle.
- Targeted root/editor `dart analyze` passed with no issues. `git diff --check`
  passed. Visual review of `build/test/campaign_playtest_mobile.png` confirms
  the game, text, shield and other controls scale together inside the preview.
  Native editor interaction and physical-device acceptance remain unrun.

The subsequent cross-host cleanup, shared launch setup for Chunk/Runner Level/
Campaign and physical-size device previews are tracked only in the
[shared gameplay runtime plan](../shared_gameplay_runtime.md). The evidence above
describes the existing fit-to-window Campaign preview, not that planned migration.
