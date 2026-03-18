# Run-Start Latency Optimization Plan

## Objective

Reduce Play-tap latency (actual and perceived) while preserving backend authority,
deterministic gameplay guarantees, and strict restart preconditions.

## In Scope

### Client/UI scope

- Bounded run-ticket prefetch in [lib/ui/state/app_state.dart](../../../lib/ui/state/app_state.dart)
- Hub warmup integration in [lib/ui/pages/hub/play_hub_page.dart](../../../lib/ui/pages/hub/play_hub_page.dart)
- Route-first transition flow across:
  - [lib/ui/pages/hub/play_hub_page.dart](../../../lib/ui/pages/hub/play_hub_page.dart)
  - [lib/ui/runner_game_route.dart](../../../lib/ui/runner_game_route.dart)
  - [lib/ui/runner_game_widget.dart](../../../lib/ui/runner_game_widget.dart)
- Ownership sync fast no-op path in [lib/ui/state/app_state.dart](../../../lib/ui/state/app_state.dart)

### Backend scope

- Run ticket issuance latency optimizations in:
  - [functions/src/index.ts](../../../functions/src/index.ts)
  - [functions/src/boards/store.ts](../../../functions/src/boards/store.ts)
  - [functions/src/boards/provisioning.ts](../../../functions/src/boards/provisioning.ts)
  - [functions/src/runs/store.ts](../../../functions/src/runs/store.ts)
  - [functions/src/runs/submission_store.ts](../../../functions/src/runs/submission_store.ts)

## Non-Goals

- Prefetching every mode/level/loadout combination
- Long-lived ticket persistence across app restarts
- Relaxing restart precondition checks
- Changing callable contracts for run start
- Changing core gameplay determinism behavior

## Workstream A: Client-Side Run Start Optimization

### A1) Run Ticket Prefetch Cache Model

Implement bounded in-memory prefetch with consume-once semantics.

- `RunTicketPrefetchKey` fields:
  - `userId`
  - `ownershipRevision`
  - `gameCompatVersion`
  - `mode`
  - `levelId`
  - `playerCharacterId`
  - `loadoutDigest` (deterministic hash)
- `Map<RunTicketPrefetchKey, RunTicket>` for cache
- `Map<RunTicketPrefetchKey, Future<void>>` for in-flight dedupe
- LRU metadata for bounded eviction

Defaults:

- max entries: `4`
- expiry safety skew: `5000ms` (must satisfy `now + skew < expiresAtMs`)

Compatibility rule:

- key must include active `gameCompatVersion` to prevent cross-version reuse

### A2) Prefetch Entry Points

Add in `AppState`:

- `startRunTicketPrefetchForCurrentSelection()`
- `startRunTicketPrefetchFor({required RunMode mode, required LevelId levelId})`

Behavior:

- fire-and-forget
- normalize effective mode/level first (including weekly normalization)
- require ownership sync gate before ticket request
- no-op when unauthenticated or API unavailable
- per-key minimum interval to avoid selection-change spam

### A3) Run Start Fast Path

In `prepareRunStartDescriptor(...)`:

1. run existing ownership/auth/canonical checks
2. resolve canonical/effective `mode` + `levelId`
3. compute prefetch key
4. consume cached ticket if valid
5. fallback to `_runSessionApi.createRunSession(...)`

Consume-once rule:

- remove entry immediately when chosen for use

### A4) Ticket Validation and Invalidation

Reuse only when all are true:

- full key match with canonical state
- not near expiry
- same authenticated `userId`
- compatible with current run-start path (no ghost mismatch)

Otherwise:

- invalidate and fetch remotely

Invalidate cache/in-flight maps on:

- auth transition (`_ensureAuthSession()` changes)
- canonical apply (`_applyCanonicalState(...)`)
- account deletion/reset

Local selection/loadout mutation policy:

- v1: clear all (safe)
- v2: selective removal (optional)

### A5) Restart Policy

For restart (`expectedMode`/`expectedLevelId` set):

- keep strict remote path in v1 (skip prefetch consumption)
- document explicitly in code
- revisit only with dedicated restart tests

### A6) Route-First Transition (Perceived Latency)

Current flow waits for descriptor before route transition.

Adopt route-first flow:

- on Play tap, navigate immediately to lightweight run-bootstrap/loading route
- execute `prepareRunStartDescriptor(...)` inside bootstrap route
- mount `RunnerGameWidget` when descriptor resolves
- show retry + return-to-hub affordances on failure

Notes:

- no backend contract change
- no invariant relaxation
- improves perceived latency even if wall-clock is unchanged

### A7) Ownership Sync Fast No-Op

Keep existing correctness checks, but avoid unnecessary work when obviously clean.

- if no active flush and pending ownership outbox count is `0`, return immediately
- else run existing flush + refresh + failed-precondition path unchanged

Guardrails:

- do not skip when pending state is unknown
- do not weaken failed-precondition behavior
- keep restart semantics unchanged

### A8) Client Observability and Concurrency Safety

Diagnostics (debug/sampled telemetry):

- `prefetch_request`
- `prefetch_hit`
- `prefetch_miss_empty`
- `prefetch_miss_key_mismatch`
- `prefetch_miss_expired`
- `prefetch_miss_invalidated`

Rules:

- coarse key fields only (`mode`, `levelId`, reason)
- never log secrets/ticket payloads
- avoid unbounded production logs

Concurrency:

- dedupe concurrent prefetch per key
- drop stale in-flight completion after state drift
- keep cache mutation synchronous/minimal inside async paths

## Workstream B: Backend Run Ticket Latency Optimization

### B1) Cold-Start and Runtime Tuning

For `runSessionCreate` in [functions/src/index.ts](../../../functions/src/index.ts):

- explicit region alignment
- `minInstances` for lower cold-start probability
- tune memory/CPU only with profiling evidence

### B2) Board Read Path Optimization

Prefer deterministic board-id reads over broad scans:

- [functions/src/boards/store.ts](../../../functions/src/boards/store.ts)
- [functions/src/boards/provisioning.ts](../../../functions/src/boards/provisioning.ts)

Preserve status/window/version validation invariants.

### B3) Ranked Session Create Fast Path

In [functions/src/runs/store.ts](../../../functions/src/runs/store.ts):

1. call `loadActiveBoardManifest(...)`
2. run `ensureManagedBoardForModeLevel(...)` only on not-found
3. retry manifest load once after ensure

Goal: avoid provisioning writes on common hot path.

### B4) Run Session Document Slimming

Keep callable response unchanged (`runTicket` still returned), but reduce
`run_sessions` write payload to fields needed by finalize/status flows in
[functions/src/runs/submission_store.ts](../../../functions/src/runs/submission_store.ts).

### B5) Backend Observability and Verification

Add step timings in [functions/src/runs/store.ts](../../../functions/src/runs/store.ts):

- canonical load time
- board resolve/provision time
- run-session write time

Log structured summaries with bounded cardinality and compare baseline vs rollout
at `p50/p95/p99`.

## Integration Checklist

- Extend `startWarmup()` in [lib/ui/state/app_state.dart](../../../lib/ui/state/app_state.dart) with ticket prefetch
- Keep warmup trigger in [lib/ui/pages/hub/play_hub_page.dart](../../../lib/ui/pages/hub/play_hub_page.dart)
- Implement route-first transition across hub route + run route/widget
- Add ownership sync fast-path gate in `AppState`
- Validate backend + client contract compatibility in same change

## Test Plan

### Client tests (add/extend under [test/ui/state](../../../test/ui/state) and relevant UI tests)

1. reuses cached ticket on exact key match
2. expired ticket falls back to remote fetch
3. key mismatch falls back to remote fetch
4. consume-once prevents second reuse
5. cache clears on canonical apply/auth change
6. in-flight dedupe prevents duplicate remote calls per key
7. LRU eviction enforces max entries
8. restart path does not consume prefetched ticket
9. stale in-flight completion is discarded after auth/selection/canonical drift
10. route-first flow navigates immediately and still surfaces run-start errors
11. route-first failure supports retry and return-to-hub
12. ownership sync fast-path returns immediately when pending count is zero
13. ownership sync still throws failed-precondition when pending writes remain

### Backend tests

14. ranked `createRunSession` uses fast path when board exists
15. ensure-on-miss path succeeds when board is absent
16. deterministic board reads preserve status/window/version validation
17. run-session document slimming does not break finalize/status behavior
18. callable payload for `runSessionCreate` remains unchanged

## Acceptance Criteria

- Play tap commonly avoids waiting for fresh `createRunSession`
- Play tap provides immediate transition feedback (loading route)
- no behavior regressions across practice/competitive/weekly
- restart semantics remain strict and unchanged
- no reuse of expired/mismatched tickets
- cache remains bounded and memory-stable
- ownership sync gate avoids unnecessary latency when pending writes are zero
- backend `runSessionCreate` improves at `p95/p99` under representative load
- backend contract compatibility remains intact for current Flutter adapters

## Rollout

### Phase 1 (Client)

- ship prefetch + observability + sync fast no-op
- validate hit/miss ratio and miss reasons in dev/staging

### Phase 2 (Perceived latency)

- ship route-first transition with retry/return UX
- verify no regression in run-start failure handling

### Phase 3 (Backend)

- ship backend fast paths and runtime tuning
- compare `p50/p95/p99` before widening rollout

Tuning guidance:

- adjust cache size/skew only after measured data review
