# Run-Start Latency Optimization — Implementation Checklist

Date: March 18, 2026  
Status: Phase 5 implemented (Phase 0 backend percentile capture still pending)  
Source plan: [docs/building/optimizeStartRun/plan.md](docs/building/optimizeStartRun/plan.md)

This checklist converts the run-start optimization plan into an execution order
with explicit done criteria and validation gates.

## Definition of done

- Play tap transitions immediately to run bootstrap/loading UI
- run ticket prefetch is bounded, safe, consume-once, and key-validated
- run start remains strict for restart preconditions
- ownership sync gate fast-path skips unnecessary work only when safe
- backend `runSessionCreate` tail latency (`p95/p99`) improves measurably
- callable contracts remain backward-compatible with current Flutter adapters
- no determinism/auth/authority regressions

## Locked constraints and invariants

Do not relax these without updating the plan in the same PR:

- no backend callable contract change for run start
- no gameplay determinism behavior change
- restart flows stay strict (no relaxed precondition behavior)
- prefetch cache stays bounded in-memory only
- prefetched ticket reuse requires full key match + expiry safety check
- no ticket payload logging in diagnostics

## Locked implementation order

1. Baseline + observability scaffolding
2. Client prefetch cache core
3. Client run-start fast path + invalidation rules
4. Ownership sync fast no-op gate
5. Route-first transition UX
6. Backend run-session latency optimizations
7. Tests and rollout verification

Do not start a later step until previous step done criteria are met.

---

## Phase 0 — Pre-flight baseline

Objective:

- establish measurable baseline before changes

Tasks:

- [x] Re-read plan and confirm constants/guardrails:
	- [x] [docs/building/optimizeStartRun/plan.md](docs/building/optimizeStartRun/plan.md)
- [x] Capture baseline timings (dev/staging):
	- [x] Play tap -> first navigation feedback
	- [x] Play tap -> `prepareRunStartDescriptor(...)` completed
	- [x] Play tap -> first rendered run frame
- [ ] Capture backend baseline for `runSessionCreate`:
	- [ ] `p50`
	- [ ] `p95`
	- [ ] `p99`
- [x] Confirm repo starts green before edits:
	- [x] `dart analyze` (no errors; 7 info-level lints)
	- [x] relevant `flutter test` slices
	- [x] `corepack pnpm --dir functions build`
	- [x] `corepack pnpm --dir functions test`

Done when:

- [ ] baseline metrics documented
- [x] green baseline recorded

Execution notes (2026-03-18):

- `dart analyze`: completed; no errors, 7 info-level diagnostics.
- `flutter test test/ui/state`: passed (`+100`, all tests passed).
- `flutter test test/ui/pages`: passed (`+46`, all tests passed).
- `flutter test test/ui`: passed (`+226`, all tests passed).
- `corepack pnpm --dir functions build`: passed.
- `corepack pnpm --dir functions test`: passed (`97/97`).
- Backend tooling warning observed (non-blocking for baseline run):
  unsupported engine (`node 20` requested, `node v24.12.0` active).
- Manual start-timing baseline (user-provided):
	- cold start: `8-10s`
	- warm/otherwise: `3-6s`

Remaining to finish Phase 0:

- capture backend `runSessionCreate` percentile baseline (`p50/p95/p99`)

---

## Phase 1 — Client prefetch primitives in AppState

Objective:

- add safe bounded ticket prefetch model without changing run-start behavior yet

Tasks:

- [x] Add prefetch key model in [lib/ui/state/app_state.dart](lib/ui/state/app_state.dart):
	- [x] `userId`
	- [x] `ownershipRevision`
	- [x] `gameCompatVersion`
	- [x] `mode`
	- [x] `levelId`
	- [x] `playerCharacterId`
	- [x] `loadoutDigest`
- [x] Add bounded cache structures:
	- [x] `Map<RunTicketPrefetchKey, RunTicket>`
	- [x] in-flight dedupe map
	- [x] LRU eviction metadata
- [x] Enforce defaults:
	- [x] max entries = `4`
	- [x] expiry skew = `5000ms`
- [x] Add prefetch APIs:
	- [x] `startRunTicketPrefetchForCurrentSelection()`
	- [x] `startRunTicketPrefetchFor({required RunMode mode, required LevelId levelId})`
- [x] Add per-key request minimum interval/rate limit
- [x] Add dedupe/stale-result-drop behavior

Done when:

- [x] prefetch requests can run in background safely
- [x] cache stays bounded and memory-stable under churn

Execution notes (2026-03-18):

- Added prefetch key/cache primitives and bounded LRU in `AppState`.
- Added auth/canonical/reset cache invalidation hooks.
- Added prefetch tests in [test/ui/state/app_state_run_ticket_prefetch_test.dart](test/ui/state/app_state_run_ticket_prefetch_test.dart):
	- concurrent dedupe
	- request budget suppression
	- weekly level normalization
	- unconfigured API no-op
- Validation:
	- `dart analyze lib/ui/state/app_state.dart test/ui/state/app_state_run_ticket_prefetch_test.dart` (clean)
	- `flutter test test/ui/state/app_state_run_ticket_prefetch_test.dart` (pass)
	- `flutter test test/ui/state/app_state_hybrid_sync_test.dart` (pass)

---

## Phase 2 — Client run-start fast path + invalidation

Objective:

- consume prefetched ticket when valid, fallback safely when not

Tasks:

- [x] Update `prepareRunStartDescriptor(...)` in [lib/ui/state/app_state.dart](lib/ui/state/app_state.dart):
	- [x] resolve canonical/effective mode+level
	- [x] compute prefetch key
	- [x] consume cached ticket on full validation pass
	- [x] fallback to `_runSessionApi.createRunSession(...)` on miss
- [x] Implement consume-once semantics
- [x] Implement hard validation checks:
	- [x] full key match
	- [x] not near expiry
	- [x] same authenticated `userId`
	- [x] no ghost/flow incompatibility
- [x] Implement invalidation triggers:
	- [x] auth transition
	- [x] canonical apply
	- [x] account deletion/reset
	- [x] local selection/loadout mutation (v1 clear-all)
- [x] Keep restart path strict remote in v1

Done when:

- [x] hot-path start uses cache when safe
- [x] all mismatches cleanly fallback to remote fetch
- [x] restart behavior unchanged

Execution notes (2026-03-18):

- `prepareRunStartDescriptor(...)` now attempts prefetched ticket consume first
  (except restart path), then falls back to remote create.
- Added consume-once ticket take path with strict validation:
	- full key match (user/mode/level/character/game-compat/loadout-digest)
	- expiry safety skew check
	- drop invalid/expired entries and fetch remote
- Added local mutation invalidation for optimistic selection/loadout edits.
- Added run-start prefetch consumption tests in
  [test/ui/state/app_state_run_ticket_prefetch_test.dart](test/ui/state/app_state_run_ticket_prefetch_test.dart):
	- exact-match cache reuse
	- consume-once remote fallback on second start
	- expired ticket remote fallback
	- key mismatch remote fallback
	- restart path strict remote bypass
- Validation:
	- `dart analyze lib/ui/state/app_state.dart test/ui/state/app_state_run_ticket_prefetch_test.dart test/ui/state/app_state_loadout_mask_test.dart` (clean)
	- `flutter test test/ui/state/app_state_run_ticket_prefetch_test.dart` (pass)
	- `flutter test test/ui/state/app_state_loadout_mask_test.dart` (pass)
	- `flutter test test/ui/state/app_state_hybrid_sync_test.dart` (pass)

---

## Phase 3 — Ownership sync fast no-op gate

Objective:

- avoid unnecessary pre-run sync latency when already clean

Tasks:

- [x] Update ownership run-start gating in [lib/ui/state/app_state.dart](lib/ui/state/app_state.dart):
	- [x] if no active flush and pending outbox count is known-zero, return immediately
	- [x] otherwise keep existing flush + refresh + failed-precondition logic
- [x] Add stale/unknown-state guard (no fast-return when state freshness is unknown)
- [x] Keep fail-closed behavior when pending writes remain

Done when:

- [x] clean state path no longer performs avoidable sync work
- [x] pending-write path still throws failed-precondition correctly

Execution notes (2026-03-18):

- Added run-start sync fast-path guard in `AppState`:
	- returns immediately only when status is known-clean and fresh
	- falls back to existing flush+refresh path otherwise
- Added freshness tracking and max-age bound for outbox status visibility.
- Added unknown-state invalidation on auth/session transitions.
- Added tests in [test/ui/state/app_state_hybrid_sync_test.dart](test/ui/state/app_state_hybrid_sync_test.dart):
	- fresh known-clean status skips extra flush/read path
	- unknown status still executes full sync path
	- existing fail-closed pending-write test remains passing
- Validation:
	- `dart analyze lib/ui/state/app_state.dart test/ui/state/app_state_hybrid_sync_test.dart` (clean)
	- `flutter test test/ui/state/app_state_hybrid_sync_test.dart` (pass)
	- `flutter test test/ui/state/app_state_run_ticket_prefetch_test.dart` (pass)

---

## Phase 4 — Route-first transition for perceived speed

Objective:

- provide immediate feedback after Play tap while preserving preconditions

Tasks:

- [x] Change hub start flow in [lib/ui/pages/hub/play_hub_page.dart](lib/ui/pages/hub/play_hub_page.dart):
	- [x] navigate immediately to bootstrap/loading route
	- [x] stop waiting on hub for descriptor fetch
- [x] Implement bootstrap route behavior in run route/widget path:
	- [x] call `prepareRunStartDescriptor(...)` within bootstrap route
	- [x] mount `RunnerGameWidget` on success
	- [x] show retry + return-to-hub affordances on failure
- [x] Keep existing error semantics/messages aligned with precondition failures

Done when:

- [x] Play tap always gives immediate route transition feedback
- [x] run-start failures are recoverable (retry/back)

Execution notes (2026-03-18):

- Added route-first bootstrap route and args in [lib/ui/app/ui_routes.dart](lib/ui/app/ui_routes.dart).
- Added run bootstrap page in [lib/ui/pages/hub/run_start_bootstrap_page.dart](lib/ui/pages/hub/run_start_bootstrap_page.dart):
	- immediate loading state
	- async descriptor prep via `AppState`
	- replacement navigation to run route on success
	- retry + back affordances on failure
- Wired route handling in [lib/ui/app/ui_router.dart](lib/ui/app/ui_router.dart).
- Updated hub start flow in [lib/ui/pages/hub/play_hub_page.dart](lib/ui/pages/hub/play_hub_page.dart) to navigate to bootstrap route.
- Updated Select Level Play flow in [lib/ui/pages/selectLevel/level_setup_page.dart](lib/ui/pages/selectLevel/level_setup_page.dart) to navigate to bootstrap route after draft flush.
- Added route/widget tests in [test/ui/pages/hub/run_start_bootstrap_page_test.dart](test/ui/pages/hub/run_start_bootstrap_page_test.dart):
	- successful bootstrap transitions to run route
	- failure path shows retry and retry re-attempts run-start prep
- Validation:
	- `dart analyze lib/ui/app/ui_router.dart lib/ui/app/ui_routes.dart lib/ui/pages/hub/play_hub_page.dart lib/ui/pages/hub/run_start_bootstrap_page.dart test/ui/pages/hub/play_hub_page_test.dart test/ui/pages/hub/run_start_bootstrap_page_test.dart` (clean)
	- `flutter test test/ui/pages/hub/play_hub_page_test.dart` (pass)
	- `flutter test test/ui/pages/hub/run_start_bootstrap_page_test.dart` (pass)

---

## Phase 5 — Warmup integration

Objective:

- trigger prefetch predictably from hub-time warmup

Tasks:

- [x] Extend `startWarmup()` in [lib/ui/state/app_state.dart](lib/ui/state/app_state.dart):
	- [x] prefetch current selection
	- [x] optionally prefetch weekly featured combination
- [x] Keep warmup trigger in [lib/ui/pages/hub/play_hub_page.dart](lib/ui/pages/hub/play_hub_page.dart)
- [x] Ensure warmup is idempotent (no duplicate flood)

Done when:

- [x] warmup prefetch occurs once per warmup session
- [x] rapid selection changes do not spam network calls

Execution notes (2026-03-18):

- Extended `startWarmup()` to trigger:
	- prefetch for current selected mode/level combo
	- additional weekly featured combo prefetch when current mode is not weekly
- Warmup remains single-shot per session via existing `_warmupStarted` guard.
- Added tests in [test/ui/state/app_state_run_ticket_prefetch_test.dart](test/ui/state/app_state_run_ticket_prefetch_test.dart):
	- warmup triggers both current + weekly prefetch
	- repeated warmup calls remain idempotent
- Validation:
	- `dart analyze lib/ui/state/app_state.dart test/ui/state/app_state_run_ticket_prefetch_test.dart` (clean)
	- `flutter test test/ui/state/app_state_run_ticket_prefetch_test.dart` (pass)

---

## Phase 6 — Backend runSessionCreate latency work

Objective:

- reduce tail latency while preserving contract and validation invariants

Tasks:

- [x] Tune callable runtime in [functions/src/index.ts](functions/src/index.ts):
	- [x] explicit region alignment
	- [x] `minInstances`
	- [x] memory/CPU tuning only with profiling evidence
- [x] Optimize board read path:
	- [x] [functions/src/boards/store.ts](functions/src/boards/store.ts)
	- [x] [functions/src/boards/provisioning.ts](functions/src/boards/provisioning.ts)
	- [x] preserve status/window/version checks
- [x] Implement ranked create-session fast path in [functions/src/runs/store.ts](functions/src/runs/store.ts):
	- [x] load manifest first
	- [x] ensure/provision only on not-found
	- [x] single retry load after ensure
- [x] Slim run session write payload in [functions/src/runs/submission_store.ts](functions/src/runs/submission_store.ts)
	- [x] keep only downstream-required fields
	- [x] keep callable response unchanged
- [x] Add step timings + structured summaries in [functions/src/runs/store.ts](functions/src/runs/store.ts)

Done when:

- [x] backend functional behavior unchanged
- [ ] measurable tail-latency reduction is observed

Execution notes (2026-03-18):

- `runSessionCreate` callable now has explicit runtime options in
  [functions/src/index.ts](functions/src/index.ts):
	- region from `RUN_SESSION_CREATE_REGION`/`FUNCTIONS_REGION` (fallback `us-central1`)
	- `minInstances` from `RUN_SESSION_CREATE_MIN_INSTANCES` when set
- Active board lookup in [functions/src/boards/store.ts](functions/src/boards/store.ts)
  now performs deterministic managed-doc lookup first, then compatibility
  fallback query.
- Ranked run creation in [functions/src/runs/store.ts](functions/src/runs/store.ts)
  now follows load-first semantics:
	- load active manifest first
	- provision only on explicit missing-board condition
	- single manifest retry after ensure
- `run_sessions` writes in [functions/src/runs/store.ts](functions/src/runs/store.ts)
  are slimmed to required fields (no embedded `runTicket`).
- [functions/src/runs/submission_store.ts](functions/src/runs/submission_store.ts)
  now reads board context from top-level `boardId`/`boardKey` with legacy
  `runTicket` fallback for compatibility.
- Added bounded timing logs (`runSessionCreate_timing`) in
  [functions/src/runs/store.ts](functions/src/runs/store.ts):
	- canonical load
	- board resolve/provision
	- run-session write
	- total duration

---

## Phase 7 — Tests

Objective:

- prove safety, correctness, and latency-facing behavior

### Client tests

- [x] Add/extend tests under [test/ui/state](test/ui/state):
	- [x] cached ticket reused on exact key match
	- [x] expired ticket falls back to remote
	- [x] key mismatch falls back to remote
	- [x] consume-once prevents second reuse
	- [x] invalidation on canonical/auth drift
	- [x] in-flight dedupe prevents duplicate calls
	- [x] LRU eviction enforces max entries
	- [x] restart path does not consume prefetched ticket
	- [ ] stale in-flight completion is dropped
	- [x] ownership sync fast-path immediate return on known-zero pending
	- [x] pending writes still fail closed
- [x] Add/extend route/widget tests (not state-only) for route-first behavior:
	- [x] immediate navigation feedback after Play tap
	- [x] descriptor failure shows retry/back UX
	- [x] retry path succeeds without stale state

### Backend tests

- [x] ranked `createRunSession` hot path with existing board
- [x] ensure-on-miss success path when board absent
- [x] deterministic board reads preserve validations
- [x] slimmed run-session document does not break finalize/status flows
- [x] callable contract payload unchanged for `runSessionCreate`

Done when:

- [ ] all targeted tests pass
- [x] no contract or invariant regressions

Execution notes (2026-03-18):

- Client validation run:
	- `flutter test test/ui/state/app_state_run_ticket_prefetch_test.dart test/ui/state/app_state_hybrid_sync_test.dart test/ui/pages/hub/run_start_bootstrap_page_test.dart test/ui/pages/hub/play_hub_page_test.dart` (pass)
	- Added extra client assertions:
		- canonical/auth invalidation coverage
		- LRU bounded cache eviction coverage
		- immediate Play-tap bootstrap navigation coverage
- Backend validation run:
	- `corepack pnpm --dir functions test` (pass, `98/98`)
- Known non-blocking environment warning:
	- functions workspace requests Node `20`; active runtime was `v24.12.0`.

Remaining in Phase 7:

- add deterministic stale in-flight completion drop test coverage (tracked as pending).

---

## Phase 8 — Validation and rollout

Objective:

- validate gains and ship safely in phases

Tasks:

- [ ] Compare before/after latency metrics:
	- [ ] Play tap -> loading route (median)
	- [ ] Play tap -> run-ready (median)
	- [ ] backend `runSessionCreate` `p50/p95/p99`
- [ ] Rollout phases:
	- [ ] Phase 1: prefetch + sync fast-path + diagnostics
	- [ ] Phase 2: route-first UX
	- [ ] Phase 3: backend latency changes
- [ ] Add rollback notes per phase:
	- [ ] disable route-first path (fallback to current flow)
	- [ ] disable prefetch consumption (remote-only run start)
	- [ ] rollback backend runtime knobs/fast-path if tail regresses

Done when:

- [ ] acceptance criteria are met in staging
- [ ] rollout/rollback procedure is documented and tested

Execution notes (2026-03-18):

- Backend sampled timing capture (emulator test run, post-change only):
	- command: `corepack pnpm --dir functions test`
	- extracted `runSessionCreate_timing.totalMs` samples: `n=14`
	- sampled percentiles: `p50=86ms`, `p95=258ms`, `p99=258ms`
	- sampled range: `min=46ms`, `max=258ms`
- This is not a before/after comparison yet; baseline percentile capture from
  pre-change backend run is still required to complete Phase 8 latency
  comparison criteria.

---

## Verification commands

- [ ] `dart analyze lib/ui test`
- [ ] `flutter test test/ui/state`
- [ ] `flutter test test/ui/pages`
- [ ] `flutter test test/ui`
- [ ] `corepack pnpm --dir functions build`
- [x] `corepack pnpm --dir functions test`

## Final acceptance checklist

- [ ] immediate Play-tap transition feedback is present
- [ ] strict run-start safety rules remain intact
- [ ] no expired/mismatched ticket reuse
- [ ] cache boundedness confirmed under stress
- [ ] sync fast no-op only triggers under safe known-zero conditions
- [ ] backend tail latency improved (`p95/p99`)
- [ ] contracts remain backward compatible
