# run_protocol

Pure-Dart shared contracts for RPG Runner run sessions, replays, boards,
leaderboards, validation results, and submission state.

This package defines wire/value contracts only. It does not contain gameplay
simulation, Flutter/Flame UI code, Firebase access, Firestore storage layout,
or Cloud Run processing.

## Main contracts

- `RunTicket`: server-issued authorization and deterministic run configuration
- `LoadoutDigest`: shared Dart/TypeScript canonical loadout hashing used by
  ticket prefetch, issuance and validation
- `ReplayBlobV1` and `ReplayCommandFrameV1`: replay payload and canonical
  SHA-256 digest binding
- `BoardKey` and `BoardManifest`: ranked board identity and active-board data
- `ValidatedRun`, `LeaderboardEntry`, and `SubmissionStatus`: validation and
  projection payloads
- `CodexRunProgress`: optional accepted-result evidence with a level identity
  and per-enemy kill counts; omitted on legacy results

Import the public API with:

```dart
import 'package:run_protocol/run_protocol.dart';
```

## Contract guarantees

- Wire JSON uses only JSON-compatible values. Canonical JSON recursively sorts
  object keys, preserves list order, and rejects non-string keys, non-finite
  numbers, and unsupported values.
- Public constructors enforce protocol invariants at runtime. `fromJson`
  rejects malformed payloads with `FormatException`; production validation does
  not rely on Dart assertions.
- Typed wire integers must fit the exact shared Dart/JavaScript range
  `[-9007199254740991, 9007199254740991]`; decoding rejects overflow before
  conversion. Storage generations remain decimal strings.
- Digest-bound JSON (`ReplayBlobV1` loadout/client summary,
  `RunTicket.loadoutSnapshot`, and `ValidatedRun.stats`) is deep-copied and
  immutable within the value object. Serialization returns detached maps.
- `RunTicket.tickHz` is authoritative. The client, recorder, replay, and
  validator must use the exact issued rate.
- Ranked ticket board keys must match the ticket mode, level, ruleset version,
  and score version. Practice tickets and replays omit board fields.

## Compatibility

Existing JSON keys and replay canonicalization are compatibility-sensitive:
they affect replay digests, stored submissions, and ghost artifacts. Add new
fields backward-compatibly where possible; make replay/command encoding
versions explicit when changing behavior.

Replay-v1 encoding preserves native Dart numeric spelling. Loadout hashing uses
an explicit cross-language profile: safe integral numbers (including integral
doubles normalized to integers), well-formed Unicode, UTF-16 sorted object keys,
and preserved list order. Fractional loadout numbers are rejected. Current
authorized loadout digests and replay-v1 bytes are unchanged.

`test/fixtures/loadout_digest_v1.json` is consumed by both Dart and Functions
tests. `test/fixtures/replay_v1.json` pins complete replay canonical bytes and
SHA-256 digests; do not regenerate expected values to accommodate encoding drift.

## Validation

From the repository root:

```sh
dart analyze packages/run_protocol
dart test packages/run_protocol/test
```

Changes to constructor validation must also extend the validator's AOT probe:

```sh
cd services/replay_validator
dart compile exe tool/aot_protocol_probe.dart -o aot_protocol_probe
./aot_protocol_probe
```

See [the protocol contract TDD](../../docs/tdd/run_protocol_contracts.md) for
ownership, flow, invariants, and cross-layer testing requirements. Contributors
should also read [AGENTS.md](AGENTS.md).
