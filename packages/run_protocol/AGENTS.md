# AGENTS.md - Run Protocol Package

Instructions for AI coding agents working in `packages/run_protocol/`.

## Package Responsibility

`packages/run_protocol` is the shared Dart contract package for run-session and
replay-adjacent data. It owns stable value objects and codecs for:

- run modes and run tickets
- replay blobs, command streams, and replay digests
- board keys and board manifests
- leaderboard entries and sort keys
- validated run records and submission status payloads

This package is contract code, not gameplay logic, UI state, or backend storage
logic.

## Hard Boundaries

- keep the package pure Dart
- do not import Flutter, Flame, Firebase, Firestore, or HTTP clients
- do not import `runner_core`; protocol contracts must not depend on the
  simulation implementation
- do not put app orchestration, backend persistence, or Cloud Run worker logic
  here

If a field only exists for local UI convenience or Firestore layout, it probably
belongs in `lib/ui/state/**`, `functions/src/**`, or
`services/replay_validator/**` instead.

## Wire Contract Discipline

Treat encoded JSON shapes as compatibility-sensitive wire contracts.

- avoid renaming existing JSON keys without a migration plan
- preserve canonical JSON and digest behavior for replay payloads
- add fields in a backward-compatible way when possible
- keep version constants explicit when changing replay or command encoding
- reject malformed inputs at decode boundaries using the existing reader/codec
  helpers
- keep map ordering and canonical serialization deterministic wherever a digest,
  sort key, or idempotency check depends on it

Replay digest changes can invalidate stored submissions and ghost artifacts, so
coordinate them deliberately.

## Current Important Files

- `lib/run_protocol.dart`: public barrel for package consumers
- `lib/replay_blob.dart`: replay payload, command-frame encoding, and digest
  binding
- `lib/replay_digest.dart`: canonical SHA-256 helpers
- `lib/run_ticket.dart`: server-issued run-start contract consumed by clients
  and validation
- `lib/board_key.dart` and `lib/board_manifest.dart`: board identity and active
  board metadata contracts
- `lib/leaderboard_entry.dart` and `lib/sort_key.dart`: projection contracts and
  deterministic ranking keys
- `lib/run_duration.dart`: canonical authoritative/client tick-to-seconds
  conversion
- `lib/submission_status.dart` and `lib/validated_run.dart`: validation result
  and client-visible submission state
- `lib/codecs/`: typed JSON parsing and canonical JSON helpers

## Cross-Layer Responsibilities

Protocol changes often require matching updates outside this package:

- Flutter client state and adapters in `lib/ui/state/**`
- replay submission and run-start flows in `lib/ui/**`
- Firebase callable validators/stores in `functions/src/**`
- replay validation and projection logic in `services/replay_validator/lib/**`
- tests in all touched packages
- docs that describe the changed payload or invariant

Do not leave Dart protocol changes semantically out of sync with TypeScript
callable contracts in the same repo change.

## Testing Expectations

Minimum checks for protocol changes:

- `dart analyze packages/run_protocol`
- `dart test packages/run_protocol/test`

Add focused tests for:

- JSON round trips
- malformed input rejection
- canonical digest stability
- sort-key ordering
- backward-compatible optional fields

## Common Failure Modes To Avoid

- changing compact replay keys such as command-frame fields without migrating
  all readers and stored expectations
- using regular JSON encoding where canonical encoding is required
- accepting partially malformed payloads that downstream validators assume are
  normalized
- adding dependencies that make this package unusable from workers or tests
- changing protocol semantics without updating the replay validator and
  Firebase callable validators
- dropping immutable replay generation/digest fields between validated-run,
  leaderboard, and ghost contracts

---

For authoritative gameplay behavior, see `packages/runner_core/lib/AGENTS.md`.
For backend callables, see `functions/AGENTS.md`. For replay validation, see
`services/replay_validator/AGENTS.md`.
