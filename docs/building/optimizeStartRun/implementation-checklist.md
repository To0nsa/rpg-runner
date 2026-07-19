# Run-Start Latency Optimization — Implementation Checklist

- Originally implemented: March 18, 2026
- Corrective audit: July 16, 2026
- Status: Authority fix production verified; latency corrective work remains
- Authoritative design: [plan.md](plan.md)

## How to use this checklist

- `[x]` means the current implementation and available evidence satisfy the
  item.
- `[ ]` means required work or verification remains.
- Historical passes are evidence for that revision only; they do not override a
  later failing or blocked validation run.
- A phase is complete only when every task and done condition in that phase is
  checked.

## Current audit summary

| Area | Current state | Decision |
| --- | --- | --- |
| Route-first Play feedback | Implemented | Keep |
| Consume-once bounded ticket cache | Implemented | Keep and harden |
| Strict restart path | Implemented | Keep |
| Ownership known-clean fast path | Implemented | Keep |
| Speculative weekly prefetch | Rejected by backend canonical-mode check | Remove |
| Prefetch ownership gate | Missing | Add |
| Stale async result rejection | Key-only; no generation protection | Add generation |
| Client prefetch diagnostics | Missing | Add |
| Bootstrap Return to Hub action | Missing | Add |
| Blocking asset warmup | Global catalog scan | Bound to critical selected assets |
| Server-time authority | Fixed, deployed, and production verified | Preserve |
| Board/session backend fast path | Implemented and tested | Keep |
| Persisted authoritative `runTicket` | Implemented and cross-layer tested | Keep |
| `minInstances` | Optional environment hook only | Record deployed value |
| Latency improvement | No representative before/after comparison | Measure |

## Locked completion order

1. Restore server-time authority.
2. Correct prefetch eligibility, ownership gating, and stale-result handling.
3. Complete route failure UX and bound blocking asset warmup.
4. Verify deployed runtime configuration and representative latency.
5. Run the final cross-layer validation gate.
6. Complete rollout/rollback evidence, then archive.

Do not skip authority or correctness work to continue performance rollout.

---

## Phase 0 — Restore server-time authority

Objective:

- ensure user callable payloads cannot influence authoritative time

Implementation:

- [x] Stop reading request `nowMs` as authority in
  [run validators](../../../functions/src/runs/validators.ts).
- [x] Ensure
  [run callable handlers](../../../functions/src/runs/callable_handlers.ts)
  supply server time to internal functions.
- [x] Apply the same rule to board resolution/provisioning callables involved in
  run start.
- [x] Ensure
  [run-session creation](../../../functions/src/runs/store.ts) derives ticket
  issue/expiry time from the server boundary.
- [x] Ensure
  [upload grant and finalize](../../../functions/src/runs/submission_store.ts)
  derive lease/expiry transitions from the server boundary.
- [x] Retain deterministic time injection for internal unit/emulator tests.
- [x] Confirm the normal Flutter callable request/response remains compatible.

Tests:

- [x] Request-supplied future time cannot future-date a run ticket.
- [x] Request-supplied time cannot select or provision a future board.
- [x] Request-supplied time cannot extend an upload lease.
- [x] Request-supplied time cannot bypass run-session expiry during finalize.
- [x] Auth gating remains unchanged.

Done when:

- [x] no user-controlled clock reaches an authority decision in local source
- [x] Functions build and emulator tests pass
- [x] deployed callables reject client-selected time and the validator enforces
  the ticket/window policy

Evidence:

- `corepack pnpm --dir functions test`: 167 passed
- `dart analyze services/replay_validator`: no issues
- `dart test test` from `services/replay_validator`: 65 passed
- [production deployment](../functions-audit-remediation/production-deployment-2026-07-19.md)
- [production client-time and ticket/window verification](../functions-audit-remediation/production-verification-2026-07-19.md)

---

## Phase 1 — Correct current-selection prefetch

Objective:

- retain the useful cache fast path while making every prefetched ticket
  canonical, ownership-clean, and generation-safe

### Verified foundation

- [x] Prefetch key contains:
  - [x] user id
  - [x] ownership revision
  - [x] game compatibility version
  - [x] mode
  - [x] level
  - [x] selected character
  - [x] deterministic loadout digest
- [x] Cache is in-memory.
- [x] Maximum cached ticket entries is `4`.
- [x] Expiry safety skew is `5000ms`.
- [x] Per-key request interval is `1500ms`.
- [x] Concurrent same-key requests are deduplicated.
- [x] Ticket consumption removes the selected entry immediately.
- [x] Exact ticket identity is checked before reuse.
- [x] Expired or mismatched tickets fall back to remote creation.
- [x] Restart bypasses prefetched tickets and uses the strict remote path.
- [x] Auth, canonical apply, local mutation, reset, and disposal clear cache
  structures.

### Required corrections

- [ ] Remove the additional weekly request from
  [startWarmup](../../../lib/ui/state/app/controllers/auth_profile_controller.dart).
- [ ] Make current canonical selection the only supported prefetch target.
- [ ] If `startRunTicketPrefetchFor(...)` remains, make it no-op for a
  noncanonical mode/level.
- [ ] Run the ownership-sync-before-run gate before creating a prefetched
  session.
- [ ] Snapshot selection/key only after the ownership gate completes.
- [ ] Add a monotonic invalidation generation in
  [AppState](../../../lib/ui/state/app/app_state.dart).
- [ ] Capture generation at request start and require it to match at completion.
- [ ] Ensure A → B → A state drift cannot revive the A request.
- [ ] Ensure auth-session drift cannot revive an old request for the same user.
- [ ] Validate the response against the captured key before placing it in cache.
- [ ] Keep request-budget, LRU, and in-flight metadata bounded across churn.

Diagnostics:

- [ ] `prefetch_request`
- [ ] `prefetch_stored`
- [ ] `prefetch_hit`
- [ ] `prefetch_miss_empty`
- [ ] `prefetch_miss_expired`
- [ ] `prefetch_miss_key_mismatch`
- [ ] `prefetch_drop_generation`
- [ ] `prefetch_drop_ownership_not_clean`
- [ ] `prefetch_request_failed`
- [ ] Verify diagnostics never contain ticket/session/nonce/auth/loadout
  payloads.

Tests in
[app_state_run_ticket_prefetch_test.dart](../../../test/ui/state/app_state_run_ticket_prefetch_test.dart):

- [x] exact-match reuse
- [x] consume-once behavior
- [x] expired fallback
- [x] mismatched fallback
- [x] same-key in-flight dedupe
- [x] request interval
- [x] LRU eviction
- [x] restart bypass
- [x] canonical/auth invalidation of completed cache entries
- [ ] response mismatch rejected before storage
- [ ] ownership-pending state prevents prefetch request
- [ ] current canonical selection is the only warmup request
- [ ] stale completion dropped after selection A → B → A
- [ ] stale completion dropped after canonical invalidation with the same key
- [ ] stale completion dropped after auth-session drift for the same user
- [ ] diagnostics cover hit, miss, failure, and generation drop

Done when:

- [ ] every prefetch request represents the current ownership-clean canonical
  selection
- [ ] invalidation cannot be undone by an older asynchronous completion
- [ ] no speculative weekly request reaches the backend
- [ ] state tests pass without relying on a backend-incompatible fake

---

## Phase 2 — Complete route UX and bound asset warmup

Objective:

- preserve immediate feedback while making failures explicit and actual
  Play-to-run latency measurable

### Verified route behavior

- [x] Hub Play navigates to a bootstrap route before descriptor preparation.
- [x] Level setup enters the bootstrap route after its selection barrier.
- [x] Bootstrap prepares the descriptor through `AppState`.
- [x] Success replaces bootstrap with the run route.
- [x] Failure displays an error and Retry action.
- [x] Platform back navigation remains available.

### Required route correction

- [ ] Add an explicit Return to Hub action to
  [run_start_bootstrap_page.dart](../../../lib/ui/pages/hub/run_start_bootstrap_page.dart).
- [ ] Ensure Return to Hub cannot leave duplicate bootstrap/run routes.
- [ ] Test visible Retry and Return to Hub actions.
- [ ] Test retry without route stacking or stale descriptor state.
- [ ] Test Return to Hub reaches the hub.

### Required asset correction

- [ ] Define the selected level/character first-frame critical asset set.
- [ ] Limit blocking
  [run-start warmup](../../../lib/ui/assets/ui_asset_lifecycle.dart) to that set.
- [ ] Stop blocking on every enemy catalog entry.
- [ ] Stop blocking on every projectile catalog entry.
- [ ] Stop blocking on every pickup catalog entry.
- [ ] Stop blocking on every spell-impact catalog entry.
- [ ] Keep non-critical warmup game-managed or non-blocking.
- [ ] Update the forest parallax test to match authoritative generated theme
  data, or correct the generated data if five layers are intended.

Done when:

- [ ] failure recovery has explicit Retry and Return to Hub actions
- [ ] blocking asset work is selected-run-specific and bounded
- [ ] Play tap → bootstrap and Play tap → first usable frame are both measured
- [ ] relevant widget and asset lifecycle tests pass

---

## Phase 3 — Preserve backend fast paths and finish deployment configuration

Objective:

- retain verified backend improvements and make runtime tuning deployable and
  measurable

### Verified backend implementation

- [x] `runSessionCreate` has explicit region alignment in
  [index.ts](../../../functions/src/index.ts).
- [x] Active-board loading tries deterministic managed document id first.
- [x] Compatibility query remains available when managed id is absent.
- [x] Board status/mode/level/window/version/bounds validation remains.
- [x] Ranked session creation loads before provisioning.
- [x] Provisioning occurs only for an explicit missing-board result.
- [x] Manifest is reloaded once after provisioning.
- [x] Callable response still returns `runTicket`.
- [x] The authoritative `runTicket` is persisted in `run_sessions`.
- [x] Submission paths preserve top-level board compatibility and ticket
  fallback.
- [x] Replay validator decodes the persisted ticket.
- [x] Structured timing contains canonical load, board resolution, session
  write, and total duration.
- [x] Run creation uses a bounded client request ID and concurrent duplicates
  return one persisted ticket.
- [x] Atomic quota and active-session observations remain on the run-create
  authority path.

### Required deployment and observability work

- [ ] Record `RUN_SESSION_CREATE_MIN_INSTANCES` for local/dev.
- [ ] Record `RUN_SESSION_CREATE_MIN_INSTANCES` for staging.
- [ ] Record `RUN_SESSION_CREATE_MIN_INSTANCES` for production.
- [ ] Identify the cost owner for a nonzero production value.
- [ ] Confirm deployed Flutter and Functions regions match.
- [ ] Confirm timing logs cover bounded success/failure outcomes.
- [ ] Capture representative backend baseline `p50/p95/p99`.
- [ ] Capture representative post-change `p50/p95/p99`.
- [ ] Separate quota/idempotency transaction time from canonical, board, and
  final session-write time in representative traces before tuning.
- [ ] Record sample size, traffic shape, cold/warm split, region, and date.
- [ ] Decide whether CPU/memory tuning is needed from evidence.

Done when:

- [ ] runtime settings are explicit rather than merely supported by code
- [ ] representative tail-latency improvement is demonstrated
- [ ] backend authority and callable compatibility tests remain green

---

## Phase 4 — Validation gate

### Audit evidence from July 16, 2026

- [x] `dart analyze`
  - no errors or warnings
  - five unrelated info-level diagnostics
- [x] focused client state tests
  - command:
    `flutter test test/ui/state/app_state_run_ticket_prefetch_test.dart test/ui/state/app_state_hybrid_sync_test.dart`
  - result: `27` passed
  - note: warmup tests emit binding-noise from replay submission resume
- [x] `corepack pnpm --dir functions build`
  - passed
  - repository and audit runtime are aligned on Node 24
- [x] full Functions emulator suite
  - passed using an isolated Firestore emulator because local port `8080` was
    occupied by a WSL relay
- [x] replay validator tests
  - result: `18` passed
- [x] run protocol tests
  - result: `27` passed
- [ ] bootstrap widget test file
  - success test passed
  - failure/Retry test is blocked by local
    `shaders/ink_sparkle.frag` runtime-stage format mismatch
- [ ] asset lifecycle tests
  - forest expectation currently requests five layers while generated theme
    data returns four

The passing prefetch test that requests both current and weekly combinations is
not valid production evidence: its fake run-session API does not enforce the
backend canonical-mode precondition.

### Required final commands

- [ ] `dart analyze`
- [ ] `flutter test test/ui/state`
- [ ] `flutter test test/ui/pages/hub`
- [ ] `flutter test test/ui/pages/select_level`
- [ ] `flutter test test/ui/ui_asset_lifecycle_parallax_test.dart`
- [ ] `flutter test test/ui`
- [ ] `corepack pnpm --dir functions build`
- [ ] `corepack pnpm --dir functions test`
- [ ] `dart analyze packages/run_protocol`
- [ ] `dart test` from `packages/run_protocol`
- [ ] `dart analyze services/replay_validator`
- [ ] `dart test` from `services/replay_validator`

Done when:

- [ ] every required command passes in the supported Flutter/Dart/Node toolchain
- [ ] no test fake permits a state the production backend rejects
- [ ] no authority, determinism, auth, replay, or revision invariant regresses

---

## Phase 5 — Performance evidence and rollout

### Metrics ledger

Historical manual baseline recorded March 18, 2026:

- cold start: `8–10s`
- warm/otherwise: `3–6s`

Historical post-change emulator sample:

- source: Functions emulator tests
- sample size: `n=14`
- `p50=86ms`
- `p95=258ms`
- `p99=258ms`
- range: `46–258ms`

The emulator sample is not comparable to the manual client baseline and does not
prove production improvement.

### Required measurements

- [ ] Play tap → first bootstrap feedback, before and after
- [ ] Play tap → descriptor ready, before and after
- [ ] Play tap → first usable run frame, before and after
- [ ] prefetch request/store/hit/miss/drop counts
- [ ] backend cold/warm `p50/p95/p99`, before and after
- [ ] asset warmup duration and critical asset count

### Rollout

- [ ] Deploy server-time authority hardening.
- [ ] Verify authority tests and production error rate.
- [ ] Deploy corrected current-selection prefetch and diagnostics.
- [ ] Verify hit rate, generation drops, and backend request volume.
- [ ] Deploy explicit route failure actions and bounded asset warmup.
- [ ] Verify Play-to-run-ready latency does not regress.
- [ ] Apply documented backend runtime settings.
- [ ] Verify tail latency and cost.

### Rollback

- [ ] Document remote-only ordinary start fallback.
- [ ] Document prefetch-consumption disable path.
- [ ] Document optional asset-warmup disable path.
- [ ] Document previous `minInstances` value.
- [ ] Exercise route-first rollback without weakening restart rules.

Server-time authority hardening is not rolled back as a latency experiment.

Done when:

- [ ] staging acceptance criteria pass
- [ ] production rollout evidence is recorded
- [ ] rollback instructions are tested

---

## Final acceptance

### Authority and correctness

- [ ] user payload time cannot influence run/board/upload authority
- [ ] prefetch targets only current canonical selection
- [ ] prefetch requires ownership-clean state
- [ ] stale generations cannot repopulate cache
- [ ] expired/mismatched/invalidated tickets are never reused
- [ ] restart remains strict and remote
- [ ] replay validator binds new sessions to persisted tickets

### UX and performance

- [ ] Play tap gives immediate feedback
- [ ] failure exposes Retry and Return to Hub
- [ ] blocking asset warmup is bounded and selection-specific
- [ ] useful prefetch hit rate is measured
- [ ] Play-to-run-ready latency does not regress
- [ ] backend tail latency improves measurably

### Operational readiness

- [ ] client/backend diagnostics are bounded and privacy-safe
- [ ] runtime configuration is explicit per environment
- [ ] all required validation passes in supported toolchains
- [ ] rollout and rollback evidence is complete
- [ ] this checklist has no unchecked blocker

Only after every final acceptance item is checked should this folder move to
`docs/building/archived/`.
