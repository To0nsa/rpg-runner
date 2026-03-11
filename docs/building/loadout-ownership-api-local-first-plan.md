# Loadout Ownership API Local-First Bridge

Date: March 9, 2026
Status: Implemented

## Superseded Note (March 11, 2026)

This plan documents the original local-first bridge phase.

Current state:

- `LocalLoadoutOwnershipApi` has been removed from `lib/ui/state`.
- `AppState` no longer defaults to a local ownership adapter.
- Production and test composition now require explicit ownership API wiring.
- Firebase ownership client path is fail-closed (no runtime mutation fallback).

## Goal

Build a local-first ownership pipeline for gear, skills, and spells that is
already shaped like a server-authoritative API. This lets us ship now with
local persistence and swap to Firebase authority later with minimal rewiring.

## Why This Is Needed

Current UI state still treats local persistence as authority in practice.
To move cleanly to Firebase-authoritative progression, we need one explicit
boundary that owns:

- command execution
- canonical normalization
- revision/conflict semantics
- idempotency semantics

## Scope

In scope:

- command-style ownership API for loadout/meta mutations
- revision-based optimistic concurrency
- command idempotency keys
- canonical response contract for success and rejection
- local adapter implementation (cache-backed)
- `AppState` migration to API-only writes
- conflict simulation hooks for tests

Out of scope:

- Firebase adapter implementation
- economy/reward design
- anti-cheat hardening beyond API contract shape

## Chosen Architecture

### 1) Single Boundary: `LoadoutOwnershipApi`

Add an API boundary that `AppState` uses for all ownership/loadout mutations.

Proposed file:

- `lib/ui/state/loadout_ownership_api.dart`

Proposed contract shape:

```dart
abstract class LoadoutOwnershipApi {
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String profileId,
  });

  Future<OwnershipCommandResult> equipGear(EquipGearCommand command);
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command);
  Future<OwnershipCommandResult> setAbilitySlot(SetAbilitySlotCommand command);
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  );
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  );
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  );
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command);
}
```

### 2) Canonical Composite State

The API owns a canonical state payload that combines selection + meta and
monotonic revision.

```dart
class OwnershipCanonicalState {
  const OwnershipCanonicalState({
    required this.profileId,
    required this.revision,
    required this.selection,
    required this.meta,
  });

  final String profileId;
  final int revision;
  final SelectionState selection;
  final MetaState meta;
}
```

### 3) Command Envelope

Every mutating command must include:

- `expectedRevision` for optimistic concurrency
- `commandId` for idempotency
- actor/profile identity (at minimum `profileId`)

```dart
abstract class OwnershipCommand {
  const OwnershipCommand({
    required this.profileId,
    required this.expectedRevision,
    required this.commandId,
  });

  final String profileId;
  final int expectedRevision;
  final String commandId;
}
```

## Required Semantics

### Revision Rule

For every command:

- if `expectedRevision != currentRevision`, reject with `staleRevision`
- do not mutate state on rejection
- return current canonical state in the response

### Idempotency Rule

For every command:

- if `commandId` is unseen, process normally
- if `commandId` repeats with identical command payload, return prior result
  without applying again
- if `commandId` repeats with different payload, reject with
  `idempotencyKeyReuseMismatch`

### Response Rule

Every command response returns:

- `canonicalState` (always)
- `newRevision` (same as canonical revision)
- `rejectedReason?` (null means accepted)

```dart
enum OwnershipRejectedReason {
  staleRevision,
  idempotencyKeyReuseMismatch,
  invalidCommand,
  forbidden,
}

class OwnershipCommandResult {
  const OwnershipCommandResult({
    required this.canonicalState,
    required this.newRevision,
    required this.replayedFromIdempotency,
    this.rejectedReason,
  });

  final OwnershipCanonicalState canonicalState;
  final int newRevision;
  final bool replayedFromIdempotency;
  final OwnershipRejectedReason? rejectedReason;

  bool get accepted => rejectedReason == null;
}
```

## Local Adapter Design

### Implementation

Add a local implementation:

- `lib/ui/state/local_loadout_ownership_api.dart`

Responsibilities:

1. Load cached `SelectionState` + `MetaState`.
2. Build canonical state with revision.
3. Execute commands through shared rules:
   - gear ownership/normalization via `MetaService`
   - slot legality via `LoadoutValidator`
4. Persist canonical updates back to local cache.
5. Track processed `commandId` results (idempotency ledger).

### Cache, Not Authority

Local persistence remains storage only. Authority is the API boundary.

That means:

- `AppState` never writes `SelectionStore`/`MetaStore` directly.
- only `LocalLoadoutOwnershipApi` touches local stores.

### Conflict Simulation (Testability)

Add a conflict injection hook in the local adapter to emulate remote updates.
This is required so stale-revision handling can be tested before Firebase.

Example strategy:

```dart
abstract class OwnershipConflictSimulator {
  bool shouldForceConflictForNextCommand();
}
```

If enabled for a command, adapter increments internal revision first, then
evaluates command revision check. This guarantees deterministic stale-revision
rejection paths in tests.

## `AppState` Migration

`AppState` becomes API-driven for ownership data.

Required changes:

1. Inject `LoadoutOwnershipApi` into `AppState`.
2. On bootstrap, call `loadCanonicalState(profileId)` and hydrate:
   - `_selection = canonical.selection`
   - `_meta = canonical.meta`
   - track current ownership revision in memory
3. For each mutation (`equipGear`, `setLoadout`, future learn/unlock commands):
   - send typed command with current in-memory revision + new command id
   - apply returned canonical state regardless of accept/reject
   - if rejected, keep UI synced to server/local-canonical state
4. Remove direct save calls from `AppState` for selection/meta.

Result:

- `AppState` is transport-agnostic.
- Local and future Firebase adapters share one behavior contract.

## Rules Engine Reuse (No Duplicate Logic)

The API adapter must continue using current domain rules:

- `MetaService` for ownership/equipped normalization
- `LoadoutValidator` for legality

No duplicated rule branches in UI.

This keeps local adapter behavior aligned with future Cloud Function behavior.

## Command Set (Bridge Baseline)

Initial command list:

- `EquipGearCommand`
- `SetLoadoutCommand`
- `SetAbilitySlotCommand`
- `SetProjectileSpellCommand`

Second wave commands (progression):

- `LearnProjectileSpellCommand`
- `LearnSpellAbilityCommand`
- `UnlockGearCommand`

All commands use the same envelope (`profileId`, `expectedRevision`,
`commandId`) and same result contract.

## Query Contract Plan

To avoid bringing back legacy per-domain `unlocked*` helpers, ownership reads
should be exposed through one typed query contract on the API boundary.

Planned read model:

- `getOwnershipSnapshot(profileId, characterId?)`

Suggested response shape:

- `profileId`
- `revision`
- `inventory` (unlocked weapon/spellbook/accessory ids)
- `equippedByCharacter`
- `spellListByCharacter`
- optional pre-sorted `candidatesBySlot` for UI convenience

Rules:

- Query returns canonical normalized state only.
- Local adapter and future Firebase adapter must return identical fields.
- UI read paths consume this query model, not `MetaService` legacy helpers.

## Suggested File Layout

- `lib/ui/state/loadout_ownership_api.dart` (interfaces + DTOs)
- `lib/ui/state/local_loadout_ownership_api.dart` (local adapter)
- `lib/ui/state/ownership_canonical_store.dart` (cache wrapper if needed)
- `lib/ui/state/app_state.dart` (API integration)
- `test/ui/state/local_loadout_ownership_api_test.dart`
- `test/ui/state/app_state_ownership_conflict_test.dart`

## Testing Requirements

Minimum test matrix:

1. `expectedRevision` match applies mutation and increments revision.
2. stale revision rejects and returns canonical state unchanged.
3. duplicate `commandId` with same payload returns replayed result only.
4. duplicate `commandId` with different payload rejects.
5. `AppState` updates from rejected result (conflict recovery path).
6. local conflict simulator reliably triggers stale revision behavior.

## Acceptance Criteria

- `AppState` performs ownership mutations only through `LoadoutOwnershipApi`.
- Every mutating command carries `expectedRevision` and `commandId`.
- Every command response returns canonical state + revision + optional reject.
- Local adapter supports deterministic stale-revision simulation for tests.
- Existing starter-owned baseline remains canonical after migration.
- `flutter test` and `dart analyze` pass for touched files.

## Verification

Validated with:

- `dart analyze lib/ui/state lib/ui/bootstrap test/ui/state`
- `flutter test test/ui/state/local_loadout_ownership_api_test.dart`
- `flutter test test/ui/state/app_state_ownership_conflict_test.dart`
- `flutter test test/ui/state/app_state_loadout_mask_test.dart`

## Firebase Transition Path

Implemented client-side bridge (March 10, 2026):

- Added `FirebaseLoadoutOwnershipApi` in `lib/ui/state` with the same
  `LoadoutOwnershipApi` command/read contract.
- Added callable transport abstraction (`FirebaseLoadoutOwnershipSource`) and
  production callable source (`PluginFirebaseLoadoutOwnershipSource`).
- Wired production UI composition to use Firebase ownership adapter with local
  fallback for environments where backend callables are not yet deployed.
- Added AppState command methods for:
  - `setAbilitySlot`
  - `setProjectileSpell`
  - `learnProjectileSpell`
  - `learnSpellAbility`
  - `unlockGear`

Still required for full server authority:

- map commands to callable functions or Cloud Run endpoints
- enforce same revision/idempotency semantics server-side
- return canonical normalized state from backend
- implementation playbook:
  `docs/building/firebase-loadout-ownership-backend-playbook.md`

`AppState` should not require additional behavioral changes beyond dependency
rewiring once backend callables are live.

## Auth Phase (Current)

Completed in this phase:

- Added `FirebaseAuthApi` implementing `AuthApi` for production identity.
- Wired production composition (`UiApp`) to instantiate `AppState` with
  `FirebaseAuthApi`.
- Bound session lifecycle through `AppState` bootstrap/mutations via
  `ensureAuthenticatedSession()`:
  - missing session => Play Games restore attempt before anonymous sign-in
    fallback
  - expiring/expired token => refresh path
  - session/user change => stale write recovery via canonical reload path
- Added AppState integration coverage for missing/expired/session-changed auth
  flows.
- Added provider-link contract on `AuthApi` for both anonymous and
  non-anonymous sessions:
  - `linkAuthProvider(AuthLinkProvider provider)`
  - typed outcomes via `AuthLinkResult` (`linked`, `alreadyLinked`,
    `canceled`, `failed`, `unsupported`)
- Implemented Play Games link path in `FirebaseAuthApi`
  (`PlayGames` v2 server-side access via Android method channel +
  `PlayGamesAuthProvider.credential`) for Android.
- Added `AppState.linkAuthProvider(...)` to expose provider-link flow to UI
  actions.
- Added Firebase auth adapter tests for anonymous and non-anonymous provider
  linking (including already-linked/unsupported/canceled branches).
- Added Profile page "Manage linked accounts" section for both anonymous and
  non-anonymous users (`Link Play Games` on Android).
- Added Firebase callable-backed profile name persistence:
  - Functions callables:
    - `playerProfileLoad`
    - `playerProfileSaveDisplayName`
  - Firestore-backed profile store (`player_profiles/{uid}`) for
    `displayName` + `displayNameLastChangedAtMs`.
  - Added unique-name reservation index (`display_name_index/{normalizedName}`)
    enforced transactionally on save.
- Added UI remote profile adapter (`FirebaseUserProfileRemoteApi`) and wired
  `AppState` bootstrap/updateProfile to sync display names with backend while
  keeping non-name profile fields local.
- Added account-deletion contract and production adapter:
  - `AccountDeletionApi` boundary in `lib/ui/state`
  - Firebase callable adapter (`FirebaseAccountDeletionApi`) using
    `accountDelete`
  - `AppState.deleteAccountAndData()` orchestration:
    - call backend deletion
    - clear local profile/session persistence
    - reset in-memory state for clean relaunch
  - Profile page "Danger zone" with two-step delete confirmation and
    app-close on success (prevents immediate guest re-creation in-process).
- Added tests for:
  - Firebase account deletion adapter result/error mapping
  - AppState deletion orchestration success/failure
  - Profile page delete action confirmation flow.
- Implemented and deployed backend callable `accountDelete`:
  - Auth guard: callable requires authenticated Firebase user (`auth.uid`).
  - Identity guard: `request.userId` must match `auth.uid`.
  - Cascade deletion scope (UID-scoped):
    - `player_profiles/{uid}`
    - `display_name_index/*` documents claimed by `uid`
    - all `ownership_profiles/*` documents where `uid` matches
      (including nested idempotency subcollections via recursive delete)
    - ghost collections (UID-scoped docs):
      - `ghost_runs`
      - `leaderboard_ghost_runs`
      - `weekly_ghost_runs`
  - Final step deletes the Firebase Auth user (`admin.auth().deleteUser(uid)`),
    tolerating already-missing user records.

Still pending for full server authority:

- Backend verification of Firebase ID tokens on ownership commands.
- Server-side revision/idempotency ledger for canonical state authority.
- Account-link UX handling for provider collisions (e.g. credential already in
  use) and sign-in fallback flows.
- Extend account-deletion cascade when new backend collections are introduced
  (e.g. future ghost/leaderboard schemas outside current collection set).
