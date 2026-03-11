# Loadout Ownership Hybrid Write-Behind Plan

Date: March 11, 2026  
Status: Ready to implement

## Goal

Implement a production-grade hybrid write-behind sync model for loadout edits in
the current UI flow so we:

- avoid one network call per tap
- preserve crash-safe durability
- keep server-authoritative revision/idempotency guarantees
- keep instant/optimistic UX in Skills and Gear screens

## Scope

In scope:

- `AppState` write-behind behavior for loadout-edit commands
- `SkillsBar` + `GearsTab` mutation flow integration
- durable client outbox with retry/backoff
- flush orchestration on lifecycle/route/run-start triggers
- stale-revision recovery and draft reapply
- telemetry counters and operational thresholds

Out of scope:

- changing backend callable contract shape
- economy/reward progression design
- replacing current Firebase callable transport

## Current Baseline (As-Is)

- `SkillsBar` calls `AppState.setAbilitySlot(...)` and
  `AppState.setProjectileSpell(...)` immediately.
- `GearsTab` calls `AppState.equipGear(...)` immediately.
- `AppState` sends all ownership mutations directly to `LoadoutOwnershipApi`.
- Backend already supports revision + idempotency via command envelope.

## Chosen Architecture

Use a dedicated sync coordinator inside `AppState`:

- progression-critical commands: immediate send
- loadout-edit commands: local optimistic draft + durable outbox + coalesced flush

This keeps UI simple while preserving one authority boundary:
`AppState -> LoadoutOwnershipApi`.

## Command Classification

Progression-critical (send immediately):

- `learnSpellAbility`
- `learnProjectileSpell`
- `unlockGear`

Loadout-edit (write-behind outbox):

- `setAbilitySlot`
- `setProjectileSpell`
- `equipGear`

Optional later:

- `setLoadout` can remain immediate for now or be migrated after loadout-edit flow
  is stable.

## New Client Components

Add in `lib/ui/state`:

- `ownership_sync_policy.dart`
- `ownership_outbox_store.dart`
- `ownership_pending_command.dart`
- `ownership_sync_status.dart`

Policy defaults:

- debounce window: `750ms`
- max staleness window: `8s`
- retry backoff: `1s -> 2s -> 4s ...`, cap `60s`
- retry jitter: `20%`

## Durable Outbox Schema

Persist to `SharedPreferences` with one key (for example
`ui.loadout_ownership_outbox.v1`).

Each pending loadout-edit entry stores:

- `coalesceKey`
- `commandType`
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

## Coalescing Rules

Use deterministic keys:

- `setAbilitySlot`: `ability:{characterId}:{slot}`
- `setProjectileSpell`: `projectile:{characterId}`
- `equipGear`: `gear:{characterId}:{slot}`

Latest payload wins per key.

If a command is already in-flight and a newer payload arrives:

- keep new payload queued with `deliveryAttempt = null`
- do not mutate the in-flight command payload

## AppState Refactor Plan

Modify `lib/ui/state/app_state.dart`:

1. Introduce dual in-memory state:
   - canonical: `_selection`, `_meta`, `_ownershipRevision`
   - optimistic draft overlay: pending loadout edits applied immediately for UI
2. Replace direct send in loadout-edit methods:
   - apply optimistic update locally
   - enqueue/coalesce outbox entry
   - schedule debounced flush
   - `notifyListeners()` immediately
3. Keep progression-critical methods immediate and authoritative.
4. Add public flush entrypoints:
   - `flushOwnershipEdits({required OwnershipFlushTrigger trigger})`
   - `ensureOwnershipSyncedBeforeRunStart()`
5. Add sync status surface:
   - `pendingCount`
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
- route pop/remove away from `UiRoutes.setupLoadout`

Trigger flush from `lib/ui/pages/hub/play_hub_page.dart`:

- before navigating to `UiRoutes.run`

Trigger on connectivity recovery:

- when network becomes reachable, call `flushOwnershipEdits(...)`

## Conflict Recovery Algorithm

For each queued edit command:

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
   - reapply unsent draft locally
   - reset this entry `deliveryAttempt = null`
   - retry once with fresh revision

## UI Integration Details

`lib/ui/pages/selectCharacter/skills_tab.dart`:

- keep current method calls (`setAbilitySlot`, `setProjectileSpell`)
- no network logic in widget
- optimistic visuals remain immediate from `AppState`

`lib/ui/pages/selectCharacter/gears_tab.dart`:

- keep `equipGear` call path
- becomes optimistic write-behind under `AppState`

## Telemetry and Ops

Track counters/gauges:

- commands per user per minute
- conflict rate (`staleRevision`)
- retry rate
- replayed idempotency rate
- unsynced age (max pending age)

Operational thresholds:

- warn if unsynced age > `30s`
- alert if conflict or retry rate spikes above baseline

## Rollout Plan

Phase 1:

- implement write-behind for `setAbilitySlot` and `setProjectileSpell`
- add flush on lifecycle + run-start
- validate production metrics

Phase 2:

- add `equipGear` to same outbox pipeline
- add connectivity-restored flush trigger

Phase 3:

- remove production mutation fallback behavior
- keep fallback debug-only if needed

## Test Plan

Add/update tests in `test/ui/state`:

1. `skills edits coalesce to latest per slot`
2. `debounce flush sends one command for rapid tap burst`
3. `max staleness triggers flush even without more input`
4. `outbox persists across app restart`
5. `retry keeps same commandId for transient failure`
6. `stale revision reloads canonical and reapplies unsent draft`
7. `run-start blocks until pending edits flush or timeout policy is hit`
8. `progression-critical commands bypass outbox and send immediately`

## Acceptance Criteria

- Skills/Gear interactions are optimistic and responsive.
- No one-call-per-tap network pattern for loadout edits.
- Pending edits survive app kill and are retried safely.
- Revision/idempotency contract remains intact.
- On conflict, UI converges to canonical state and reapplies unsent draft.
- Flush is guaranteed on page exit, app pause/background, run start, and
  connectivity restore.
- Touched tests pass and `dart analyze` is clean for touched files.

