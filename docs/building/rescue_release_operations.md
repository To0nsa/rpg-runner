# Rescue release operations

Status: the leaderboard level patch was deployed October 18, 2026 UTC from
frozen commit `1a8e899c` under gameplay `2026.10.17`; see
[current production evidence](../verification/leaderboard-level-2026-10-18-production.md).
Linked Play Games production smoke remains outstanding. Earlier releases:
[2026.10.17 base release](../verification/game-compat-2026.10.17-production.md),
[2026.10.16](../verification/game-compat-2026.10.16-production.md),
[2026.10.12](../verification/game-compat-2026.10.12-production.md),
[2026.10.11.1](../verification/game-compat-2026.10.11.1-production.md),
[2026.10.11](../verification/game-compat-2026.10.11-production.md),
[2026.10.10](../verification/boss-combat-corrections-2026-10-08.md#production-release),
[2026.10.9](../verification/ancient-god-bosses-2026-10-07.md#production-release),
[2026.10.8](../verification/forest_boss_arena.md#production-release-2026108),
[2026.10.7](../verification/game-compat-2026.10.7-production.md),
[2026.10.6](../verification/game-compat-2026.10.6-production.md),
[2026.10.4](../verification/game-compat-2026.10.4-production.md),
[2026.10.3](../verification/game-compat-2026.10.3-production.md),
[2026.10.1](../verification/game-compat-2026.10.1-production.md),
[2026.09.10](../verification/game-compat-2026.09.10-production.md),
[initial rescue deployment](../archive/2026-09-25/verification/game-compat-2026.09.8-production.md)
and [Forest spawn release](../archive/2026-09-25/verification/game-compat-2026.09.9-production.md).

## Deployed leaderboard level patch: 2026.10.17

Only the leaderboard contract, backend enrichment, and online board UI were
carried forward from `master` onto the preceding production source. The owner
authorized the coordinated cutover and separately approved cancellation of
the one reviewed ticket only if it remained unsubmitted. See the
[release verification](../verification/leaderboard-level-2026-10-18-production.md)
for the exact source, receipts, immutable artifacts, and live checks.

- [x] Freeze `1a8e899c` with only the leaderboard diff; pass all ten required
  preparation components, current dependency audit, generated-content
  freshness, and production web build.
- [x] Build the 93,840-graph worker image in Cloud Build
  `151c4339-65d6-4df5-b40a-68910d25cd20` and pass all six strict
  exact-image benchmark gates.
- [x] Pause issuance; review and conditionally cancel exactly one unsubmitted
  ticket. Preserve all 333 accepted validations and settled grants.
- [x] Deploy Functions, Firestore rules/indexes, worker revision
  `replay-validator-00057-7jb`, and Hosting; verify six boards and byte-matching
  live worker and web artifacts.
- [x] Restore both queues and issuance; verify all 26 Functions ACTIVE, healthy
  worker and issuer revisions serving 100%, no pause gate, and no pending or
  quarantined settlement.
- [ ] Complete controlled signed-in Play Games leaderboard level display,
  accepted replay, once-only settlement, wallet catch-up, ghost playback, and
  target-device performance checks.

## Deployed release: 2026.10.17

The owner authorized this coordinated release and cancellation of only verified
unsubmitted tickets. The detached release recipe excluded 15 owner-accepted
Forest enemy-traversal failures. Those cases remain unresolved; no authored
chunk or repository test source was changed to make them pass. The
[release verification](../verification/game-compat-2026.10.17-production.md)
records the frozen source, build history, cutover evidence, and coverage limits.

- [x] Freeze `21b60c70`; pass all ten required preparation components,
  generated-content freshness, production dependency audit, and web build.
- [x] Build the immutable worker image in Cloud Build
  `59ccbd5f-2a83-4cbe-8b99-c446e2f519d0` and pass the strict exact-image
  36,000-tick benchmark at one CPU / 512 MiB.
- [x] Pause issuance and inspect the drain. Verify and conditionally cancel
  exactly six unsubmitted old-version tickets; retain their records and all
  330 accepted validations and settled grants.
- [x] Deploy 25 non-issuer Functions, Firestore rules/indexes, worker revision
  `replay-validator-00056-qnw`, six boards, and Hosting. Verify the live worker
  digest and web bytes against prepared artifacts.
- [x] Resume both queues and issuance. Verify all 26 Functions ACTIVE, worker
  and issuer serving 100%, all six boards present, zero active sessions, and
  no pending or quarantined settlement.
- [ ] Complete controlled signed-in Play Games issuance, accepted replay,
  once-only settlement, wallet catch-up, leaderboard/ghost and retired-version
  smoke, plus target-device performance checks.

## Deployed release: 2026.10.16

The owner authorized the coordinated release of the updated authored Field
and Forest content and shared `2026.10.16` gameplay compatibility. The owner
requested removal of tests tied to authored gap changes instead of changing
those chunks, approved the required release checks, and authorized cancelling
unsubmitted runs when needed for cutover. The removed traversal, streaming and
terrain-order cases are documented as coverage limits in the
[release verification](../verification/game-compat-2026.10.16-production.md).

- [x] Freeze `709c9d42`, prepare and verify all ten required components, 1,474
  Flutter tests, 2,241 Core tests, generated-content freshness, and the
  production web artifact.
- [x] Build the 93,050-graph worker image and pass the strict exact-image
  benchmark in Cloud Build `017dd2a8-c129-4e3b-be56-d4b78db81b67`.
- [x] Pause issuance, verify zero pending/quarantined settlement, and cancel
  exactly 15 guarded unsubmitted `2026.10.12` tickets. Preserve all 318
  accepted validations and settled grants; do not reset data.
- [x] Deploy Functions, Firestore rules/indexes, worker revision
  `replay-validator-00055-795`, six new-version boards, and Hosting. Verify
  live worker digest and web bytes against the prepared artifacts.
- [x] Restore both queues and normal issuance. Verify all 26 Functions ACTIVE,
  healthy issuer revision `runsessioncreate-00062-wbd` serving 100% without
  the pause gate, worker serving 100%, no active sessions, and no pending or
  quarantined settlement.
- [ ] Complete controlled signed-in Play Games issuance, accepted replay,
  once-only settlement, wallet catch-up, leaderboard/ghost and retired-version
  smoke, plus target-device performance checks.

## Deployed release: 2026.10.12

The owner authorized deployment of Forest revision 389 on October 12, 2026,
requested focused validation and accepted traversal failures for this release.
The nine distinct hard Rocky Grove chunks after Goddess become the repeating
final section. Gameplay compatibility changes together across client, Functions
and worker; rules-v2, score-v4, ghost-v1 and replay/command format 1 remain.

The owner repaired the Forest exit landing, preserving all nine distinct chunks.
Field now uses one early chunk and seven distinct easy chunks with all ground
boundaries and its spawn reference at 224. Content generation admits 87 chunks
and all three levels. Regenerated client/Core terrain includes the saved prefab
and encounter authoring.

Preparation completed in frozen commit `77525d31` at October 12 21:16:57 UTC.
The focused client, Core, Functions and validator checks, shared-package suites,
production audit, web build and generated-content freshness passed. Seed-42
traversal diagnostics passed Forest Grojib and Field Unoco; Field Grojib, Hashash
and Derf still stall in `field_default_easy_007`. These are owner-waived failures,
not passing evidence. See [release verification](../verification/game-compat-2026.10.12-production.md)
for exact test scope and omitted suites.

The 21:04:40 UTC read-only inventory observed 226 accepted validations with settled
rewards and four issued `2026.10.11.1` tickets. The owner approved cancelling
only the four reviewed unsubmitted tickets after a fresh paused-state recheck.
The four approved tickets were cancelled at 22:16:13 UTC after that recheck.
All 226 accepted runs and settled rewards were preserved. Issuance and both queues
are restored; the final inventory has zero active runs or unsettled rewards.

- [x] Regenerate runtime content and align matching source and route seeds.
- [x] Freeze the release snapshot.
- [x] Run focused content, route, compatibility and replay checks in a detached
  release recipe; report omitted suites and traversal failures separately.
- [x] Build the production web client.
- [x] Build the 93,600-graph worker image and pass all nine strict benchmark gates;
  Cloud Build `1068079f-4923-413b-95e2-c051aa7bf0b2` succeeded.
- [x] Pause issuance, recheck/cancel only the four authorized unsubmitted tickets,
  drain, deploy matching artifacts and boards, verify live readiness, and restore
  both queues and issuance.
- [x] Record immutable artifacts and final live results: 26 ACTIVE Functions,
  both queues RUNNING, all six boards ready, healthy worker/issuer traffic and
  matching live web bytes.
- [ ] Complete controlled signed-in gameplay/replay/settlement/ghost smoke.

## Deployed release: 2026.10.11.1

Prepared navigation, curated Practice routes, app-owned reward completion,
current Forest authoring and the bootstrap recovery repair are deployed with
`rules-v2`, `score-v4`, `ghost-v1` and format 1.

- [x] Freeze `6ac2a73a`; validate the repaired client and all required components.
  Record exactly two owner-accepted traversal exclusions in the detached recipe;
  retain the normal recipe on main and keep both failures unresolved.
- [x] Build the final 60,620-graph worker pack and pass all nine strict image gates.
- [x] Pause issuance, recheck the outstanding ticket and cancel one unsubmitted
  old-version run under owner authorization. Preserve all 204 settled runs/rewards.
- [x] Deploy Functions, worker and Hosting; verify six boards and matching live
  artifacts, restore both queues and issuance, and save the production baseline.
- [x] Verify 26 ACTIVE Functions, healthy worker/issuer revisions serving 100%,
  no issuer pause override and zero active runs or pending/quarantined settlement.
- [ ] Complete linked Play Games gameplay/replay/settlement, background wallet
  catch-up, leaderboard/ghost and live retired-version smoke. Browser startup
  still reports its pre-existing unsupported-services message; no native package
  was installed. Device and latency measurements remain in the
  [rollout plan](reward_verification_latency.md).

## Deployed release: 2026.10.11

The latest combat, boss, Forest progression, terrain preparation and run-startup
changes are deployed with `rules-v2`, `score-v4`, `ghost-v1` and format 1.
The owner authorized deployment and cancellation when necessary.

- [x] Align stale release regressions with current authored content and combat
  contracts, and freeze `90d1becc` without changing production gameplay.
- [x] Pass coordinated preparation, current dependency audit, generated freshness
  and the release web build. Retry the Core runner's temporary-directory cleanup
  failure successfully; preserve the failed attempt separately.
- [x] Build the immutable worker and pass all nine strict benchmark gates.
- [x] Pause issuance through the documented missing-image rebuild; verify zero
  active runs and settled rewards. No cancellations or resets were needed.
- [x] Deploy Functions, worker and Hosting; verify all six boards and exact live
  web bytes, restore both queues and matching issuance, and save the baseline.
- [x] Verify all 26 Functions ACTIVE, healthy worker/issuer revisions serving 100%,
  issuer pause gate absent, and all 199 accepted runs/rewards preserved.
- [x] Confirm the release-mode guard disables actor/projectile/trap debug overlays.
- [ ] Complete linked Play Games gameplay/replay/settlement/leaderboard/ghost and
  live retired-version smoke. Browser automation reached the same existing
  unsupported-services startup error before and after publishing; no native
  package was built or installed. Keep this checklist active.

## Deployed release: 2026.10.10

Compatibility `2026.10.10` corrects beam-piece alignment, adds
Goddess's upper-corner hand barrage, and allows separate visible swings/pulses
to hit again. The owner authorized commit/deploy and cancellation when necessary.

- [x] Inspect the actual sprite frames and both live/ghost effect rendering paths.
- [x] Verify sequential hands in the real Forest room at 30/60/90 Hz, independent
  strike windows, cancellation/replacement/death and recycled-entity cleanup.
- [x] Pass coordinated release preparation and the strict immutable-image benchmark.
- [x] Pause issuance; transactionally cancel the two reviewed unsubmitted old-version
  tickets without changing profiles, validated runs or rewards.
- [x] Deploy Functions, worker and Hosting; verify all six boards and exact web
  artifact bytes, restore both queues and matching issuance, and save the baseline.
- [x] Verify healthy worker/issuer revisions serving 100%, with the issuer pause
  gate absent, zero active sessions and all 199 accepted runs/rewards preserved.
- [ ] Complete linked Play Games gameplay/replay/settlement/leaderboard/ghost and
  live retired-version smoke. Browser automation was unavailable; no native package
  was installed. See the current production evidence for limits.

## Deployed release: 2026.10.9

The release includes the [Bringer tuning](../gdd/bringer_of_death.md):
1.5x boss/column size, faster attacks, 20% faster pursuit and 20% resource
restoration from easy-chunk victory blessings.
The death column's bottom and damage now anchor to the captured floor/platform.
This release also includes the independent Voidborn Goddess, Shoggoth and
Voidcaller implementations, their owned summons, and the video-audited diagonal
beam/spin collision corrections. Three new easy Forest chunks place Goddess,
Shoggoth and Voidcaller immediately after Bringer, before the enchanted forest.
The owner authorized the release and
cancellation of active runs if necessary on October 7. See
[boss audit and release evidence](../verification/ancient-god-bosses-2026-10-07.md).
- [x] Audit the video, separate each boss's content/AI, correct beam/spin geometry,
  and validate all four consecutive authored arenas with both characters.
- [x] Freeze `8b0062d4`; pass client/Core/Functions/worker/shared-package checks,
  current dependency audit, generated freshness and the production web build.
- [x] Build and strictly benchmark the immutable worker image at one CPU / 512 MiB.
- [x] Pause issuance; cancel two unsubmitted tickets and one expired empty upload
  under owner authorization. Preserve all 196 validated runs and settled grants.
- [x] Deploy Functions, worker and Hosting; verify six boards and exact live web
  bytes; restore queues and matching issuance at 20:52 UTC on October 7.
- [x] Record production evidence and the verified baseline.
- [ ] Complete linked Play Games gameplay/replay/settlement/leaderboard/ghost and
  live retired-version smoke. The browser's existing `_Namespace` service-startup
  error persists; no native package was installed by this release.

## Deployed release: 2026.10.8

The mandatory Forest boss, purple entrance with shared black vignette/shake/haptic
feedback, grounded attacks with shared 112-unit knockback, fixed boss scoring,
and the Dames de la forêt 60% victory resource restore are deployed.
That release's 80-chunk runtime catalog preserves the newer authoring from 2026.10.7.
The ranked partition is now `score-v4`; replay/command and ghost formats remain 1.

- [x] Merge the feature into master, preserve newer authoring/release fixes and
  regenerate the current catalog. All 139 focused boss/traversal checks pass.
- [x] Freeze corrected source and pass required client/backend/shared checks;
  reuse only matching successful validator evidence. Build the release web artifact.
- [x] Build and benchmark the exact immutable worker image at one CPU / 512 MiB.
- [x] Pause issuance and verify the drain. Zero active sessions; all 191 grants
  settled. No cancellation or remote data reset was necessary.
- [x] Deploy matching Functions/worker/Hosting, verify all six boards, worker
  digest/traffic and live web bytes, then restore both queues and matching issuer.
- [x] Record live production evidence and the verified baseline.
- [x] Remove the merged feature branch and all 17 obsolete clean, merged
  worktrees after live verification, retaining checksum-verified release evidence.
- [ ] Complete linked Play Games production gameplay/replay/settlement/ghost
  and live retired-version smoke. The pre-existing browser bootstrap limitation
  remains unverified; no native package was installed by this release.

See [production evidence](../verification/forest_boss_arena.md#production-release-2026108)
for frozen source, immutable artifacts, actual stage times and verification limits.

## Deployed release: 2026.10.7

Derf now keeps explosions in its normal stationary caster phase, transforms on
first body visibility, then pursues with tentacle melee only. The same entity,
health and terrain capsule survive transformation. Source compatibility is
updated in the deployed client, Functions and replay worker.
See [Derf contracts](../tdd/derf_transformation.md).

This source also includes the expanded Forest hard assembly, easy boss-themed
terrain chunk, revised hard collision/spawns/traps/rescue placements, and removal
of two hard ruin chunks. The authored sources and generated level, chunk and
terrain artifacts belong in the same client/worker preparation. See
[level composition](../gdd/level_composition.md) and
[the Core content contract](../tdd/runner_core_simulation_contract.md#authored-content-and-generated-outputs).

- [x] Regenerate the 80-chunk catalog and confirm dry-run freshness. All 85
  traversal/control checks pass: seeds 7, 42 and 2026 across all four enemies,
  complete Forest assemblies of 108, 108 and 104 chunks, and 32-chunk Field/New
  Level prefixes. Retain the exact obstacle/foothold regression routes. These
  pursuit checks exclude authored spawns, combat, player, camera and rendering
  acceptance; see [traversal scope](../../.agent/workflows/test-level-traversal.md).
- [x] Resolve the production dependency audit blockers: pin Express's
  [`proxy-addr`](https://github.com/advisories/GHSA-jqcg-44mw-7w3h) to `2.0.8`
  and Firebase Admin's
  [`@fastify/busboy`](https://github.com/advisories/GHSA-gxm5-99cw-xjw9) to `3.2.2`.
  The regenerated lockfile passes supply-chain policies and the October 6
  production dependency audit reports no known vulnerabilities. Full release
  preparation passed against this dependency revision. The deployed Functions
  manifest also mirrors the workspace security overrides and pins the four
  production SDK versions to the tested baseline. An isolated cloud-style npm
  production resolution confirms both patched versions and reports zero known
  vulnerabilities; see [dependency ownership](../tdd/firebase_cloud_functions_overview.md).
- [x] Repair the Windows authored-trap compilation budget. This check compiles
  three isolated real-worker fixtures, and its five-minute timeout triggered
  fixture teardown while a compiler still needed its package configuration.
  Windows now allows 15 minutes; other platforms retain five. All three trap
  assertions passed the isolated recheck in 201 seconds. The strict final-image
  throughput gate is unchanged. The encounter compiler fixture has the same
  Windows allowance (six minutes versus the usual two); its immutable-roster,
  reward and excluded-source checks passed the isolated recheck in 65 seconds.
  The final pinned backend also passes all 212 emulator tests and its build.
- [x] Align the encounter preflight regression with grounded Derf: valid
  ground placement now succeeds, while a Derf body extending beyond the chunk
  still rejects the complete group. The focused encounter-source suite passes.
  Preparation also passes 1,102 client tests, 928 Core tests, 44 protocol tests,
  81 content-pipeline tests, 25 terrain-material tests, generated freshness and
  the web build. Matching cached validator evidence includes 188 tests and the
  compiled AOT protocol-rejection probe.
- [x] Prepare and benchmark matching client/worker/backend artifacts. Backend
  valid-request fixtures now use the exported current compatibility; retired
  `2026.10.6` remains explicitly rejected. The first frozen preparation exposed
  these stale fixtures before any production mutation.
- [x] Owner authorized coordinated production deployment on October 6, 2026.
  Owner also authorized cancellation of active runs if necessary.
  Unsubmitted-ticket and replay/reward evidence was rechecked before applying it.
- [x] Pause issuance and drain validation/settlement. Three unsubmitted
  `2026.10.6` tickets were cancelled atomically with records retained. No profile,
  reward or validated-run data was reset.
- [x] Deploy matching Functions, worker and Hosting; verify the live web hash,
  Ready worker and all six boards; restore both queues and matching issuance.
- [x] Record production evidence and the verified baseline.
- [ ] Complete linked Play Games issuance, replay, settlement, leaderboard,
  ghost and live retired-version smoke.

The strict exact-image benchmark passed all nine gates. The clean cutover
inventory had zero active sessions and all 187 grants settled. The verified
baseline was saved at `2026-10-06T22:02:38.7071214Z` (October 7 in Helsinki).
The final inventory later observed two accepted new-version validations with
settled rewards and one issued new-version ticket; ordinary traffic was retained.
This passive evidence does not complete the controlled signed-in smoke above.
No native package was built or installed. The earlier browser file-I/O bootstrap
limitation remains; this release verified live bundle identity, not browser play.

## Deployed release: 2026.10.6

This revision prevents coins and restoration gems from spawning where their
margin-expanded footprint overlaps authored non-collidable terrain. It retains
`rules-v2`, `score-v3`, `ghost-v1`, and replay/command format 1, but changes
deterministic pickup placement and therefore requires a coordinated cutover.
It also includes [combat pose alignment](../tdd/combat_pose_geometry.md): fitted
body/attack/projectile geometry, shared pose clocks, and delayed visible Derf
impact damage. Frozen preparation and the strict exact-image benchmark passed;
matching Functions, worker, web artifacts, and all six boards are deployed.
Both queues and issuance are restored. No runs required cancellation.

- [x] Freeze and prepare the source, including the full replay-validator gate
  and strict exact-image benchmark.
- [x] Pause issuance, drain active validation/settlement, and inspect the live
  baseline before cutover.
- [x] Deploy matching Functions, worker, web client, and `2026.10.6` boards;
  restore issuance after board/artifact readiness and local compatibility gates.
- [x] Record production evidence and the verified baseline.
- [ ] Complete signed-in gameplay, replay,
  settlement, leaderboard, and ghost smoke.
- [ ] Confirm live retired-version rejection with a linked Play Games account.

The web build now includes its public App Check key and live attestation passed.
Fresh browser service initialization still fails on unsupported file I/O
(`_Namespace`); browser gameplay and signed-in service bootstrap are unverified.
No native package was built or installed in this release.

## Deployed release: 2026.10.4

Source now gives the Forest blessing +0.10 health, mana, and stamina per second
and labels it “Bénédiction des Dames de la forêt”. Client, Functions defaults,
and worker use `2026.10.4` because the prior health and mana rates replay
differently. The coordinated cutover is complete.

The release also includes 37-HP allied NPCs, the nine-chunk Forest
hard finale and current authored layouts, startup/ghost-loading improvements,
regenerated runtime content, and the patched backend multipart dependency.
The owner authorized repairs and deployment on October 3. The repaired frozen
source passed preparation and the exact-image benchmark. Six unsubmitted
`2026.10.3` tickets were cancelled with separate owner authorization and their
records retained. No rewards, validated runs or profiles were reset.

- [x] Repair release blockers, regenerate content and validate the frozen source.
- [x] Build and strictly benchmark the exact worker image.
- [x] Pause issuance, complete the approved cancellation and verify drain.
- [x] Deploy Functions/worker/web, verify all six boards and live artifacts,
  then restore both queues and issuance.
- [x] Record the verified production baseline and release evidence.
- [ ] Complete linked Play Games gameplay/replay/settlement/ghost and
  retired-version smoke below.

## Client maintenance: ghost cache filenames

The October 3 [ghost cache release](../verification/ghost-cache-client-2026-10-03.md)
published frozen `8d7d9bdc` through the verified Hosting scope and installed the
fixed debug APK on the connected Android phone under compatibility `2026.10.3`.

- [x] Focused ghost regressions, full 876-test client gate, and production web build.
- [x] Verify the live baseline, publish Hosting, and verify the new live artifact.
- [x] Install the fixed Android app while retaining account and app data.
- [x] Verify the Forest Competitive ghost opens and renders on the unlocked phone,
  including a second launch reusing the saved replay.

No run cancellations or server cutover were needed. This maintenance release
does not complete the broader signed-in smoke below.

## Deployed release: 2026.10.3

Authorized October 3, 2026 (Helsinki time). Scope includes Huntress
throw/stab/slash combat, furthest-progress distance at 25 world units per
metre with ranked `score-v3`, and regeneration shrines. Gameplay compatibility
is `2026.10.3`; rules/ghost and replay/command formats remain unchanged.

- [x] Validate/build one frozen source snapshot and benchmark its exact image.
- [x] Pause issuance, verify a drained read-only inventory, deploy matching
  Functions/worker/web, and restore issuance after board/artifact readiness.
- [x] Record immutable artifacts and live verification; retain existing data.
- [ ] Complete linked Play Games gameplay/replay/settlement/ghost and
  retired-version smoke.

The owner authorized cancellation of two issued `2026.10.1` sessions to
complete the cutover. Neither had an upload, validated replay, or reward grant.
Their records were preserved with conditional terminal writes. The final
inventory showed zero active sessions, all 177 grants settled, six expected
boards, and both queues RUNNING. See the
[production evidence](../verification/game-compat-2026.10.3-production.md).

## Deployed release: 2026.10.1

The preceding `2026.09.10` commit includes the 20% reduction in camera
auto-scroll targets and early Forest prefab/layout refinement. Later
projectile auto aim and authored content edits were excluded from that
deployment at the owner's instruction to ignore ongoing edits. This cutover
includes those previously excluded deterministic changes and the latest
Forest geometry.

Authorized October 2, 2026. Scope includes projectile auto aim, the six new
Forest grove chunks and subsequent layout/prefab collision refinements.
Regenerated Core chunk patterns and staged terrain include all 60 chunks.
Rules/score/ghost versions and replay/command formats remain unchanged.

- [x] Validate/build one frozen source snapshot and benchmark its exact image.
- [x] Pause issuance, verify a drained read-only inventory, deploy matching
  Functions/worker/web, and restore issuance after board/artifact readiness.
- [x] Record immutable artifacts and live verification; retain existing data.
- [ ] Complete linked Play Games gameplay/replay/settlement/ghost smoke.

The owner authorized cancellation of six issued `2026.09.10` sessions to
complete the cutover. They had no upload, validated replay or reward grant.
The records were preserved with conditional terminal writes; no player data,
rewards or replay artifacts were reset. The final inventory showed zero active
sessions, all 176 grants settled, six expected boards, and both queues RUNNING.
See the [production evidence](../verification/game-compat-2026.10.1-production.md).

## Deployed release: 2026.09.10 at 6bfda4c8

Use the [deployment workflow](../tdd/deployment_workflow.md) and its
[agent checklist](../../.agent/workflows/deploy-release.md).
The earlier owner's omission of tests/benchmarks applies only to the historical
2026.09.9 deployment below; it does not waive the current release gates.

- [x] Prepare matching source, frozen dependencies, fresh generated content and
  successful client/Functions/shared-package/validator checks.
- [x] Build and benchmark the immutable release worker image.
- [x] Pause normal ticket issuance and complete the drain/cancellation review.
- [x] Deploy Functions repair/settlement surfaces and READY indexes, private
  invocation permissions, matching worker/queues and web artifacts.
- [x] Verify current/next boards and published worker/web identity, then restore
  queues and matching ticket issuance.
- [ ] Complete the linked Play Games and retired-version smoke checks below,
  then append their outcomes to the current release evidence.

## Pre-cutover read-only production inspection: October 1, 2026

The release Inspect action completed against rpg-runner-d7add at
2026-10-01T18:38:03.955Z. All 26 Functions reported ACTIVE; validation and
projection queues reported RUNNING. The ready worker remained
replay-validator-00042-g9g with 100% traffic and immutable image digest
sha256:e2716e59c3db8bb6577b917ab12769b0a9b2faf38d5779afcc6b76f152717aa7,
matching the September 25 deployment evidence.

The inventory contained 194 terminal run sessions, 170 accepted validations and
170 settled reward grants; no active runs, stale pending settlements or
quarantined settlements were reported. Current-source 2026.09.10 boards were
not provisioned (all six expected current/next boards absent). This snapshot
does not complete the current release or its signed-in gameplay smoke.
No production changes were performed during that inspection.

## Historical production evidence: 2026.09.9

The historical matching release is gameplay `2026.09.9`, rules `rules-v2`, score `score-v2`,
ghost `ghost-v1`, replay/command format 1. It includes the earlier Forest
navigation and Poison Darts changes, plus grounded melee combat holding on
direct walk routes and the final allied health tuning: Warrior 20 HP, Huntress
13 HP, Huntress 2 9 HP (12 less than the preceding 32/25/21 values).
These combat changes affect replay outcomes and are included in
the deployed build; client and worker use the same Core. The follow-up
`2026.09.9` release removes ten Forest enemy placements. The owner requested
this content deployment without tests or benchmarks; none were run.
The release includes the current authored Forest geometry, traps, markers and
assembly, regenerated with the Field rescue content (54 chunks, three levels).
Client issuance, generated content,
Functions board/ticket defaults and replay worker must agree. The new worker
does not run historical Core versions.

- [x] Pause old ticket issuance and inspect unfinished runs. None required cancellation.
- [x] Verify validation/settlement are drained. No reset was necessary; historical
  sessions, settled grants and artifacts were preserved.
- [x] Build the matching immutable worker image. Further benchmarks, including
  the exact-image container run, were explicitly stopped by the owner. This is
  a release-specific exception, not a passing performance result.
- [x] Deploy matching generated content, worker, Functions and client. Remove
  stale supported-version environment overrides. Use the existing validator
  [deployment procedure](../../services/replay_validator/README.md).
- [x] Restore issuance and both queues; provision all six current/next boards.
- [ ] With a linked Play Games account, smoke-test fresh tickets, Practice and
  ranked rescue scoring, uploaded replay acceptance, once-only settlement,
  leaderboard totals and generation-pinned ghost playback.
- [ ] Confirm live retired gameplay/score tickets are rejected and archive this
  checklist with the deployment evidence. Local compatibility tests pass; the
  anonymous live smoke account was rejected by the existing identity gate and
  deleted without creating a run.

Cancellation/reset replaces old-run migration or a ticket-lifetime wait for this
pre-live cutover. Historical production replay support is not claimed. Existing
accepted artifacts retain their digest and generation lineage; no remote data
reset is authorized merely by this checklist.
