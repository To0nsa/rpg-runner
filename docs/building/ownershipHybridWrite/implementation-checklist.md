# Hybrid Sync — Implementation Checklist

Date: March 16, 2026  
Status: Ready to implement  
Source plan: docs/building/hybridWrite/plan.md

## Goal

Execute hybrid sync in one cohesive delivery for:

- optimistic Gear/Skills edits
- optimistic Select Level + Practice/Competitive selection
- durable retry-safe server sync with revision/idempotency guarantees

## Delivery Assumptions

- Existing callable contracts remain unchanged.
- `AppState -> LoadoutOwnershipApi` stays the only ownership authority boundary.
- `SharedPreferences` is acceptable for outbox durability in this phase.
- This can ship as one PR if all listed tests/gates are green.

If any assumption changes, update this checklist before implementation.

## Locked Constants and Invariants

Do not change these during implementation unless the source plan is updated in
the same PR.

- Policy defaults:
  - Tier B debounce: `750ms`
  - Tier C debounce: `100-200ms` (or immediate micro-batch)
  - max staleness: `8s`
  - retry backoff: `1s -> 2s -> 4s ...`, cap `60s`
  - retry jitter: `20%`
- Outbox key/schema: `ui.ownership_outbox.v2`
- Coalesce keys:
  - `ability:{characterId}:{slot}`
  - `projectile:{characterId}`
  - `gear:{characterId}:{slot}`
  - `selection`
- Tier A commands remain immediate-authoritative (no write-behind):
  - `purchaseStoreOffer`
  - `refreshStore`
  - `awardRunGold`
  - progression unlock/learn commands
- Weekly canonical constraints override optimistic selection when conflicting.

## Locked Implementation Order

1. Sync primitives + outbox persistence
2. `AppState` coordinator and optimistic overlay
3. Tier B migration (skills/gear)
4. Tier C migration (selection)
5. Flush barriers + route/lifecycle wiring
6. Ghost-run preselection integration
7. Tests, telemetry hooks, and release gates

Do not start a later step before the previous step’s done criteria are met.

---

## Pre-flight

- [x] Confirm current baseline behavior and latency in:
  - level setup mode/level switching
  - skills/gear selection
  - leaderboard ghost-run start path
- [x] Capture simple latency baseline notes (manual):
  - tap-to-visual-update
  - tap-to-network-settle
- [x] Record current green baseline:
  - `dart analyze`
  - touched test slices
- [x] Confirm no pending backend contract changes are required.

Done when:

- [x] baseline is documented
- [x] repo is green before modifications

---

## Step 1 — Add Sync Primitives + Durable Outbox

Objective:

- define shared policy/status/queue model for Tier B + Tier C

Tasks:

- [x] Add `lib/ui/state/ownership_sync_policy.dart`.
- [x] Add `lib/ui/state/ownership_pending_command.dart`.
- [x] Add `lib/ui/state/ownership_sync_status.dart`.
- [x] Add `lib/ui/state/ownership_outbox_store.dart`.
- [x] Implement outbox key and schema versioning (`ui.ownership_outbox.v2`).
- [x] Implement tolerant decode for unknown/older entries (drop invalid safely).
- [x] Persist insertion order and coalescing metadata.
- [x] Persist delivery attempt metadata (`commandId`, `expectedRevision`, retry fields).

Done when:

- [x] outbox survives restart
- [x] policy tier metadata is persisted and reloadable
- [x] no UI call sites changed yet

---

## Step 2 — Refactor AppState Coordinator Core

Objective:

- introduce one policy-aware sync pipeline with optimistic overlay

Tasks:

- [x] Add optimistic overlay model in `lib/ui/state/app_state.dart`.
- [x] Add enqueue + coalesce by deterministic keys.
- [x] Add flush scheduler:
  - Tier B debounced
  - Tier C urgent/micro-batch
- [x] Add retry with jittered backoff.
- [x] Add stale-revision recovery:
  - canonical reload
  - unsent overlay reapply
- [x] Add sync status fields/surface (`pendingCount`, `isFlushing`, `lastSyncError`, etc.).
- [x] Add flush API surface used by route/lifecycle barriers.

Done when:

- [x] coordinator can enqueue/flush without UI migration
- [x] stale-revision path converges back to canonical safely

---

## Step 3 — Migrate Tier B (Loadout Edits)

Objective:

- make skills/gear interactions optimistic and coalesced

Tasks:

- [x] Route `setAbilitySlot` through Tier B enqueue in `app_state.dart`.
- [x] Route `setProjectileSpell` through Tier B enqueue.
- [x] Route `equipGear` through Tier B enqueue.
- [x] Keep widgets unchanged:
  - `lib/ui/pages/selectCharacter/skills_tab.dart`
  - `lib/ui/pages/selectCharacter/gears_tab.dart`
- [x] Ensure immediate `notifyListeners()` from optimistic overlay.

Done when:

- [x] no one-call-per-tap behavior for rapid skills/gear changes
- [x] UI remains instant while outbox drains in background

---

## Step 4 — Migrate Tier C (Selection Fast Sync)

Objective:

- make selection instant in UI while preserving strict sync safety

Tasks:

- [x] Route `setRunMode` through Tier C enqueue.
- [x] Route `setLevel` through Tier C enqueue.
- [x] Route `setCharacter` through Tier C enqueue.
- [x] Keep `setBuildName` immediate for now (documented non-migrated path).
- [x] Add/confirm coalesce keys:
  - `selection`
- [x] Keep weekly canonical constraint handling authoritative.

Done when:

- [x] level setup changes are immediate visually
- [x] canonical weekly constraints still override invalid optimistic state safely

---

## Step 5 — Flush Barriers + Lifecycle/Route Wiring

Objective:

- guarantee durable convergence before critical transitions

Tasks:

- [x] Trigger flush from lifecycle in `lib/ui/app/ui_app.dart`:
  - inactive
  - paused
  - detached
- [x] Enforce Tier C flush before leaving level setup route:
  - `lib/ui/pages/selectLevel/level_setup_page.dart`
- [x] Enforce Tier B+Tier C flush before leaving loadout route:
  - `lib/ui/pages/selectCharacter/loadout_setup_page.dart`
- [x] Enforce required pre-run sync before navigation to run:
  - `lib/ui/pages/hub/play_hub_page.dart`
- [x] Add connectivity-restored flush trigger.

Done when:

- [x] route exits and run start cannot bypass required sync barriers
- [x] pending edits survive and resume correctly after app background/restore

---

## Step 6 — Ghost-Run Preselection Integration

Objective:

- remove sequential selection latency in ghost-run launch path

Tasks:

- [x] Update `lib/ui/pages/leaderboards/leaderboards_page.dart` ghost start flow:
  - enqueue Tier C mode/level changes
  - run one pre-run required flush barrier
  - call `prepareRunStartDescriptor(...)`
- [x] Preserve existing error/safe-fail UX messaging.

Done when:

- [x] ghost start avoids chained selection waits
- [x] run-start preconditions still fail closed on sync/precondition errors

---

## Step 7 — Tests and Validation

Objective:

- prove deterministic and safe behavior under optimistic buffering

Tasks:

- [x] Add/update `test/ui/state` coverage for:
  - skills coalescing per slot
  - debounce collapse for rapid taps
  - max staleness auto-flush
  - outbox persistence across restart
  - retry keeps same `commandId`
  - stale-revision canonical reload + draft reapply
  - Tier C priority over Tier B
  - leave-level-setup barrier behavior
  - run-start required sync barrier behavior
  - weekly canonical override safety
- [x] Add/update leaderboards ghost-start tests for Tier C preselection + single barrier flush.
- [x] Add/update tests confirming `setCharacter` follows Tier C behavior.
- [x] Add/update route/widget tests for flush barriers where needed.
- [x] Keep Tier A commands immediate-authoritative in tests.
- [x] Add initial hybrid sync tests:
  - `test/ui/state/ownership_outbox_store_test.dart`
  - `test/ui/state/app_state_hybrid_sync_test.dart`
  - `test/ui/state/app_state_ownership_commands_test.dart` updated for manual flush expectations

Current Step 7 test coverage now includes:

- retry delivery reuses the same queued `commandId`
- stale-revision queued command recovery + canonical convergence
- Tier C selection delivery priority over Tier B loadout edits
- max-staleness pending command delivery override
- leave-level-setup selection sync barrier behavior
- run-start fail-closed sync barrier behavior
- leaderboards ghost-start page flow test (Tier C preselection + run navigation)
- level setup page run-start barrier test (pending selection flush before run)
- weekly canonical override safety behavior

Done when:

- [x] all targeted tests pass
- [x] no regression in authority or idempotency semantics

---

## Cross-Cutting Rules

- [x] Keep backend contracts unchanged.
- [x] Keep Tier A commands immediate (no write-behind).
- [x] Keep all ownership writes flowing only through `AppState` coordinator.
- [x] Keep docs and literals consistent across client/backend.
- [x] Keep plan and checklist synchronized in the same PR.
- [x] Avoid unrelated refactors in this implementation pass.

---

## Verification Commands

Run relevant subsets as work lands:

- [x] `dart analyze lib/ui/state lib/ui/pages lib/ui/app test`
- [x] `flutter test test/ui/state`
- [x] `flutter test test/ui/pages`
- [x] `flutter test test/ui`
- [x] `corepack pnpm --dir functions build`
- [x] `corepack pnpm --dir functions test`

---

## Release Gates

Before merge:

- [x] Steps 1-7 complete
- [x] analyzer/tests green
- [x] no direct-send legacy path left for Tier B/Tier C commands
- [x] route/run barriers confirmed in manual smoke checks
- [x] latency smoke check shows immediate visual response for Tier B/Tier C interactions

## Exit Criteria

Checklist is complete when:

- [x] Gear/Skills are optimistic, coalesced, and durable
- [x] level/mode/character selection is instant and safely synchronized
- [x] run start and route transitions are protected by required sync barriers
- [x] stale-revision recovery converges without user-visible corruption
- [x] authority and idempotency guarantees remain intact
