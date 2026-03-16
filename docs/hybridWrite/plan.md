# Ownership Hybrid Sync Implementation Plan (Loadout + Selection)

Date: March 16, 2026  
Status: Implementation plan (one-pass capable)

## Implementation Strategy

Target delivery model: single cohesive PR (one pass) with no long-lived
parallel path.

Guardrails for one pass:

- keep backend callable contracts unchanged
- keep authority boundary unchanged (`AppState -> LoadoutOwnershipApi`)
- migrate all Tier B/Tier C call sites in the same PR
- add tests for coalescing, conflict recovery, and route/run sync barriers
- block merge unless `dart analyze` and touched tests are green

## Implementation Checklist (Execution Order)

1. Define sync primitives
  - add `ownership_sync_policy.dart`
  - add `ownership_pending_command.dart`
  - add `ownership_sync_status.dart`
2. Add durable outbox store
  - add `ownership_outbox_store.dart` using `SharedPreferences`
  - implement schema versioning (`ui.ownership_outbox.v2`)
3. Refactor `AppState` core pipeline
  - add optimistic overlay model
  - add enqueue/coalesce logic per policy tier
  - add flush scheduler (Tier B debounced, Tier C urgent)
  - add retry/backoff/jitter handling
  - add stale-revision recovery with canonical reload and draft reapply
4. Migrate command handlers
  - Tier B: `setAbilitySlot`, `setProjectileSpell`, `equipGear`
  - Tier C: `setRunMode`, `setLevel`, `setCharacter`
  - keep Tier A immediate-authoritative
5. Wire flush barriers
  - app lifecycle pause/inactive/detached
  - leave level setup route
  - leave loadout route
  - before run start
  - connectivity restored
6. Update call sites that currently chain sequential waits
  - ghost-run preselection flow uses Tier C optimistic selection + one pre-run
    barrier flush
7. Add/adjust tests
  - outbox durability
  - coalescing correctness
  - retry/idempotency behavior
  - stale-revision recovery
  - route/run barrier behavior
8. Validate and ship
  - `dart analyze`
  - targeted `flutter test` for touched state/ui tests
  - doc sanity pass

## File-Level Work Plan

Primary implementation files:

- `lib/ui/state/app_state.dart`
- `lib/ui/state/ownership_sync_policy.dart` (new)
- `lib/ui/state/ownership_pending_command.dart` (new)
- `lib/ui/state/ownership_sync_status.dart` (new)
- `lib/ui/state/ownership_outbox_store.dart` (new)

Integration files:

- `lib/ui/app/ui_app.dart` (lifecycle-triggered flush)
- `lib/ui/pages/selectLevel/level_setup_page.dart` (pre-exit Tier C barrier)
- `lib/ui/pages/selectCharacter/loadout_setup_page.dart` (selection sync path)
- `lib/ui/pages/hub/play_hub_page.dart` (pre-run barrier)
- `lib/ui/pages/leaderboards/leaderboards_page.dart` (ghost-run preselection)

Tests:

- `test/ui/state/**` (new and updated unit tests)
- route-level widget tests where barriers are enforced

## Goal

Implement a production-grade hybrid sync model in the current UI flow so we:

- avoid one network call per tap for rapid UI changes
- preserve crash-safe durability and deterministic recovery
- keep server-authoritative revision/idempotency guarantees
- keep instant/optimistic UX for:
  - Skills and Gear edits
  - Select Level and Practice/Competitive switching

## Scope

In scope:

- `AppState` sync coordinator for ownership mutations
- shared durable outbox with retry/backoff/conflict recovery
- command-policy tiers (same engine, different safety policies)
- integration for:
  - `SkillsBar` + `GearsTab`
  - level setup mode/level selection flow
- flush orchestration on lifecycle/route/run-start/connectivity triggers
- stale-revision recovery and optimistic draft reapply
- telemetry counters and operational thresholds

Out of scope:

- changing backend callable contract shape
- economy/reward progression design
- replacing current Firebase callable transport

## Current Baseline (As-Is)

- Skills/Gear:
  - `SkillsBar` calls `AppState.setAbilitySlot(...)` and
    `AppState.setProjectileSpell(...)` directly.
  - `GearsTab` calls `AppState.equipGear(...)` directly.
- Level setup:
  - level/mode controls call `AppState.setLevel(...)` and
    `AppState.setRunMode(...)`, which currently await network-backed selection
    persistence.
- `AppState` currently sends ownership mutations directly to
  `LoadoutOwnershipApi`.
- Backend already supports revision + idempotency via command envelope.

## Chosen Architecture

Use one sync coordinator inside `AppState` with policy tiers:

- **Tier A (Immediate-authoritative)**
  progression-critical commands send immediately.
- **Tier B (Write-behind optimistic)**
  high-frequency loadout edits apply optimistic local draft + durable outbox +
  debounced/coalesced flush.
- **Tier C (Selection-fast-sync optimistic)**
  level/mode selection applies optimistic local state immediately, but flushes
  with stricter urgency and hard barriers before critical transitions.

One authority boundary remains unchanged:
`AppState -> LoadoutOwnershipApi`.

## Command Classification

### Tier A: Progression-critical (send immediately)

- `learnSpellAbility`
- `learnProjectileSpell`
- `unlockGear`
- `awardRunGold`
- `purchaseStoreOffer`
- `refreshStore`

### Tier B: Loadout-edit (write-behind outbox)

- `setAbilitySlot`
- `setProjectileSpell`
- `equipGear`
- optional later: `setLoadout`

### Tier C: Selection-fast-sync (shared outbox, stricter flush)

- `setRunMode`
- `setLevel`
- `setCharacter` (optional: keep immediate if preferred; policy toggle allowed)

## New/Updated Client Components

Add in `lib/ui/state`:

- `ownership_sync_policy.dart`
- `ownership_outbox_store.dart`
- `ownership_pending_command.dart`
- `ownership_sync_status.dart`

Update in `lib/ui/state/app_state.dart`:

- canonical + optimistic overlay model
- policy-aware enqueue/send pipeline
- route/lifecycle/run-start preflush APIs

Policy defaults:

- Tier B debounce window: `750ms`
- Tier C debounce window: `100-200ms` (or immediate micro-batch)
- max staleness window: `8s`
- retry backoff: `1s -> 2s -> 4s ...`, cap `60s`
- retry jitter: `20%`

## Durable Outbox Schema

Persist to `SharedPreferences` with one key (for example
`ui.ownership_outbox.v2`).

Each pending entry stores:

- `coalesceKey`
- `commandType`
- `policyTier` (`A`/`B`/`C`)
- `payloadJson`
- `createdAtMs`
- `updatedAtMs`
- `deliveryAttempt`:
  - `commandId`
  - `expectedRevision`
  - `attemptCount`
  - `nextAttemptAtMs`
  - `sentPayloadHash`

Rules:

- outbox survives app kill/crash
- preserve insertion order for deterministic processing
- coalescing updates `updatedAtMs` but keeps original `createdAtMs`
- Tier C flush priority > Tier B

## Coalescing Rules

Use deterministic keys:

- `setAbilitySlot`: `ability:{characterId}:{slot}`
- `setProjectileSpell`: `projectile:{characterId}`
- `equipGear`: `gear:{characterId}:{slot}`
- `setRunMode`: `selection:runMode`
- `setLevel`: `selection:level`
- `setCharacter` (if Tier C): `selection:character`

Latest payload wins per key.

If a command is already in-flight and a newer payload arrives:

- keep new payload queued with `deliveryAttempt = null`
- do not mutate in-flight payload

## AppState Refactor Plan

Modify `lib/ui/state/app_state.dart`:

1. Introduce dual in-memory state:
   - canonical: `_selection`, `_meta`, `_ownershipRevision`
   - optimistic overlay: pending Tier B/Tier C edits applied for UI
2. Replace direct send in Tier B/Tier C methods:
   - apply optimistic update locally
   - enqueue/coalesce outbox entry with policy tier
   - schedule policy-based flush
   - `notifyListeners()` immediately
3. Keep Tier A methods immediate and authoritative.
4. Add public flush entrypoints:
   - `flushOwnershipEdits({required OwnershipFlushTrigger trigger})`
   - `ensureOwnershipSyncedBeforeRunStart()`
   - `ensureSelectionSyncedBeforeLeavingLevelSetup()`
5. Add sync status surface:
   - `pendingCount`
   - `pendingSelectionCount`
   - `oldestPendingAgeMs`
   - `isFlushing`
   - `lastSyncError`
   - `retryCount`
   - `conflictCount`

## Flush Triggers (Guaranteed)

Trigger flush from `lib/ui/app/ui_app.dart`:

- `AppLifecycleState.inactive`
- `AppLifecycleState.paused`
- `AppLifecycleState.detached`

Trigger flush from level setup route flow:

- before pop/remove away from `UiRoutes.setupLevel`, force Tier C flush

Trigger flush from loadout route flow:

- before pop/remove away from `UiRoutes.setupLoadout`, flush Tier B and Tier C

Trigger flush from `lib/ui/pages/hub/play_hub_page.dart`:

- before navigating to `UiRoutes.run`, require Tier C clean and flush Tier B

Trigger on connectivity recovery:

- when network becomes reachable, call `flushOwnershipEdits(...)`

## Conflict Recovery Algorithm

For each queued command:

1. If no `deliveryAttempt`, stamp:
   - `commandId = _newCommandId()`
   - `expectedRevision = current canonical revision`
2. Send using existing callable contract.
3. On success:
   - apply returned canonical state
   - remove queued entry
4. On transient failure:
   - keep same `commandId` + `expectedRevision`
   - increment `attemptCount`
   - schedule retry with backoff+jitter
5. On `staleRevision`:
   - reload canonical via `loadCanonicalState(...)`
   - reapply unsent optimistic draft locally
   - reset stale entry `deliveryAttempt = null`
   - retry once with fresh revision

Selection-specific rule:

- if canonical weekly constraints invalidate optimistic level,
  canonical state wins immediately and UI reflects forced level.

## UI Integration Details

`lib/ui/pages/selectCharacter/skills_tab.dart`:

- keep current method calls (`setAbilitySlot`, `setProjectileSpell`)
- no network logic in widget
- optimistic visuals remain immediate from `AppState`

`lib/ui/pages/selectCharacter/gears_tab.dart`:

- keep `equipGear` call path
- becomes Tier B optimistic write-behind under `AppState`

`lib/ui/pages/selectLevel/level_setup_page.dart`:

- keep control callbacks (`setRunMode`, `setLevel`)
- update selection instantly from optimistic overlay
- enforce Tier C flush before critical route transitions (leave page/start run)

## Additional Candidates to Include Now

Include now (same shared engine, policy-aware):

- `setCharacter` as Tier C (`selection:character` coalesce key)
  - reason: aligns character switching with level/mode fast-sync semantics
  - reason: removes mixed behavior caused by fire-and-forget character syncing
- leaderboard ghost-run preselection flow
  - when ghost run needs mode/level adjustment, enqueue Tier C updates,
    coalesce, then run one required pre-run flush barrier before
    `prepareRunStartDescriptor(...)`
  - expected result: fewer visible sequential waits

Include conditionally (when editable UI is enabled):

- `setBuildName`
  - classify as Tier C if edited frequently from text input
  - apply short debounce + coalescing

Do **not** include in write-behind (keep Tier A immediate-authoritative):

- economy/progression critical mutations:
  - `purchaseStoreOffer`
  - `refreshStore`
  - `awardRunGold`
  - unlock/learn actions that gate ownership progression

## Telemetry and Ops

Track counters/gauges:

- commands per user per minute by tier
- conflict rate (`staleRevision`) by command type
- retry rate by tier
- idempotency replay rate
- unsynced age (max pending age)
- selection sync latency p50/p95

Operational thresholds:

- warn if unsynced age > `30s`
- warn if Tier C pending age > `5s`
- alert if conflict or retry rate spikes above baseline

## Rollout Plan

Phase 1:

- implement shared outbox engine + Tier B for skills (`setAbilitySlot`,
  `setProjectileSpell`)
- add lifecycle + run-start flush
- validate metrics

Phase 2:

- add `equipGear` to Tier B
- add connectivity-restored flush trigger

Phase 3:

- add Tier C optimistic selection (`setRunMode`, `setLevel`)
- include `setCharacter` in Tier C
- add strict pre-exit/pre-run selection flush barriers
- integrate ghost-run mode/level preselection with Tier C preflush
- validate weekly constraint behavior under conflicts

Phase 4:

- remove legacy direct-send fallback from production path
- harden telemetry dashboards and operational alerts for Tier B/Tier C

## Test Plan

Add/update tests in `test/ui/state`:

1. `skills edits coalesce to latest per slot`
2. `debounce flush sends one command for rapid tap burst`
3. `max staleness triggers flush even without more input`
4. `outbox persists across app restart`
5. `retry keeps same commandId for transient failure`
6. `stale revision reloads canonical and reapplies unsent draft`
7. `selection updates are optimistic and immediate in level setup`
8. `setRunMode/setLevel coalesce and flush with Tier C priority`
9. `leave level setup waits for Tier C flush (or timeout policy)`
10. `run-start blocks until required Tier C sync is clean`
11. `weekly canonical constraint overrides optimistic level safely`
12. `Tier A commands bypass outbox and send immediately`

## Acceptance Criteria

- Skills/Gear interactions are optimistic and responsive.
- Level/mode selection is visually immediate and remains safe.
- No one-call-per-tap network pattern for rapid Tier B edits.
- Pending edits survive app kill and are retried safely.
- Revision/idempotency contract remains intact.
- On conflict, UI converges to canonical state and reapplies unsent draft.
- Flush is guaranteed on page exit, app pause/background, run start, and
  connectivity restore.
- Tier C sync barriers protect run start and route transitions.
- Touched tests pass and `dart analyze` is clean for touched files.

