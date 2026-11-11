# Campaign implementation checklist

Status: planning prepared November 11, 2026; gameplay implementation not started.
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
- [ ] Recheck current source/worktree and trace all forward-camera lifetime
  assumptions and run mode/outcome producer-consumer boundaries.
- [ ] Settle chapter/mission/occurrence identities, schema, source ownership,
  campaign-only variant admission, inclusion rules, and dependency fingerprint.
- [ ] Specify finite bounds, camera follow, terrain residency, actor activation,
  lifetime/timer semantics, objective ordering, and successful terminal outcome.
- [ ] Specify mode/ticket/replay/result/account fields and compatibility, including
  mission identity versus existing `levelId`, digests, versions, and old records.
- [ ] Record the trusted reward-policy projection and account/mission entitlement
  model; enumerate projections that admit or exclude campaign results.
- [ ] Define the small mission fixture, supported size/performance targets, and
  exact behavior checks before implementing the shared contracts.

Acceptance: each invariant has one owner; no unresolved identity, lifetime, or
wire assumption forces a contradictory M1 implementation. Reward amounts and
final mission titles may remain open. Update design documents with decisions,
not a second checklist.

## M1: one playable return-trip mission

Owners: Core, pipeline/generator, game/controller, local session/play host, protocol
and validator wherever shared outcomes/replays change. Depends on M0.

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
- [ ] Validate both starter characters, return-path navigation, same-tick terminal
  ordering, repeated chunk occurrences, and no duplicated enemies/items/score.
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
  checks, no board fields, and server-owned mission/reward policy resolution.
- [ ] Update all request/ticket/replay/result codecs, repositories, fixtures,
  compatibility/digests, and worker admission as one coherent contract change.
- [ ] Extend verified settlement and full canonical receipts with mission clears,
  comparable personal bests, chapter progress, once-only first-clear entitlements,
  and explicit repeat/failure rewards.
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

Acceptance: a new account can open Val Outpost and start mission one; verified
success grants the configured reward once and unlocks the next mission. Locked
mission requests, forged outcomes, incompatible content, and duplicate first-clear
grants are rejected. Existing runner modes retain their behavior.

## M4: Val Outpost chapter and product acceptance

Owners: authored content/editor, game/UI, Core tuning, presentation/localization,
trusted reward catalogue. Depends on M2 authoring and M3 progression.

- [ ] Finalize three or four missions, stable IDs/order, localized titles and
  assignments, explicit objectives, prompts, and chunk choices.
- [ ] Author every mission through the editor with guaranteed teaching encounters,
  supported return paths, and first-clear/repeat rewards from trusted policies.
- [ ] Tune both starter characters without purchased skills; ensure contextual
  prompts match actual loadouts and input devices.
- [ ] Complete chapter-wide player/enemy traversal, encounter, camera, replay,
  score, reward/unlock, localization, accessibility, and performance coverage.
- [ ] Validate campaign/runner/Training Field regression boundaries and new/returning
  account flows; update generated outputs, TDD/GDD, and content documentation.
- [ ] Record device/manual checks actually performed and retain explicit pending
  acceptance where hardware, sign-in, or backend deployment is unavailable.

Acceptance: the whole introductory chapter is playable, understandable, revisitable,
and reward-safe. Each mission has its own title, objective, results, rewards, and
personal best; all intended return routes work with continuous actor state.

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

Planning validation on the documentation worktree over `1b8a77e2`, from repository
root: `git diff --check` passed. An inline `python -` check passed for all six
campaign documents and the two new index entries: 36 local links/anchors resolved,
new files had final newlines and no trailing whitespace, and only this file owns
progress checkboxes. These are local documentation checks, not gameplay evidence.

Completed: planning package and confirmed requirement capture. Next concrete
action, when implementation is requested: M0 contract/residency audit and the M1
fixture specification. There are no user-input blockers to planning. Mission
titles/count, payouts, scoring coefficients, and shared-stat eligibility retain
their explicit defaults/deadlines in [Experience](experience.md).
