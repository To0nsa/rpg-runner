# run_protocol

Pure-Dart shared contracts for RPG Runner run sessions, replays, boards,
leaderboards, validation results, and submission state.

This package defines wire/value contracts only. It does not contain gameplay
simulation, Flutter/Flame UI code, Firebase access, Firestore storage layout,
or Cloud Run processing.

## Main contracts

- `RunTicket`: server-issued authorization and deterministic run configuration
- `ReplayBlobV1` and `ReplayCommandFrameV1`: replay payload and canonical
  SHA-256 digest binding
- `BoardKey` and `BoardManifest`: ranked board identity and active-board data
- `ValidatedRun`, `LeaderboardEntry`, and `SubmissionStatus`: validation and
  projection payloads

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
