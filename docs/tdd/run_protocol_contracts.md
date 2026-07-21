# Run Protocol Contracts

This document describes the implemented shared contracts in
`packages/run_protocol`. The package is pure Dart and owns stable payload
values; it does not own gameplay simulation, UI state, Firestore layout, or
Cloud Run processing.

## Ownership and flow

1. Firebase Functions issues a `RunTicket`.
2. The Flutter client uses the exact ticket fields to configure Core and the
   replay recorder.
3. The recorder emits a `ReplayBlobV1` whose canonical digest covers its
   complete replay payload.
4. The replay validator compares the replay with the immutable ticket data and
   emits a `ValidatedRun`.
5. Projection workers derive `LeaderboardEntry`, ghost, and submission-status
   payloads from that validation result.

The protocol package is the shared wire/value-contract layer for those steps.
Backend authority remains in `functions/src` and
`services/replay_validator/lib`.

## JSON and value semantics

All protocol JSON contains only JSON-compatible values: null, booleans, finite
numbers, strings, lists, and objects with string keys. Canonical JSON sorts
object keys recursively and preserves list order. It rejects non-string keys,
non-finite numbers, and unsupported Dart object types before they can enter a
digest.

The following fields are deep-copied into recursively immutable values when a
contract is constructed:

- `ReplayBlobV1.loadoutSnapshot`
- `ReplayBlobV1.clientSummary`
- `RunTicket.loadoutSnapshot`
- `ValidatedRun.stats`

`toJson()` and `ReplayBlobV1.toCanonicalPayloadJson()` return detached mutable
copies. Mutating a caller-owned input map or a returned serialization map must
not change the retained contract value or a replay digest.

## Runtime validation

Constructors validate public invariants at runtime and throw `ArgumentError`
for invalid direct construction. `fromJson` uses the typed reader helpers and
throws `FormatException` for malformed wire data. Assertions are supplemental
developer checks only and are not an enforcement mechanism.

Important enforced constraints include:

- command-frame ticks are positive, strictly increasing in a replay, and do
  not exceed `totalTicks`
- command axes are finite, paired where required, and inside `[-1, 1]`; masks
  contain only supported bits
- board keys/manifests, leaderboard entries, validated runs, and submission
  values reject empty identity fields and invalid ranges
- replay and command encoding versions must be explicitly supported

`services/replay_validator/tool/aot_protocol_probe.dart` compiles and runs the
critical malformed-input and direct-construction cases in AOT mode. This guards
against accidental regression to assertion-only validation.

## Ticket, board, and replay binding

`RunTicket.tickHz` is an authoritative simulation rate. The client must pass
it unchanged through the run-start descriptor, route, `GameCore`, controller,
and recorder. The validator rejects a replay whose `tickHz` differs from the
ticket.

Practice tickets and replays have no board fields. Competitive and weekly
tickets require a board ID, board key, and compatibility versions. Their board
key must match the ticket mode and level, and its ruleset and score versions
must equal the ticket's version fields. The replay must then match that ticket
binding exactly.

The ticket also binds the run session ID, seed, level, character, loadout
snapshot/digest, and compatibility tuple. The validator recomputes the loadout
digest and compares canonical JSON snapshots rather than trusting client
claims.

## Compatibility and testing

Do not rename existing wire keys or change replay canonicalization without an
explicit migration: replay digests, stored submissions, and ghost artifacts
depend on the present shape. Add fields backward-compatibly where possible and
keep replay/command versions explicit.

Protocol changes require focused package tests for JSON round trips, malformed
inputs, direct constructors, canonical JSON edge cases, defensive copying, and
digest stability. Changes to ticket/replay bindings additionally require
cross-layer coverage, including a non-default ticket rate and the validator's
AOT protocol probe.

Related implementation documents:

- [Replay validator worker](replay_validator_worker.md)
- [Ghost replay serialization and deserialization](ghost_run_serialization_deserialization.md)
