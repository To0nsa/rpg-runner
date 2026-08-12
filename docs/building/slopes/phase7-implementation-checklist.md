# Slopes Phase 7 - Compatibility Rollout And Production Verification Checklist

- Status: Production rollout active; session drain complete and 24-hour cutoff
  guard in progress
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

The release drill's normal `prepare` command intentionally remains subject to
the linked Google Play Games callable policy. For an automated production
validator canary, `prepare-admin` is an explicit operator-only mode: it creates
a disposable anonymous Auth identity, writes only isolated canonical/profile
shells and protocol fixtures through operator credentials, and binds the
competitive fixture to the one active current-version board. It does not mint
or impersonate a Play Games identity and therefore does not claim to test that
callable authentication boundary. Cleanup uses the deployed resumable account
deletion worker, including board scans, late-write detection, final passes,
Auth deletion, and an independent zero-residue verifier. Its deletion request
is backdated past the quiet period only because the operator mode never issues
a signed upload grant and uploads immutable fixture bytes directly.

The removal audit is repeatable and fail-closed:

```powershell
corepack pnpm --dir functions build
node functions/tool/production_inventory.mjs `
  --project rpg-runner-d7add `
  --retiring-game-compat 2026.03.0 `
  --issuance-cutoff-at 2026-08-12T14:32:29Z
```

Its `compatibilityRetirement.readyForRemoval` result becomes true only after
the full 24-hour lifetime, with zero active sessions and no observed retired
ticket issued after the recorded cutoff. Any unassessable issuance timestamp
or unknown session state/compatibility value also blocks removal.

Once that gate is true, retirement remains an ordered deployment rather than
one combined mutation:

1. Change the Functions default issuance allowlist to current-only, run the
   full Functions suite, deploy the four compatibility-aware callables, and
   prove old practice/ranked issuance rejects while current issuance succeeds.
2. Rerun the readiness inventory after the Functions deployment. Any matching
   ticket issued after the recorded cutoff invalidates the cutoff and stops the
   sequence even if no session is currently active.
3. Disable only the `2026.03.0` board partition with update-time
   preconditions. Do not delete board documents, player bests, top views,
   manifests, or ghost objects. Re-inventory to prove all six current boards
   remain active and the 37 old boards retain their descendants.
4. Remove old acceptance from validator source, run its full suite, build and
   benchmark the exact immutable image, then deploy that digest. Verify health,
   current acceptance, retired-version rejection, settlement/projection
   idempotency, empty queues, and the full integrity inventory.

Functions must lead validator removal: otherwise an old client could receive a
ticket that the newly narrowed validator rejects. Board disabling follows the
issuance stop so lookup and document status agree throughout the cutover.

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

- [x] local analyzers and relevant Flutter/Core/protocol/editor/Functions/
      validator tests pass
- [x] generated content dry-run reports zero drift
- [x] exact release-container benchmark passes at one CPU and 512 MiB
- [x] staging/live Core and validator results match the accepted golden runs
- [x] no unsupported ticket can be issued or validated
- [x] old and new same-window boards coexist without lookup ambiguity
- [x] rewards, leaderboard order, and ghost publication are idempotent and
      partitioned by board/version
- [x] old-version active-session count reaches zero after the recorded cutoff
- [ ] collision/navigation/validator latency and rejection metrics remain
      inside the accepted budgets
- [x] rollback artifacts and commands are verified before old support removal

## 6) Progress Evidence

| Date / revision | Slice | Result |
| --- | --- | --- |
| 2026-08-12 / Phase 7 working head | Compatibility inventory | Phase 6 is accepted locally. Inventory found that managed board IDs and provisioning uniqueness omitted compatibility versions, so an old same-window board could block new-board creation. Practice issuance also accepted arbitrary client compatibility strings until validator rejection. The local cutover therefore starts by partitioning board identity and enforcing a bounded backend allowlist before any deployment. |
| 2026-08-12 / Phase 7 working head | Local dual-version implementation | The client and board default advance to `2026.08.0`; Functions centrally allow current plus draining `2026.03.0`, reject other practice/ranked and active-board requests, provision the requested supported partition, and bind managed IDs to the full version tuple. The validator accepts both labels through one current Core path. Same-window lookup/provisioning and both acceptance/rejection directions are covered; all 188 Functions emulator tests, all 85 validator tests, and 41 focused client tests pass. The release-image workflow now runs the strict benchmark with one CPU and 512 MiB. |
| 2026-08-12 14:15 UTC / pre-deployment production | Read-only compatibility baseline | Production has 37 legacy-ID boards, all `2026.03.0`: three current, three upcoming, and 31 expired. It has 37 sessions: 21 validated, nine expired, and seven uploading; all use `2026.03.0`, so old validator support must remain. All 21 grants are settled, two player bests/two ghosts are source-valid, and no stale settlement, terminal-evidence, loadout, identity, or board-window issuance mismatch is present. The two historical validated sessions missing immutable board-window fields both match their canonical board and predate the hardened contract. Current/next `2026.08.0` board count is zero of six before rollout. |
| 2026-08-12 14:19 UTC / `af8a17d7` | Constrained release-container benchmark | Cloud Build `f78781b4-574c-4baa-9761-0876d2d832c8` produced immutable digest `sha256:93dff13c…35f989`. Cloud Run Job execution `replay-validator-phase7-benchmark-577zw` ran that exact digest with one CPU, 512 MiB, no retries, and the strict 36,000-tick gate. Field completed in 0.408197 seconds (1,469.88x real time) and Forest in 0.658831 seconds (910.70x); both ended at geometry version 190 with their deterministic outcomes and every strict gate true. |
| 2026-08-12 14:22-14:32 UTC / `af8a17d7` + `e4237e95` | Ordered production cutover | Dual-compatible validator revision `replay-validator-00031-pds` was deployed first. Firestore indexes and the four version-aware Functions then deployed as `runsessioncreate-00015-nup`, `runboardsloadactive-00013-dop`, `leaderboardloadactiveboarddata-00014-nul`, and `leaderboardboardmaintenance-00010-hiy`. Maintenance created all six current/next `2026.08.0` boards with zero identity/window mismatch while preserving 37 old boards. Flutter web initially exposed a JavaScript exact-integer portability failure in the pathfinder sentinel; `e4237e95` replaced it with the maximum JS-safe value without changing reachable navigation scores, passed focused Core tests and the release web build, and Hosting version `91b3cd82f4a00884` went live at 14:32:29 UTC. The served `main.dart.js` hash exactly matched the local release bundle and contains `2026.08.0`. |
| 2026-08-12 14:37-14:42 UTC / `d552240e` | Exact client/Core validator parity | Cloud Build `14bd359c-239c-46ec-a4e0-b822cd85b19e` rebuilt the validator after the JS-safe Core correction as digest `sha256:6f32cf5b…272d9`. Job execution `replay-validator-phase7-benchmark-zfwp5` ran that exact digest at one CPU/512 MiB: Field 0.395722 seconds (1,516.22x), Forest 0.572208 seconds (1,048.57x), geometry version 190, deterministic results, and every strict gate true. Revision `replay-validator-00032-x4p` now serves 100%; `/live` and `/ready` return 200 and its configured image is the exact digest. |
| 2026-08-12 / `d552240e` | Full local release matrix | Root, Core package, protocol, and editor analyzers are clean. All 742 root Flutter tests, 370 Core-package tests, 44 protocol tests, 377 editor tests, 188 Functions emulator tests, and 85 replay-validator tests pass. The real generator dry-run validates eight Chunks, two levels, and two parallax themes with zero drift; the release web build also passes. |
| 2026-08-12 15:07-15:31 UTC / production `replay-validator-00032-x4p` | Current-version compatibility and projection canary | The operator-only disposable drill prepared 16 isolated fixtures and exercised all nine compatibility cases against the private live service. `2026.08.0` was accepted with HTTP 202, settled to `validated_settled`, became the current-board player best, published an active ghost, and appeared in the materialized top view. A repeated validation returned HTTP 202 with the same session, grant, best source, and ghost digest. Retired game compatibility was rejected as `game_compat_version_unsupported`; ticket identity/loadout, retired board versions, board binding, and board-window failures all reached their exact terminal reasons with revoked grants. The deployed deletion worker detected a late projection, performed an additional final pass, deleted Auth, and the independent verifier found zero residual Firestore or Storage data for the successful canary and both failed pre-fixture bootstrap attempts. |
| 2026-08-12 15:33 UTC / post-canary production | Drain and integrity inventory | Production returned to 37 sessions, 21 grants, two player bests, and two ghosts; all source/identity/window/loadout/terminal/settlement/projection integrity counters remain zero. The six `2026.08.0` boards coexist with 37 old boards without ambiguity. One old uploading ticket expired during the rollout, leaving six active `2026.03.0` uploading sessions, so draining support remains mandatory. All 13 retained deletion records are compact and complete with no active/retryable deletion. Three pre-existing old-version projection tasks still retry and keep the monitoring acceptance item open while they are diagnosed. |
| 2026-08-12 15:41-15:49 UTC / `4658b75a` | Privacy-safe projection diagnosis | Cloud Build `9a145904-a921-4333-bb28-a16587f3b451` produced diagnostic digest `sha256:863c4a67…c021c`. Benchmark execution `replay-validator-phase7-benchmark-qhvb5` passed every strict gate at geometry version 190 (Field 0.536386 seconds/1,118.60x; Forest 0.735220 seconds/816.08x), and revision `replay-validator-00033-5zs` served it at 100% with 200 health probes. A controlled retry then classified the pre-existing failure as `leaderboard_DetailedApiRequestError_http_409` after the Firestore 20-second deadline without logging provider messages or document/object identities. Inspection found that the idempotent unchanged-player-best branch returned from a pessimistic transaction without rollback, retaining the exact player-best lock needed by the following top-view refresh. |
| 2026-08-12 15:52-15:57 UTC / `cb25d333` | Leaderboard transaction fix and production drain | Unchanged player-best comparisons now explicitly roll back, and deletion-fence setup failures best-effort roll back before preserving their original error. Validator analysis and all 87 tests pass, including an HTTP-level regression proving the no-write rollback request. Cloud Build `e3dbe8c8-c99e-4bdc-93c3-89115f42c2c4` produced digest `sha256:a1d30a07…db86`; benchmark execution `replay-validator-phase7-benchmark-p8879` passed at geometry version 190 (Field 0.469540 seconds/1,277.85x; Forest 0.626631 seconds/957.50x). Revision `replay-validator-00034-tmg` serves that exact digest at 100% with `/live` and `/ready` both 200. The three formerly stuck projections completed sequentially with HTTP 200 in 1.169, 0.905, and 0.653 seconds and were deleted by Cloud Tasks; both projection and validation queues are empty. |
| 2026-08-12 15:58-16:03 UTC / post-fix production | Integrity and reconciliation audit | The read-only inventory remains at 43 valid boards, 37 sessions, 21 settled grants, two source-valid player bests, and two source-valid ghost manifests. All identity, issuance-window, loadout, terminal-evidence, settlement, and projection-source error counters are zero; all 13 deletion requests remain compact/complete with no active or retryable deletion. Six old `2026.03.0` uploading sessions remain active with valid expiries from 16:11:48 through 16:39:26 UTC, so removal is still blocked and the independent 24-hour cutoff guard remains 2026-08-13 14:32:29 UTC. The deployed scheduler first proved same-bucket task-key idempotency, then a fresh 16:00 cycle scanned and enqueued all 43 boards. All 43 emitted `projection_reconciliation/completed`, the queue drained to zero, and revision `00034-tmg` emitted no error-level records during the drain or audit. |
| 2026-08-12 16:06-16:16 UTC / initial production metric baseline | Latency, rejection, and alert observation | Since the 14:32:29 client cutoff, 259 completed board reconciliations have p50/p95/max latency of 186/548/869 ms, and four completed run projections have p50/p95/max of 905/1,169/1,169 ms. The accepted current-version canary reached its durable settlement handoff in 23.192 seconds and immediate settlement dispatch in 2.471 seconds. Its eight deliberate negative fixtures account exactly for the observed rejection mix. The six run-projection and two board-reconciliation retry metrics belong to the diagnosed pre-fix Firestore lock incident; the fixed revision has no retry or error-level record. All 14 replay/validator/settlement alert policies are enabled, no monitoring snooze is active, the normal 16:10 submission-cleanup schedule completed without scheduler status error, and the normal 16:15 projection cycle completed another 43/43 board reconciliations with an empty queue and zero fixed-revision errors. There is not yet an organic current-version run sample or a 24-hour observation interval, so the production-metrics acceptance item remains open. |
| 2026-08-12 16:12 UTC / compatibility drain | First old-session expiry | After the first audited ticket expiry, a manual invocation of the deployed submission-cleanup schedule expired exactly one session and reported no other cleanup/repair mutation or error. The inventory moved from six to five active old uploading sessions, retained zero past-expiry expirable sessions and zero integrity failures, and still observes no `2026.03.0` issuance after the client cutoff. The remaining valid expiries are 16:37:49-16:39:26 UTC; retirement remains blocked by both active sessions and the independent 24-hour interval. |
| 2026-08-12 16:15 UTC / retirement readiness guard | Fail-closed removal assessment | The optional inventory gate now delegates to a typed pure Functions rule. It requires a positive cutoff, the complete 24-hour interval, zero matching sessions in any non-terminal state, assessable issuance time for every matching session, and zero issuance after the recorded cutoff. Four focused elapsed/active/post-cutoff/malformed/ready tests and the full 192-test Functions emulator suite pass. The production adapter reproduces the five-session inventory and reports `readyForRemoval: false` with exactly `ticket_lifetime_not_elapsed` and `active_sessions_remain`. |
| 2026-08-12 16:20-16:22 UTC / `532e6dc7` + `5d11aba3` | Current-head collision/navigation budget | The strict 1,280-edge Windows benchmark passed every frozen gate from clean master heads: the normal run measured combined controller p95/p99 31/48 microseconds, candidate p95/p99 10/10, matched flat/slope full-harness p99 259/68 microseconds, -27.91% slope overhead, bounded contact/recovery iterations, and zero warmed buffer growth across 35,000 controller plus 20,000 harness samples. The isolated VM allocation run repeated all gates (controller p95/p99 35/56 microseconds, harness p99 235/74 microseconds) and two paired 10,000-iteration trials attributed zero steady-state hot-loop allocations. This refreshes local runtime evidence at the deployed client/Core head; the production observation interval remains open. |
| 2026-08-12 16:30-16:40 UTC / final session drain | Zero active old-version sessions | The normal 16:30 reconciliation cycle completed 43/43 with an empty queue and zero errors. After the audited maximum expiry, the deployed cleanup expired exactly the remaining five sessions and made no retention, orphan-repair, or Storage cleanup mutation. Production now has 16 expired and 21 validated sessions, zero active `2026.03.0` sessions, zero validation/projection tasks, no post-cutoff issuance, no malformed compatibility/state/time evidence, and no integrity or fixed-revision error counter. The readiness gate is still false for the sole expected blocker `ticket_lifetime_not_elapsed`; old support and all 37 old board statuses remain unchanged until 2026-08-13 14:32:29 UTC. |
| 2026-08-12 / pre-removal rollback inventory | Retained rollback points | Pre-rollout rollback artifacts remain available: validator `replay-validator-00030-r4j` at `sha256:47a93735…ff96805`; Functions `runsessioncreate-00014-mob`, `runboardsloadactive-00012-yir`, `leaderboardloadactiveboarddata-00013-nek`, and `leaderboardboardmaintenance-00009-dok`; Hosting version `75f7614e000153f1`; and the 14:15 UTC board/session inventory. Rollback routes traffic/releases to those retained artifacts, stops new-version issuance, and disables rather than deletes new boards while leaving the dual validator available for any already-issued `2026.08.0` ticket. |
