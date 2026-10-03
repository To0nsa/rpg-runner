# Rescue release operations

Status: `2026.10.3` was deployed October 3, 2026 (Helsinki time) from frozen
commit `b5835b8e`; see [current production evidence](../verification/game-compat-2026.10.3-production.md).
Signed-in production gameplay smoke remains outstanding. Earlier releases:
[2026.10.1](../verification/game-compat-2026.10.1-production.md),
[2026.09.10](../verification/game-compat-2026.09.10-production.md),
[initial rescue deployment](../archive/2026-09-25/verification/game-compat-2026.09.8-production.md)
and [Forest spawn release](../archive/2026-09-25/verification/game-compat-2026.09.9-production.md).

## Client maintenance: ghost cache filenames

The October 3 [ghost cache release](../verification/ghost-cache-client-2026-10-03.md)
published frozen `8d7d9bdc` through the verified Hosting scope and installed the
fixed debug APK on the connected Android phone. Compatibility remains `2026.10.3`.

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
