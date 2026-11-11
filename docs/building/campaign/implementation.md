# Campaign implementation checklist

Status: implementation started November 11, 2026; initial Core primitives added,
playable campaign integration pending.
This is the sole progress checklist for the campaign workstream. Design details
are linked from the [plan index](README.md).

## Execution rules

Implement in dependency order. A milestone is complete only when its acceptance
gate and relevant checks pass. Keep public producer/consumer migrations coherent:
do not ship a new mode or outcome that any decoder, validator, or UI cannot handle.
Local prototypes may remain outside production admission while dependent work is
unfinished; they cannot masquerade as Practice to gain existing rewards.

Follow the [coordination workflow](../../../.agent/workflows/coordinate-work.md)
and applicable owner instructions. Stage task-only changes, review them, and make
small validated milestone commits. Record evidence with source, working directory,
command, result, and limitations. A milestone or this plan does not authorize a
cloud deployment, account reset, or unrelated work.

## M0: contracts and finite-world design

Owners: Core, content pipeline, protocol, editor, UI state, Functions, validator.
Dependencies: source inspection and confirmed requirements in this folder.

- [x] Record requested experience, bidirectional movement, current limitations,
  proposed scope, ownership, and dependency order in one planning folder.
- [x] Incorporate the user's post-Le feu de joie cultist premise, encounter-free
  arrival mission, manual layout ownership, Double Jump/Willow unlocks, level-3
  XP target, and bidirectional chunk-copy converter requirement.
- [ ] Recheck current source/worktree and trace all forward-camera lifetime
  assumptions and run mode/outcome producer-consumer boundaries.
- [ ] Settle chapter/mission/occurrence identities, schema, source ownership,
  campaign-only variant admission, two-way conversion semantics, inclusion rules,
  mission-one content validation, and dependency fingerprint.
- [ ] Specify finite bounds, camera follow, terrain residency, actor activation,
  lifetime/timer semantics, objective ordering, and successful terminal outcome.
- [ ] Specify mode/ticket/replay/result/account fields and compatibility, including
  mission identity versus existing `levelId`, digests, versions, and old records.
- [ ] Record trusted gold/XP/ability/character reward projections and mission/chapter
  entitlements, Willow availability across modes, and existing-account/ticket
  compatibility; enumerate other eligible projections. Target 224 first-pass XP.
- [ ] Define the small mission fixture, supported size/performance targets, and
  exact behavior checks before implementing the shared contracts. The fixture is
  separate from the user's encounter-free Reporting for Duty layout.

Acceptance: each invariant has one owner; no unresolved identity, lifetime, or
wire assumption forces a contradictory M1 implementation. Reward amounts and
final mission titles may remain open. Update design documents with decisions,
not a second checklist.

## M1: one playable return-trip mission

Owners: Core, pipeline/generator, game/controller, local session/play host, protocol
and validator wherever shared outcomes/replays change. Depends on M0.

- [x] Establish independently tested finite source/resident scheduler and bounded
  bidirectional camera primitives, without admitting campaign into normal runs.
  This is a foundation only; the integration gates below remain open.

- [ ] Compile a finite route of a few reused chunks with stable occurrences,
  guaranteed enemy/item placement, a supported start, objective, and exit.
- [ ] Implement bounded bidirectional movement/camera and the chosen terrain and
  entity lifetime policy; preserve all needed gameplay state on return travel.
- [ ] Remove campaign dependence on runner scrolling, behind-camera failure,
  random route/spawn defaults, and camera-driven encounter expiry.
- [ ] Add Core objective progress and once-only success alongside normal failure,
  abandonment, pause, retry, and death presentation behavior.
- [ ] Provide a local development launch and minimal mission HUD/results using
  the production mission simulation; no canonical rewards in the prototype.
- [ ] Integrate affected shared event/recording/result consumers and demonstrate
  replay parity through the validator's production simulation path with trusted
  local fixtures. Authenticated issuance/settlement remains M3.
- [ ] Validate Éloïse's basic-jump traversal and explicitly unlocked local Willow
  regression cases, return-path navigation, same-tick terminal ordering, repeated
  chunk occurrences, and no duplicated enemies/items/score. Validate the
  encounter-free result of ordinary edits to copies that originally had enemies.
- [ ] Measure initial terrain preparation, return travel, frame/tick costs, and
  memory against the declared small-route budget; record residency decision.
- [ ] Update implemented simulation/output documentation and relevant embedding
  API docs if their public surface changes.

Acceptance: start, cross the actual joins, defeat an enemy, collect an item,
return to the start, then reach the exit after completing the objective. Camera
and state remain correct, replay reaches the same outcome/tick/score, and failure
controls cannot claim completion. No teleporting or skipping chunks in evidence.

## M2: complete mission authoring

Owners: editor, content pipeline, generator, source assets; Core admission where
needed. Depends on the M1 production mission path.

- [ ] Add campaign/mission source domain and chapter library with semantic edits,
  revision/history, transactional Save, and source/dependency drift handling.
- [ ] Add exact route ordering, occurrence IDs, continuous preview, source reuse,
  where-used impact, and explicit shared-source/variant workflows.
- [ ] Add Copy to Campaign / Copy to Runner with fresh identities, source
  preservation, destination owner/group/tier/usage, supported encounter preservation,
  adaptation reports, transactional Save, and destination validation. Prove
  supported layout round-trip fidelity without silently dropping metadata. Leave
  encounter removal to the user's subsequent edits; provide no removal preset.
- [ ] Add start/exit/objective authoring, mission settings, and chapter prerequisite
  controls using existing geometry and presentation components.
- [ ] Validate source references, inclusion, bounds, actual seams, target ownership,
  guaranteed required placements, and initial/terminal readiness.
- [ ] Extend captured authored Play and return navigation without requiring a
  runtime build; preserve unsaved state and captured dependency isolation.
- [ ] Integrate campaign output and transitive freshness into atomic Build and
  applicable navigation preparation; keep generated artifacts generated.
- [ ] Recreate and modify the M1 mission entirely through the editor, including a
  variant and a repaired return-path seam, then save/reopen/play/build it.
- [ ] Provide the user with the workflow to copy Forest rocky_grove easy/normal
  layouts and trainingcamp layouts into the first mission. Do not select or
  author their production route as part of the tooling milestone.
- [ ] Update implemented editor/content pipeline documentation and instructions
  only where ownership changes.

Acceptance: a complete finite mission can be authored without JSON edits. Invalid
runtime drafts remain saveable where structurally valid; Play/Build reject them
with precise diagnostics. Shared edits refresh dependents and never silently
change a mission occurrence's identity or contaminate runner selection pools.

## M3: campaign UI and verified progression

Owners: UI/app/state/localization, protocol, Functions, validator, relevant Firestore
contracts. Depends on M1 contracts and M2 compiled catalogue.

- [ ] Add the third hub card with a Val Outpost map crop; fit all three cards on
  one row across supported viewports, safe areas, languages, and enlarged text.
- [ ] Add campaign map, independent Val Outpost access, mission selection/details,
  selected-build launch, results, retry/next/chapter navigation, and recovery UI.
- [ ] Complete authenticated campaign admission with prerequisite/content/build
  and character-availability checks, no board fields, and server-owned
  mission/reward policy resolution. Apply Willow's lock to selection, all run
  modes, saved-build restoration, restart, and Training Field.
- [ ] Update all request/ticket/replay/result codecs, repositories, fixtures,
  compatibility/digests, and worker admission as one coherent contract change.
- [ ] Extend verified settlement and full canonical receipts with mission clears,
  comparable personal bests, chapter progress, once-only first-clear entitlements,
  and explicit repeat/failure rewards.
- [ ] Grant mission-one Double Jump through existing ability ownership and grant
  Willow once for four verified clears. Handle already-owned content, concurrent
  grants, explicit equip/selection UI, and starter initialization without erasing
  existing builds or equating provisioned gear with character availability.
- [ ] Define campaign XP distribution totaling 224 on the intended new-account
  first pass and keep score-derived runner XP from being applied a second time.
  Reconcile preview/receipt, level gifts, and retained account XP consistently.
- [ ] Integrate durable submission, pending-progress presentation, response-loss
  recovery, duplicate/concurrent settlement, account switching/deletion, and
  retained-data decoding. Next-mission admission uses canonical progress.
- [ ] Audit all shared stat, achievement, discovery, leaderboard, ghost, and
  reward projections for explicit campaign eligibility.
- [ ] Validate actual producer-to-consumer payloads and focused emulator/client/
  worker integration; keep local/mock evidence distinct from live acceptance.
- [ ] Publish implemented campaign TDD/GDD sections and revise menu/vision
  exclusions narrowly to reflect finite campaign chapters without claiming an
  open-world or large dialogue campaign.

Acceptance: a new account starts with Éloïse and sees Willow locked. Mission-one
success grants Double Jump once and unlocks the next mission; four clears unlock
Willow once. The intended first pass ends at 224 XP/level 3. Locked mission or
character requests, forged outcomes, incompatible content, and duplicate grants
are rejected. Runner rules remain unchanged apart from the deliberate shared
character-availability gate.

## M4: Val Outpost chapter and product acceptance

Owners: user-authored level layouts, editor/content integration, game/UI, Core
tuning, presentation/localization, trusted reward catalogue. Depends on M2
authoring, M3 progression, and the user's production layouts when available.

- [ ] Finalize four mission IDs/order and the three remaining assignments/titles
  within the cultist premise; keep Reporting for Duty's arrival objective and
  explicit absence of encounters. Localize text/prompts without inventing canon.
- [ ] Integrate and validate the user's editor-authored layouts when provided,
  including supported return paths and mission/chapter reward policies. Exact
  chunk selection and geometry remain the user's responsibility.
- [ ] Verify Reporting for Duty with Éloïse's basic jump, earned Double Jump for
  later missions where needed, and post-unlock Willow replay. Contextual prompts
  must match actual loadouts/input and require no unearned purchased skill.
- [ ] Complete chapter-wide player/enemy traversal, encounter, camera, replay,
  score, reward/unlock, localization, accessibility, and performance coverage.
- [ ] Validate campaign/runner/Training Field regression boundaries and new/returning
  account flows; update generated outputs, TDD/GDD, and content documentation.
- [ ] Record device/manual checks actually performed and retain explicit pending
  acceptance where hardware, sign-in, or backend deployment is unavailable.

Acceptance: the whole introductory chapter is playable, understandable, revisitable,
and reward-safe. The user's encounter-free forest arrival and cultist context are
preserved. Each mission has its own title, objective, results, rewards, and personal
best; intended return routes work with the character/skills actually available at
that progression stage. Chapter XP and both unlock milestones match the design.

## M5: release readiness and authorized rollout

Owners: existing release tooling and all changed contract owners. Depends on M4.

- [ ] Prepare one compatible source/artifact candidate, generated freshness,
  finite/bidirectional navigation evidence, and coordinated release assessment.
- [ ] Complete required release checks and record artifact identity plus explicit
  live/device gaps under the existing release workflow.
- [ ] Execute environment-specific rollout only within separate release
  authorization; verify deployed admission, replay, settlement, and app behavior.
- [ ] Finish signed-in device acceptance, repair outstanding findings, archive
  this completed folder, and update incoming links while preserving open evidence.

Acceptance: local implementation and deployed acceptance are reported separately;
release completion requires the actual authorized environment and device evidence.

## Resume checkpoint

Planning source: `1b8a77e2`, clean initial worktree, November 11, 2026. This task
adds planning documents and index links only. No application tests, runtime
generation, replay simulations, emulator work, or deployment have been performed
for campaign. Documentation validation is recorded in the task handoff.

Initial planning validation on the documentation worktree over `1b8a77e2`, from repository
root: `git diff --check` passed. An inline `python -` check passed for all six
campaign documents and the two new index entries: 36 local links/anchors resolved,
new files had final newlines and no trailing whitespace, and only this file owns
progress checkboxes. These are local documentation checks, not gameplay evidence.

Revision baseline: clean `c45d796f`, November 11, 2026. User decisions now fix the
four-mission count, post-chapter-3 cultist premise, mission-one forest arrival with
no encounters, Double Jump reward, Willow chapter unlock, 224-XP/level-3 target,
manual layout ownership, and runner/campaign chunk copying in both directions.
This revision still changes planning only; no production layout or character
availability has been modified.

Converter clarification from clean `c95dff1d`: preserve supported encounters during
copying. The user will edit each duplicate afterward; remove the proposed
encounter-removal option/preset and automatic mission-specific suppression from
the plan. Reporting for Duty still requires encounter-free final authored content.
Clarification validation from repository root: `git diff --check` and the inline
`python -` link/whitespace check passed for six campaign documents and 37 links.

Previous revision validation from repository root: `git diff --check` passed; the inline
`python -` documentation check resolved all 39 local links/anchors across six
campaign files and two index entries, with valid whitespace/newlines and one
progress checklist. The level-3 budget is 100 + 124 = 224 XP, checked against
`functions/src/ownership/player_progress.ts` and the current progression GDD.
These are documentation/source checks; no gameplay or converter tests ran.

Implementation baseline: clean `1ee69a66`. The initial Core foundation adds
immutable exact route occurrences, whole-route track residency, stable occurrence
IDs on scheduler output, single marker emission and a bounded bidirectional
camera. Existing runner selection and auto-scrolling remain unchanged. The
[implemented contract](../../tdd/campaign_runtime.md) records the boundary: these
components are not yet a complete mission or a production campaign entry point.

Next concrete action: finish M0's content/wire/admission decisions, then integrate
the M1 local mission fixture with physical bounds, ECS lifetime, terrain admission,
objectives and terminal/replay consumers. Measure whole-route collision/navigation
cost before admitting production route sizes. No campaign UI, editor converter,
account gating, rewards or deployment is complete. Production layouts are not
needed for that technical work. Remaining design decisions are the last three
assignments/titles, XP split and gold tuning, Willow's separate Double Jump
eligibility, and legacy availability handling, as described in
[Experience](experience.md).

Foundation validation, local worktree over `1ee69a66`:

- Repository root: `dart analyze packages/runner_core` passed after removing an
  import made unused by the shared immutable-pattern capture. Formatting of all
  nine changed/new implementation and test files passed.
- Repository root: `dart run tool/generate_chunk_runtime_data.dart --dry-run`
  passed (88 chunk files, three levels, three parallax themes, three materials);
  no generated files changed. `dart run
  packages/runner_core/tool/update_navigation_revision.dart --check` passed with
  unchanged revision `bd2274e0b71f13d538e131be959817d040eb11182da317b2db98903ed26a1e98`.
- `packages/runner_core`: the three new finite-source/streamer/camera test files
  plus `test/track/track_streamer_active_chunks_test.dart` passed all 18 tests.
  Full `test` execution passed 2,646 tests; five fresh-process checks failed only
  because child Dart processes could not write SDK telemetry under the sandbox.
  Rerunning the five affected files with SDK filesystem access passed all 40
  tests: `slopes_golden_geometry_test.dart`, `terrain_player_signatures_test.dart`,
  `enemy_terrain_signatures_test.dart`, `terrain_spawn_placement_test.dart`, and
  `terrain_surface_extractor_test.dart`. No gameplay assertion remained failing.
  The full run includes the existing Field/Forest traversal matrix and controls;
  it does not establish campaign traversal, whose integrated fixture is pending.
- Repository root: `flutter --suppress-analytics test --no-pub` with the eight
  targets `test/core/track_streamer_spawn_placement_test.dart`,
  `test/core/track_streamer_identity_passthrough_test.dart`,
  `test/core/track_streamer_hashash_deferred_spawn_test.dart`,
  `test/core/autoscroll_camera_test.dart`, `test/core/camera_vertical_follow_test.dart`,
  `test/core/command_scheduling_test.dart`, `test/core/determinism_test.dart`, and
  `test/core/fixed_point_pilot_test.dart` passed all 21 tests.
- Repository root: `git diff --check` passed. An inline Python check validated
  seven campaign Markdown files and 44 local link targets, URL-decoding filenames
  before checking their existence.

Environment detail: the initial `dart` SDK wrapper stalled on restricted local
SDK access and was cancelled. Direct SDK commands used
`C:/Users/Toonsa/flutter/bin/cache/dart-sdk/bin/dart.exe --suppress-analytics`.
`dart test` then tried a blocked pub.dev advisory lookup before testing; package
tests instead invoked the existing runner with
`dart --packages=../../.dart_tool/package_config.json
../../.dart_tool/pub/bin/test/test.dart-3.13.1.snapshot <targets>` from the Core
package. The full run used `test --reporter compact`; the five-file retry used
`--reporter expanded`. No dependencies or global analytics settings were changed.
No editor, UI campaign, replay-worker, backend/emulator, device, performance or
deployment acceptance is claimed by these component and runner-regression checks.
