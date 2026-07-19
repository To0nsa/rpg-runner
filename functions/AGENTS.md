# AGENTS.md - Firebase Functions Backend

Instructions for AI coding agents working in `functions/`.

## Backend Responsibility

`functions/` contains the Firebase Functions backend for authenticated player
profile, ownership/progression, run-session, board, leaderboard, ghost, cleanup,
and account deletion workflows.

Current domains:

- `src/ownership/`: canonical ownership state, command validation, command execution, idempotency, Firestore paths/defaults
- `src/profile/`: remote player profile loading and updates, display-name uniqueness
- `src/runs/`: run-session ticket creation, upload grants, validation status,
  stale-validation repair, reward grant backfill, submission cleanup, and
  callable auth gating
- `src/boards/`: leaderboard board manifests, UTC windowing, provisioning, and active-board validation
- `src/leaderboards/`: callable board/rank reads and top-view decoding
- `src/ghosts/`: ghost manifest reads and signed replay download grants
- `src/account/`: account deletion across profile, ownership, ghost-related collections, and auth user cleanup
- `src/abuse/`: App Check rollout options, callable payload bounds, atomic
  per-UID quota windows, and bounded quota retention
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
- Firebase Functions v2 scheduled handlers via `onSchedule`
- Firestore via `firebase-admin`
- Cloud Tasks dispatch support for replay validation
- Node 24
- TypeScript compiled to ESM-style JavaScript in `lib/`
- emulator-driven tests executed against compiled `lib_test/**`

Do not introduce a second backend style or bypass the existing callable/transaction pattern without a strong reason.

## Auth And Validation Rules

Every user callable currently follows the same pattern:

1. apply the configured Functions App Check option
2. require `request.auth?.uid`
3. enforce shared payload bounds, then parse using the domain validator
4. verify `userId` in the request matches the authenticated uid
5. apply deletion/quota and domain authorization
6. execute domain logic
7. return a typed payload shape

Preserve that sequence. Do not trust client-supplied identity fields just because the client already authenticated.

Scheduled maintenance functions such as board provisioning and replay-submission
cleanup are not user callables, but they must still use narrow domain helpers and
avoid ad-hoc Firestore writes in `index.ts`.

## Ownership Domain Rules

The ownership backend is revisioned and command-driven. Preserve these invariants:

- canonical state is stored under `ownership_profiles`
- callers mutate ownership through command envelopes, not arbitrary field patches
- commands include `expectedRevision` and `commandId`
- idempotency is enforced per command id with payload hashing
- public command IDs are bounded and backend-safe
- idempotency outcomes are compact and expire only after the supported offline
  retry window
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
- abuse quota state
- ghost-related collections listed explicitly in `src/account/delete.ts`
- Firebase Auth user deletion

If the schema grows, update the explicit deletion coverage. Silent partial deletion is a bug.

## App Check And Abuse Controls

- keep App Check in monitoring mode until every enabled platform has measured
  attestation success and a rollback plan
- never treat App Check as identity or operation authorization
- do not add production quota values without recorded normal-client telemetry
- enforce quotas transactionally per UID and before Storage signing, task
  dispatch, or protected expensive reads
- keep quota/idempotency retention bounded and included in account deletion
- update `docs/tdd/callable_abuse_controls.md` when routes, limits, windows,
  platform providers, or retention change

## Run Session, Replay, And Reward Rules

Run sessions are the server-issued authority for replay validation. Preserve
these invariants:

- run tickets bind mode, level, character, loadout snapshot, seed, tick rate,
  board identity when applicable, and compatibility versions
- clients must create sessions through callables, not locally mint tickets
- upload grants must remain scoped to the authenticated user/session path
- finalize/status callables must preserve auth gating and state-machine checks
- validation state changes must remain compatible with
  `services/replay_validator`
- scheduled validation repair must remain bounded and idempotent; it may reclaim
  only expired leases or requeue eligible pending sessions, and must use
  generation-specific task names
- finalized replay metadata must preserve the exact positive Storage
  generation; re-finalization must not rebind a run to overwritten evidence
- reward grants must be idempotent and tied to run-session lifecycle state
- cleanup must not delete active or terminal artifacts outside its explicit
  eligibility rules

If run-ticket or submission-status payloads change, update
`packages/run_protocol`, the Flutter client adapters, and replay validator tests
in the same change.

## Board, Leaderboard, And Ghost Rules

Boards are provisioned server-side and act as the authority for ranked windows.
Preserve these invariants:

- board ids/keys must match mode, level, ruleset, score version, and window
- competitive windows use exact UTC month boundaries
- weekly windows use exact ISO week boundaries
- disabled or incompatible boards must not be returned as active play targets
- leaderboard callables read projected data; they do not validate replays
- ghost manifests must point only at approved ghost artifact paths and use
  signed download URLs

Leaderboard projection and ghost artifact creation happen in the replay validator
worker after deterministic validation, not in read callables.
Scheduled projection reconciliation must remain bounded, cursor-based, and
idempotent, and may advance its cursor only after the full board page is
durably enqueued.

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

- shared Dart protocol contracts in `packages/run_protocol/**` when the payload
  is shared with replay validation or app state
- `lib/ui/state/firebase_*.dart` implementations
- any shared UI/state value objects or error handling
- `services/replay_validator/**` when run-session, board, leaderboard, ghost, or
  reward validation semantics change
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
