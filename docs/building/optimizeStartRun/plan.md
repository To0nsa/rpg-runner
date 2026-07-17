# Run-Start Latency Optimization Plan

- Reviewed: July 16, 2026
- Status: Corrective implementation required; not accepted for rollout
- Execution tracker: [implementation-checklist.md](implementation-checklist.md)

## Purpose

Reduce actual and perceived Play-tap latency without weakening server authority,
ownership synchronization, deterministic gameplay, replay validation, or strict
restart preconditions.

This document is the authoritative target design. The checklist records what is
already implemented, what the July 2026 audit disproved, and what remains before
the work can be accepted.

## Audit outcome

The current implementation has a sound base:

- route-first navigation provides immediate Play-tap feedback
- run-ticket reuse is bounded, consume-once, expiry-checked, and key-checked
- restart flows bypass prefetched tickets
- the ownership gate has a safe known-clean fast path
- ranked board lookup uses a deterministic read before compatibility fallback
- ranked session creation provisions only on an explicit missing-board result
- authoritative run tickets are persisted for replay validation

The implementation is not complete because:

- production callables accept client-provided time and use it for authority
  decisions
- hub warmup requests a weekly ticket while canonical mode is not weekly, which
  the backend correctly rejects
- prefetch does not run through the ownership-sync gate
- cache invalidation has no generation token, so an older request can repopulate
  the cache after state cycles back to the same key
- the documented client prefetch diagnostics are absent
- the bootstrap error state has Retry but no explicit Return to Hub action
- blocking asset warmup scans global render catalogs instead of a bounded
  selection-specific set
- deployed cold-start configuration and before/after latency gains have not
  been demonstrated

## Locked design decisions

These decisions are required for the corrective implementation:

1. Server time is authoritative. User callable payloads cannot influence ticket
   issuance, board windows, expiry, upload leases, or finalize transitions.
2. Prefetch is only for the current canonical selection. Do not prefetch a
   speculative weekly, mode, level, character, or loadout combination.
3. Prefetched tickets are in-memory, bounded, consume-once, and never persisted
   across app restarts.
4. Every invalidation increments a generation token. An asynchronous result may
   be stored only if its captured generation is still current.
5. Restart always performs a fresh canonical read and remote session creation.
6. Route-first UX changes when feedback appears; it does not relax any
   precondition.
7. Blocking asset warmup is limited to assets required for the selected
   level/character's first useful frame.
8. No phase is complete based only on emulator timings. Rollout requires
   representative staging or production evidence.

Changing one of these decisions requires updating this plan and checklist in the
same change.

## Scope

### Client and UI

- run-start state and prefetch orchestration:
  - [app_state.dart](../../../lib/ui/state/app/app_state.dart)
  - [run_start_controller.dart](../../../lib/ui/state/app/controllers/run_start_controller.dart)
  - [ownership_sync_controller.dart](../../../lib/ui/state/app/controllers/ownership_sync_controller.dart)
  - [auth_profile_controller.dart](../../../lib/ui/state/app/controllers/auth_profile_controller.dart)
- route-first flow:
  - [play_hub_page.dart](../../../lib/ui/pages/hub/play_hub_page.dart)
  - [run_start_bootstrap_page.dart](../../../lib/ui/pages/hub/run_start_bootstrap_page.dart)
  - [ui_routes.dart](../../../lib/ui/app/ui_routes.dart)
  - [ui_router.dart](../../../lib/ui/app/ui_router.dart)
  - [runner_game_widget.dart](../../../lib/ui/runner_game_widget.dart)
- run-start asset preparation:
  - [ui_asset_lifecycle.dart](../../../lib/ui/assets/ui_asset_lifecycle.dart)

### Backend and shared contract

- callable configuration and input authority:
  - [index.ts](../../../functions/src/index.ts)
  - [callable_handlers.ts](../../../functions/src/runs/callable_handlers.ts)
  - [validators.ts](../../../functions/src/runs/validators.ts)
- run session, board, and upload/finalize authority:
  - [store.ts](../../../functions/src/runs/store.ts)
  - [submission_store.ts](../../../functions/src/runs/submission_store.ts)
  - [board store](../../../functions/src/boards/store.ts)
  - [board provisioning](../../../functions/src/boards/provisioning.ts)
- replay-validation compatibility:
  - [run_session_repository.dart](../../../services/replay_validator/lib/src/run_session_repository.dart)
  - [run_ticket.dart](../../../packages/run_protocol/lib/run_ticket.dart)

## Non-goals

- prefetching every selectable combination
- minting or reconstructing run tickets on the client
- long-lived ticket persistence
- reusing tickets for restart
- weakening ownership revision or failed-precondition behavior
- changing deterministic Core gameplay
- changing the normal Flutter request/response shape for run start
- tuning memory or CPU without measurements

Removing test-only time control from public callable payloads is security
hardening, not a product contract expansion. Tests should inject a clock into
internal functions instead.

## Workstream 0: Restore server-time authority

### 0.1 Public callable boundary

User-callable handlers must derive authority time from a server clock. Request
fields such as `nowMs` must not affect:

- active board/window resolution or provisioning
- `issuedAtMs` and `expiresAtMs` on a run ticket
- run-session timestamps
- upload-grant lease issuance or expiry
- upload finalization and run-session expiry transitions

The Flutter app does not send `nowMs`; its normal callable contract remains
unchanged.

### 0.2 Testability

Keep deterministic time control below the callable boundary:

- internal store/domain functions may accept an injected clock or explicit
  `nowMs`
- callable handlers always supply server time
- tests that exercise historical window boundaries call internal functions or
  inject a fake clock
- auth-gating tests prove a request-supplied `nowMs` is ignored or rejected

### 0.3 Authority acceptance

- a caller cannot create a future-dated ticket
- a caller cannot provision an arbitrary future board through a user callable
- a caller cannot extend a ticket or upload lease
- emulator tests cover create, upload-grant, and finalize boundaries

## Workstream A: Correct client prefetch

### A1. Cache identity and bounds

The cache key remains:

- `userId`
- `ownershipRevision`
- `gameCompatVersion`
- normalized `mode`
- normalized `levelId`
- `playerCharacterId`
- deterministic `loadoutDigest`

Required structures:

- ticket cache
- per-key in-flight dedupe
- LRU metadata
- per-key request budget metadata
- monotonic invalidation generation

Defaults remain:

- maximum cached tickets: `4`
- expiry safety skew: `5000ms`
- request minimum interval: `1500ms`

The ticket cache and its supporting metadata must remain bounded or be cleared
on invalidation.

### A2. Canonical-selection-only policy

`startRunTicketPrefetchForCurrentSelection()` is the supported entry point.

If a lower-level `startRunTicketPrefetchFor(...)` helper remains, it must
no-op unless the normalized requested mode/level exactly matches the current
selection after ownership synchronization.

Remove the additional weekly warmup request. The backend requires requested
mode and level to match canonical selection, so speculative weekly prefetch is
invalid by design.

### A3. Prefetch request sequence

For a current-selection prefetch:

1. no-op if the run-session API is unavailable
2. authenticate without surfacing background errors to the UI
3. pass the ownership-sync-before-run gate
4. snapshot user, revision, selection, character, loadout, compatibility
   version, and current invalidation generation
5. normalize weekly level
6. apply per-key request budgeting and in-flight dedupe
7. request the server-issued run ticket
8. validate the returned ticket against the captured key and expiry policy
9. store only when both the captured key and generation are still current

Background failure is allowed, but it must produce a bounded diagnostic reason.
Never cache a response that does not match the requested key.

### A4. Invalidation and stale completion

Invalidate on:

- auth user or auth session transition
- canonical ownership apply
- local selection or loadout mutation
- account reset/deletion
- AppState disposal

Invalidation must:

- increment the generation
- clear cached tickets
- clear in-flight ownership/dedupe references without treating old work as
  current
- clear LRU and request-budget metadata

An old request cannot become current merely because state changes A → B → A.

### A5. Consumption

`prepareRunStartDescriptor(...)` must:

1. enforce ownership synchronization
2. authenticate
3. perform the existing strict restart canonical read when expected mode/level
   is supplied
4. resolve canonical effective mode and level
5. consume and remove an exact valid ticket for ordinary starts
6. create a fresh remote run session on every miss
7. build the descriptor from the authoritative ticket
8. load ghost bootstrap only after board identity is known

Consume-once means the entry is removed before further asynchronous work.

### A6. Client diagnostics

Provide debug or sampled telemetry for:

- `prefetch_request`
- `prefetch_stored`
- `prefetch_hit`
- `prefetch_miss_empty`
- `prefetch_miss_expired`
- `prefetch_miss_key_mismatch`
- `prefetch_drop_generation`
- `prefetch_drop_ownership_not_clean`
- `prefetch_request_failed`

Only log bounded fields such as mode, level, and reason. Never log a ticket,
nonce, session identifier, auth token, loadout contents, or replay data.

## Workstream B: Route-first UX and asset preparation

### B1. Bootstrap route

On Play tap:

- navigate immediately to the run-bootstrap route
- prepare the run descriptor inside that route
- display loading feedback while backend and critical asset work proceeds
- replace the bootstrap route with the run route on success

### B2. Recoverable failure

The error state must expose two explicit actions:

- Retry: re-run descriptor preparation without stacking routes
- Return to Hub: pop or replace back to the hub safely

Platform back navigation may remain, but it is not the documented Return to Hub
affordance.

### B3. Bounded blocking asset warmup

Blocking warmup may include:

- selected level's first-frame parallax/theme assets
- selected character's first-frame animation assets
- any small, explicitly identified first-frame dependency

Do not block route entry on scanning every enemy, projectile, pickup, or spell
impact catalog. Non-critical assets should remain game-managed or warm
non-blockingly after the critical set is ready.

Measure both:

- Play tap → bootstrap feedback
- Play tap → first usable run frame

An immediate loading route alone does not prove actual latency improved.

## Workstream C: Ownership fast path

The existing fast path remains valid only when:

- no ownership flush is active
- status is not marked flushing
- pending count is known to be zero
- the status timestamp is present, monotonic, and within the freshness bound

Otherwise run the existing flush, refresh, and fail-closed pending-write path.
Prefetch and ordinary run start use the same correctness gate.

## Workstream D: Backend latency path

### D1. Board resolution

For ranked modes:

1. read the deterministic managed board document
2. use the compatibility query only when the managed document does not exist
3. validate status, mode, level, window, game compatibility, and board bounds
4. provision only on an explicit missing-board result
5. reload once after provisioning

### D2. Session persistence

Keep the callable response shape unchanged and persist the authoritative
`runTicket` in `run_sessions`. Preserve top-level board compatibility fields
used by finalize/status and the replay validator.

### D3. Runtime configuration

- keep Functions and Flutter region configuration aligned
- record the deployed `RUN_SESSION_CREATE_MIN_INSTANCES` value per environment
- treat an absent variable as no cold-start mitigation
- choose nonzero minimum instances only with an explicit cost owner
- tune CPU/memory only from profiling evidence

### D4. Backend observability

Keep bounded step timings for:

- canonical load
- board resolution/provisioning
- run-session write
- total duration

Capture success/failure outcome without logging ticket payloads. Compare
representative before/after `p50/p95/p99`; emulator samples are functional
evidence, not rollout latency evidence.

## Required tests

### Client state

1. exact ticket match is reused
2. ticket is consume-once
3. expired ticket falls back
4. ticket/key mismatch falls back
5. response mismatch is rejected before cache storage
6. concurrent request dedupe issues one backend call
7. LRU bounds all cache state
8. restart bypasses cache
9. auth/canonical/local mutation invalidates cache
10. A → B → A drift cannot revive an old completion
11. auth-session drift cannot revive an old completion
12. pending ownership edits prevent prefetch
13. warmup requests only the canonical current selection
14. no API/auth background cases remain no-op

### Widget and route

15. Play tap navigates immediately
16. success replaces bootstrap with run route
17. failure displays Retry and Return to Hub
18. retry does not stack routes or reuse stale state
19. Return to Hub reaches the hub
20. blocking warmup is limited to the selected critical asset set

### Backend and cross-layer

21. callable-supplied time cannot alter issued/expiry timestamps
22. callable-supplied time cannot select or provision a future board
23. upload-grant/finalize expiry uses server time
24. existing managed board uses the hot path
25. missing board provisions once and reloads once
26. board validation invariants remain enforced
27. run ticket is persisted and decoded by replay validation
28. callable response remains compatible with the Flutter adapter

## Acceptance criteria

### Authority and correctness

- no user-controlled clock affects authority decisions
- no expired, mismatched, invalidated, or stale-generation ticket is reused
- prefetch never runs against a noncanonical speculative selection
- restart behavior remains strict and remote
- ownership pending writes remain fail-closed
- replay validation can bind every new session to its issued ticket

### UX and performance

- Play tap provides immediate loading feedback
- bootstrap failure has visible Retry and Return to Hub actions
- current-selection prefetch has a measured useful hit rate
- blocking asset warmup does not scan global catalogs
- representative Play-to-run-ready latency does not regress
- backend `p95/p99` improves or an explicit decision records why the backend
  tuning is not being rolled out

### Quality

- cache and metadata remain bounded
- client and backend diagnostics are present and privacy-safe
- Flutter, Functions, protocol, and replay-validator validation passes
- deployment configuration and rollback steps are documented
- the checklist has no unchecked blocker before this folder is archived

## Rollout and rollback

Roll out independently:

1. server-time authority hardening
2. corrected current-selection prefetch and diagnostics
3. route error UX and bounded asset warmup
4. backend runtime configuration

Rollback controls:

- disable prefetch consumption and use remote-only ordinary starts
- retain route-first navigation while disabling optional asset warmup
- set minimum instances back to the previous deployed value
- retain server-time authority hardening; it is not a latency feature flag

Do not archive this plan until the acceptance section and the final checklist are
fully satisfied.
