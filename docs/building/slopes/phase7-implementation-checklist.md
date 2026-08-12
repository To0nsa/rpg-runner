# Slopes Phase 7 - Compatibility Rollout And Production Verification Checklist

- Status: Local compatibility preparation in progress
- Source plan: [plan.md](plan.md)
- Prerequisite: accepted
  [Phase 6 direct authority cutover](phase6-implementation-checklist.md)

## 1) Goal And Boundary

Issue the polygon-terrain runtime as game compatibility `2026.08.0`, preserve
already-issued `2026.03.0` sessions for one bounded drain interval, and prove
that boards, replay validation, rewards, leaderboards, and ghosts remain bound
to the exact compatibility tuple.

This checklist separates repository preparation from production mutation.
Local source, tests, deployment manifests, and operator commands may be
completed and committed autonomously. Deploying Functions, Firestore indexes,
Cloud Run, Hosting, or a client; provisioning live boards; changing live
environment variables; disabling boards; and deleting or repairing production
records require an explicit deployment decision and credentials. No live
mutation is authorized by this checklist alone.

The compatibility disposition is:

- `2026.08.0` is the only version newly issued by the updated client and the
  default managed-board provisioner.
- `2026.03.0` is accepted temporarily so tickets issued before the client and
  board cutover can finish. This is protocol compatibility only; there is no
  legacy terrain-authority path.
- `rules-v1`, `score-v1`, `ghost-v1`, replay format `1`, and command format `1`
  remain unchanged because their contracts did not change.
- the maximum run-ticket lifetime is 24 hours. Old-version validator support
  may be removed only after old issuance is stopped, at least 24 hours have
  elapsed, and the active-session audit described below is empty.

## 2) Repository Preparation

- [x] centralize the backend current and draining compatibility versions
- [x] reject unsupported versions before issuing both practice and ranked
      tickets
- [x] make managed board identity include ruleset, score, game compatibility,
      and ghost versions so same-window old/new boards can coexist
- [x] make ranked fallback provisioning use the requested supported game
      compatibility version
- [x] make active-board lookup select only the requested compatibility
      partition and reject ambiguity inside that partition
- [x] update the client default to `2026.08.0`
- [x] configure the validator to accept `2026.08.0` and draining `2026.03.0`
- [x] add same-window board coexistence, unsupported practice/ranked issuance,
      and dual validator acceptance coverage
- [x] add the strict replay benchmark to the release-image CI path under one
      CPU and 512 MiB
- [x] update rollout, protocol, validator, and operations documentation

## 3) Ordered Deployment Runbook

The safe production sequence is intentionally asymmetric:

1. Capture a pre-cutover baseline: deployed revisions and image digest,
   Functions/runtime configuration, active and next board manifests, active
   sessions grouped by `runTicket.gameCompatVersion` and state, validation
   rejection reasons, settlement backlog, leaderboard counts, and current
   ghost artifacts.
2. Build the exact release image and run its strict 36,000-tick Field/Forest
   benchmark with `--cpus=1 --memory=512m`. Record image digest, elapsed times,
   real-time multiples, final results, and geometry versions.
3. Deploy the dual-compatible validator first. It must accept both
   `2026.03.0` and `2026.08.0` while preserving the existing replay, ruleset,
   score, and ghost versions. Verify health and an old-version canary before
   allowing new issuance.
4. Deploy version-partitioned Functions and any required indexes/configuration.
   Keep the supported issuance set at `2026.08.0,2026.03.0`, with
   `2026.08.0` as the managed-board default.
5. Provision and inspect current and next `2026.08.0` competitive/weekly
   boards. Confirm old and new boards have different IDs, exact tuple fields,
   deterministic seeds, windows, levels, and active statuses.
6. Deploy the matching client/content build. Record the old-issuance cutoff
   time and verify new practice, competitive, and weekly tickets all carry
   `2026.08.0` and bind to new-version boards where applicable.
7. Run end-to-end canaries for replay acceptance, reward settlement,
   leaderboard projection, and ghost publication. Compare live results with
   local/staging golden runs and verify retries remain idempotent.
8. Monitor for at least the 24-hour ticket lifetime. Do not remove old support
   while any old-version session remains in `issued`, `uploading`, `uploaded`,
   `pending_validation`, `validating`, or `settlement_pending`.
9. After the interval, audit old sessions and repair or resolve any legitimate
   queue/settlement backlog. Disable old boards only when no new old-version
   entry can be accepted. Preserve their leaderboard and ghost history.
10. Remove `2026.03.0` from backend issuance and validator acceptance in a
    separate reviewed commit/deployment, then prove a stable unsupported-version
    rejection and repeat the projection/monitoring checks.

## 4) Rollback Contract

Before new issuance starts, retain the previous client artifact, Functions
revision/configuration, validator image digest, and board inventory. If parity,
settlement, leaderboard, ghost, or performance gates fail:

1. stop `2026.08.0` issuance by rolling the client/backend configuration back;
2. disable new-version boards without deleting them or their projections;
3. keep the dual-compatible validator available for already-issued tickets;
4. drain or explicitly resolve those tickets before removing validator support;
5. preserve replay objects, run sessions, settlement records, leaderboard
   entries, ghosts, logs, and image digests as investigation evidence.

Rollback must never switch Core back to rectangle terrain or rewrite an
existing ticket/board compatibility tuple.

## 5) Acceptance Evidence

- [ ] local analyzers and relevant Flutter/Core/protocol/editor/Functions/
      validator tests pass
- [ ] generated content dry-run reports zero drift
- [ ] exact release-container benchmark passes at one CPU and 512 MiB
- [ ] staging/live Core and validator results match the accepted golden runs
- [ ] no unsupported ticket can be issued or validated
- [ ] old and new same-window boards coexist without lookup ambiguity
- [ ] rewards, leaderboard order, and ghost publication are idempotent and
      partitioned by board/version
- [ ] old-version active-session count reaches zero after the recorded cutoff
- [ ] collision/navigation/validator latency and rejection metrics remain
      inside the accepted budgets
- [ ] rollback artifacts and commands are verified before old support removal

## 6) Progress Evidence

| Date / revision | Slice | Result |
| --- | --- | --- |
| 2026-08-12 / Phase 7 working head | Compatibility inventory | Phase 6 is accepted locally. Inventory found that managed board IDs and provisioning uniqueness omitted compatibility versions, so an old same-window board could block new-board creation. Practice issuance also accepted arbitrary client compatibility strings until validator rejection. The local cutover therefore starts by partitioning board identity and enforcing a bounded backend allowlist before any deployment. |
| 2026-08-12 / Phase 7 working head | Local dual-version implementation | The client and board default advance to `2026.08.0`; Functions centrally allow current plus draining `2026.03.0`, reject other practice/ranked and active-board requests, provision the requested supported partition, and bind managed IDs to the full version tuple. The validator accepts both labels through one current Core path. Same-window lookup/provisioning and both acceptance/rejection directions are covered; all 188 Functions emulator tests, all 85 validator tests, and 41 focused client tests pass. The release-image workflow now runs the strict benchmark with one CPU and 512 MiB. |
| 2026-08-12 14:15 UTC / pre-deployment production | Read-only compatibility baseline | Production has 37 legacy-ID boards, all `2026.03.0`: three current, three upcoming, and 31 expired. It has 37 sessions: 21 validated, nine expired, and seven uploading; all use `2026.03.0`, so old validator support must remain. All 21 grants are settled, two player bests/two ghosts are source-valid, and no stale settlement, terminal-evidence, loadout, identity, or board-window issuance mismatch is present. The two historical validated sessions missing immutable board-window fields both match their canonical board and predate the hardened contract. Current/next `2026.08.0` board count is zero of six before rollout. |
