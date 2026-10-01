# Rescue release operations

Status: 2026.09.9 was deployed September 25, 2026; 2026.09.10 remains a source
release awaiting deployment evidence. Signed-in production gameplay smoke remains
outstanding. See the [initial rescue deployment](../archive/2026-09-25/verification/game-compat-2026.09.8-production.md)
and [current Forest content release](../archive/2026-09-25/verification/game-compat-2026.09.9-production.md).

The repository now targets gameplay `2026.09.10` for a 20% reduction in camera
auto-scroll targets and projectile auto aim that filters targets by travel reach
and terrain sightline, then predicts from the offset launch point. No
current-source deployment evidence is recorded. Its client, Functions,
worker and board versions must be cut over together after the existing run and
settlement drain steps; the completed `2026.09.9` steps below are historical
deployment evidence, not completion evidence for `2026.09.10`.

## Current source release: 2026.09.10

Use the [deployment workflow](../tdd/deployment_workflow.md) and its
[agent checklist](../../.agent/workflows/deploy-release.md).
The earlier owner's omission of tests/benchmarks applies only to the historical
2026.09.9 deployment below; it does not waive the current release gates.

- [ ] Prepare matching source, frozen dependencies, fresh generated content and
  successful client/Functions/shared-package/validator checks.
- [ ] Build and benchmark the immutable release worker image.
- [ ] Pause normal ticket issuance and complete the drain/cancellation review.
- [ ] Deploy Functions repair/settlement surfaces and READY indexes, private
  invocation permissions, matching worker/queues and web artifacts.
- [ ] Verify current/next boards and published worker/web identity, then restore
  queues and matching ticket issuance.
- [ ] Complete the linked Play Games and retired-version smoke checks below,
  then record current release evidence.

## Read-only production inspection: October 1, 2026

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
No production changes were performed.

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
