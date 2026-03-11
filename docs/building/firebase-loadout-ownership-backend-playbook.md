# Firebase Loadout Ownership Backend Playbook

Date: March 10, 2026  
Status: Ready to implement

## Goal

Implement server-authoritative ownership for gear/skills/spells with the exact
contract already used by:

- `lib/ui/state/loadout_ownership_api.dart`
- `lib/ui/state/firebase_loadout_ownership_api.dart`

This removes local-client authority and makes Firestore + callable backend the
source of truth.

## Done Definition

- Both callable endpoints exist and are deployed:
  - `loadoutOwnershipLoadCanonicalState`
  - `loadoutOwnershipExecuteCommand`
- Server enforces:
  - Firebase auth identity
  - revision check (`expectedRevision`)
  - idempotency (`commandId`)
- Server always returns canonical payload matching current client DTO shape.
- Firestore rules block direct client writes to canonical ownership docs.
- App can run without local fallback in production.

## Recommended Backend Layout

Create a Firebase Functions TypeScript workspace and use this file layout:

```text
functions/
  src/
    index.ts
    ownership/
      contracts.ts
      firestore_paths.ts
      hash.ts
      defaults.ts
      validators.ts
      canonical_store.ts
      command_executor.ts
      apply_command.ts
  test/
    ownership/
      ownership_callable.test.ts
firestore.rules
```

Monorepo package manager baseline:

- workspace root: `pnpm-workspace.yaml`
- root scripts in `package.json`
- functions package scripts use `pnpm`

## Step-by-Step Implementation

1. Initialize Firebase backend (if missing):
   - `firebase init functions firestore`
   - Choose `TypeScript` + Node 20.
2. Add callable functions in `functions/src/index.ts`:
   - `loadoutOwnershipLoadCanonicalState`
   - `loadoutOwnershipExecuteCommand`
3. Define request/response contracts in `contracts.ts` (exact shapes below).
4. Define Firestore paths:
   - canonical doc:
     - `ownership_profiles/{uid}__{profileId}`
   - idempotency doc:
     - `ownership_profiles/{uid}__{profileId}/idempotency/{commandId}`
5. Implement `loadCanonicalState` callable:
   - Require `context.auth?.uid`.
   - Validate `profileId`.
   - Load canonical doc.
   - If missing, create canonical starter state revision `0`.
   - Return `{ canonicalState: ... }`.
6. Implement `executeCommand` callable:
   - Require `context.auth?.uid`.
   - Validate command envelope fields (`type`, `profileId`, `expectedRevision`, `commandId`, `payload`).
   - Run Firestore transaction with this exact order:
     1. Load canonical doc.
     2. Load idempotency doc for `commandId`.
     3. If idempotency doc exists:
        - same payload hash => return stored result with `replayedFromIdempotency: true`
        - different payload hash => reject `idempotencyKeyReuseMismatch`
     4. If `expectedRevision != currentRevision` => reject `staleRevision`
     5. Apply command mutation.
     6. Normalize canonical (required invariants).
     7. Increment revision by `+1`.
     8. Save canonical + idempotency result.
7. Implement command handlers for all command types already in client:
   - `setSelection`
   - `resetOwnership`
   - `setLoadout`
   - `equipGear`
   - `setAbilitySlot`
   - `setProjectileSpell`
   - `learnProjectileSpell`
   - `learnSpellAbility`
   - `unlockGear`
8. Add Firestore rules to deny direct ownership writes from clients.
9. Add emulator tests for all acceptance cases (matrix below).
10. Deploy:
   - from repo root:
     - `pnpm functions:deploy`
   - or from `functions/`:
     - `pnpm run deploy`

## Contract (Must Match Client)

### Callable `loadoutOwnershipLoadCanonicalState`

Request:

```json
{
  "profileId": "profile_123",
  "userId": "client_user_id",
  "sessionId": "client_session_id"
}
```

Notes:

- Ignore `userId` and `sessionId` for authority.
- Authority comes from `context.auth.uid`.

Response:

```json
{
  "canonicalState": {
    "profileId": "profile_123",
    "revision": 4,
    "selection": { "...": "SelectionState json" },
    "meta": { "...": "MetaState json" }
  }
}
```

### Callable `loadoutOwnershipExecuteCommand`

Request:

```json
{
  "command": {
    "type": "setAbilitySlot",
    "profileId": "profile_123",
    "userId": "client_user_id",
    "sessionId": "client_session_id",
    "expectedRevision": 4,
    "commandId": "cmd_abc",
    "payload": { "...": "type-specific payload" }
  }
}
```

Response:

```json
{
  "result": {
    "canonicalState": {
      "profileId": "profile_123",
      "revision": 5,
      "selection": { "...": "SelectionState json" },
      "meta": { "...": "MetaState json" }
    },
    "newRevision": 5,
    "replayedFromIdempotency": false,
    "rejectedReason": null
  }
}
```

`rejectedReason` values must be exactly:

- `staleRevision`
- `idempotencyKeyReuseMismatch`
- `invalidCommand`
- `forbidden`
- `unauthorized`

## Firestore Canonical Schema

Canonical document: `ownership_profiles/{uid}__{profileId}`

```json
{
  "uid": "firebase_uid",
  "profileId": "profile_123",
  "revision": 5,
  "selection": { "...": "SelectionState json" },
  "meta": { "...": "MetaState json" },
  "createdAt": "server timestamp",
  "updatedAt": "server timestamp"
}
```

Idempotency document:  
`ownership_profiles/{uid}__{profileId}/idempotency/{commandId}`

```json
{
  "payloadHash": "sha256 of canonicalized command json",
  "result": { "...": "OwnershipCommandResult json" },
  "createdAt": "server timestamp"
}
```

## Security Rules (Required)

Put this in `firestore.rules` (adapt if you have more collections):

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /ownership_profiles/{docId} {
      allow read, write: if false;
      match /idempotency/{commandId} {
        allow read, write: if false;
      }
    }
  }
}
```

Only backend callables should read/write these docs.

## Validation + Normalization Rules

At minimum, server must enforce:

- `command.profileId` non-empty
- `command.commandId` non-empty
- `expectedRevision >= 0`
- command payload matches command type
- command targets authenticated uid data only

If full gameplay normalization is not yet ported to backend, ship with:

1. strict envelope/revision/idempotency/auth checks
2. minimal payload shape validation
3. deterministic canonical serialization

Then port full normalization rules from local adapter as follow-up.

## Emulator Test Matrix

Implement tests for:

1. valid revision applies and increments revision
2. stale revision rejects with canonical unchanged
3. duplicate `commandId` + same payload returns replayed result
4. duplicate `commandId` + different payload rejects mismatch
5. unauthenticated call rejects `unauthorized`
6. cross-user profile access rejects `forbidden`
7. each command type mutates expected canonical fields

## Client Cutover Checklist

After backend is green in staging:

1. Ensure client is fail-closed in production wiring:
   - `FirebaseLoadoutOwnershipApi` is instantiated without runtime fallback
   - callable/load errors must surface to UI/app flow (no synthetic canonical)
2. Keep fallback only in debug/dev if desired.
3. Run these client tests:
   - `test/ui/state/firebase_loadout_ownership_api_test.dart`
   - `test/ui/state/app_state_ownership_conflict_test.dart`
4. Run backend emulator tests in CI.

## Immediate Next Task

Start with `command_executor.ts` and implement transaction semantics first.
Do not start with command business rules first; revision + idempotency is the
critical contract boundary.
