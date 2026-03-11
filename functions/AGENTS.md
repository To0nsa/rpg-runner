# AGENTS.md - Firebase Functions Backend

Instructions for AI coding agents working in `functions/`.

## Backend Responsibility

`functions/` contains the authenticated backend for player profile, ownership/progression state, and account deletion workflows.

Current domains:

- `src/ownership/`: canonical ownership state, command validation, command execution, idempotency, Firestore paths/defaults
- `src/profile/`: remote player profile loading and updates, display-name uniqueness
- `src/account/`: account deletion across profile, ownership, ghost-related collections, and auth user cleanup
- `src/index.ts`: callable function exports and auth gate entrypoints

## Source Of Truth Rules

- edit TypeScript in `functions/src/**`
- do not hand-edit generated output in `functions/lib/**`
- do not hand-edit generated test output in `functions/lib_test/**`
- keep `package.json`, `tsconfig.json`, and callable exports aligned when the backend surface changes

If you change source files, the expected follow-up is a build.

## Current Runtime Model

The backend uses:

- Firebase Functions v2 callable handlers via `onCall`
- Firestore via `firebase-admin`
- Node 20
- TypeScript compiled to ESM-style JavaScript in `lib/`
- emulator-driven tests executed against compiled `lib_test/**`

Do not introduce a second backend style or bypass the existing callable/transaction pattern without a strong reason.

## Auth And Validation Rules

Every callable currently follows the same pattern:

1. require `request.auth?.uid`
2. parse and validate request data using the domain validator
3. verify `userId` in the request matches the authenticated uid
4. execute domain logic
5. return a typed payload shape

Preserve that sequence. Do not trust client-supplied identity fields just because the client already authenticated.

## Ownership Domain Rules

The ownership backend is revisioned and command-driven. Preserve these invariants:

- canonical state is stored under `ownership_profiles`
- callers mutate ownership through command envelopes, not arbitrary field patches
- commands include `expectedRevision` and `commandId`
- idempotency is enforced per command id with payload hashing
- stale revisions and reused command ids with mismatched payloads must stay rejected
- canonical normalization/defaulting stays centralized in the ownership helpers

If you change the ownership contract, update:

- validators
- command application/execution
- Firestore path/default helpers if needed
- client adapters in `lib/ui/state/`
- tests covering revision and idempotency behavior

Do not weaken these rules to paper over a client bug.

## Profile Domain Rules

The player profile flow currently guarantees:

- authenticated users can load or lazily create a profile
- display names are normalized by policy
- uniqueness is enforced through `display_name_index`
- renames clean up the previous name claim when owned by the same user

Keep normalization and uniqueness logic centralized. Do not duplicate name-policy logic across multiple write paths.

## Account Deletion Rules

Account deletion currently spans:

- player profile docs
- display-name index docs
- ownership profile docs and subcollections
- ghost-related collections listed explicitly in `src/account/delete.ts`
- Firebase Auth user deletion

If the schema grows, update the explicit deletion coverage. Silent partial deletion is a bug.

## Firestore And Transaction Discipline

Use transactions when enforcing multi-document invariants such as:

- revision checks
- idempotency writes
- display-name ownership claims

Prefer narrow, typed helper functions over ad-hoc inline document parsing.

Rules:

- keep Firestore collection names centralized when a helper already exists
- normalize documents at the boundary before business logic consumes them
- avoid `any`; use explicit interfaces and typed helpers
- throw `HttpsError` for callable-facing failures

## Testing And Build Expectations

Relevant commands:

- build: `corepack pnpm --dir functions build`
- tests: `corepack pnpm --dir functions test`

The current test flow compiles TypeScript with `tsconfig.test.json` and then runs `node --test` against `lib_test/test/**` inside the Firebase emulator.

When changing backend behavior:

- update or add tests in `functions/test/**`
- ensure the compiled test path still maps correctly
- keep emulator assumptions intact

## Cross-Repo Contract Responsibilities

Changes here often require Flutter-side updates too. When a callable request or response changes, update:

- `lib/ui/state/firebase_*.dart` implementations
- any shared UI/state value objects or error handling
- docs that describe the contract

Do not leave the app and backend on different protocol versions in the same repo change.

## Common Mistakes To Avoid

- editing `functions/lib/**` instead of `functions/src/**`
- trusting `userId` from the client without matching it to auth uid
- bypassing revision/idempotency checks for ownership commands
- scattering collection names and normalization rules across multiple files
- changing callable payload shapes without updating Flutter client adapters and tests

---

For app-side consumers of these callables, see `lib/ui/AGENTS.md`.
