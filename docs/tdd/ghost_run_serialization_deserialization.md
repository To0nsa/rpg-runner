# Ghost Run Serialization / Deserialization (Technical)

This document focuses on byte-level and JSON-level contracts for ghost runs: how replay and manifest data are encoded, transported, decoded, validated, and then consumed by playback.

## 1) Data planes

Ghost flow uses two distinct serialized payloads:

1. **Ghost manifest payload** (callable JSON)
   - Small metadata contract for authorization, lookup, and download.
2. **Replay blob payload** (`ReplayBlobV1` JSON, optionally gzip-compressed bytes)
   - Full deterministic command stream + run/ticket binding fields.

The preceding leaderboard row is a separate `LeaderboardEntry` protocol value.
Its `ghostEligible` field identifies a top-10 publication candidate, while its
backward-compatible `ghostAvailable` field is false when absent and becomes
true only after the worker has observed a matching active/exposed manifest.
The client enables `VS Ghost` only from `ghostAvailable`; the manifest remains
the authoritative download and policy payload.

---

## 2) Replay blob format (`ReplayBlobV1`)

Source of truth: [packages/run_protocol/lib/replay_blob.dart](packages/run_protocol/lib/replay_blob.dart).

Top-level fields:
- `replayVersion` (int, currently `1`)
- `runSessionId` (string)
- `boardId` (nullable string, must pair with `boardKey`)
- `boardKey` (nullable object)
- `tickHz` (int)
- `seed` (int)
- `levelId` (string)
- `playerCharacterId` (string)
- `loadoutSnapshot` (object)
- `commandEncodingVersion` (int, currently `1`)
- `totalTicks` (int)
- `commandStream` (array of compact command frames)
- `clientSummary` (optional object)
- `canonicalSha256` (lowercase 64-char hex)

## 2.1 Canonical digest generation

Digest generation is deterministic:
1. Build canonical payload without `canonicalSha256`.
2. Canonical-JSON encode with recursively sorted object keys.
3. SHA-256 over UTF-8 JSON bytes.
4. Store as lowercase hex `canonicalSha256`.

Digest-bound JSON objects are deep-copied and immutable within their protocol
values. Serialization returns detached JSON maps, so callers cannot mutate a
replay's covered payload after its digest is generated.

Source:
- [packages/run_protocol/lib/codecs/canonical_json_codec.dart](packages/run_protocol/lib/codecs/canonical_json_codec.dart)
- [packages/run_protocol/lib/replay_digest.dart](packages/run_protocol/lib/replay_digest.dart)

On read, `ReplayBlobV1.fromJson(..., verifyDigest: true)` recomputes and rejects mismatches.

## 2.2 Compact command frame encoding

Each command frame is `ReplayCommandFrameV1` with compact keys:
- `t` = tick
- `mx` = move axis (optional)
- `ax`, `ay` = aim vector components (optional pair)
- `pm` = pressed mask bitfield (optional when non-zero)
- `hm` = hold-changed mask bitfield (optional when non-zero)
- `hv` = hold-value mask bitfield (optional when non-zero)

Pressed bits:
- bit0 jump
- bit1 dash
- bit2 strike
- bit3 projectile
- bit4 secondary
- bit5 spell

Invariant: `hv` may only set bits that are present in `hm`.

---

## 3) Replay serialization on client (recording side)

Recorder source: [lib/game/replay/run_recorder.dart](lib/game/replay/run_recorder.dart).

Write path:
1. During run, command frames are quantized and appended as canonical NDJSON lines (`*.frames.ndjson`).
2. Stream digest is accumulated over NDJSON lines.
3. On finalize, NDJSON is read back into command frames.
4. `ReplayBlobV1.withComputedDigest(...)` materializes full replay object.
5. Replay is written as canonical JSON text (`*.replay.json`).

Important distinction:
- Local finalized replay file is JSON text.
- Stored/served ghost replay object can be gzip-wrapped (`ghost.bin.gz` path).

---

## 4) Ghost manifest serialization (backend callable)

Callable contract:
- request parser: [functions/src/ghosts/validators.ts](functions/src/ghosts/validators.ts)
- handler: [functions/src/ghosts/callable_handlers.ts](functions/src/ghosts/callable_handlers.ts)
- store decode: [functions/src/ghosts/store.ts](functions/src/ghosts/store.ts)

Request JSON keys:
- `userId`
- `sessionId`
- `boardId`
- `entryId`

Response JSON shape:
- `{ ghostManifest: { ... } }`

Manifest fields returned to client:
- `boardId`, `entryId`, `runSessionId`, `uid`
- `replayStorageRef`, `sourceReplayStorageRef`
- `sourceReplayStorageGeneration`, `promotedReplayStorageGeneration`, `replayDigest`
- `score`, `distanceMeters`, `durationSeconds`, `sortKey`, `rank`, `updatedAtMs`
- `downloadUrl`, `downloadUrlExpiresAtMs` (added by callable signer)

Backend eligibility gate before serialization:
- Firestore manifest must be `status == "active"` and `exposed == true`.
- `replayStorageRef` must start with `ghosts/`.
- The signed URL includes the immutable `promotedReplayStorageGeneration`, so it cannot resolve a newer generation at the same object path.

---

## 5) Ghost manifest persistence schema (Firestore)

Write path from validator service:
- [services/replay_validator/lib/src/ghost_publisher.dart](services/replay_validator/lib/src/ghost_publisher.dart)

Manifest document path:
- `leaderboard_boards/{boardId}/ghost_manifests/{entryId}`

Upserted fields:
- identity: `boardId`, `entryId`, `runSessionId`, `uid`
- storage refs: `replayStorageRef`, `sourceReplayStorageRef`
- storage lineage: `sourceReplayStorageGeneration`, `promotedReplayStorageGeneration`
- replay integrity: `replayDigest`
- leaderboard fields: `score`, `distanceMeters`, `durationSeconds`, `sortKey`, `rank`
- lifecycle fields: `status`, `exposed`, `updatedAtMs`, optional `promotedAtMs`, `demotedAtMs`, `expiresAtMs`

Promotion writes `status=active, exposed=true`.
Demotion writes `status=demoted, exposed=false`.

---

## 6) Ghost replay deserialization on client

Client decode path:
- manifest model: [lib/ui/state/ghost_api.dart](lib/ui/state/ghost_api.dart)
- callable adapter: [lib/ui/state/firebase_ghost_api.dart](lib/ui/state/firebase_ghost_api.dart)
- cache/decoder: [lib/ui/state/ghost_replay_cache.dart](lib/ui/state/ghost_replay_cache.dart)

Deserialization sequence:
1. Parse callable response map.
2. Parse `GhostManifest.fromJson(...)` with strict required fields.
3. Try the versioned local cache first; URL freshness is required only on a cache miss.
4. Validate URL freshness (`downloadUrlExpiresAtMs > now`) and download bytes when no cache entry is usable.
5. Detect gzip by magic bytes `1f 8b`; if gzip, decompress.
6. UTF-8 decode + JSON parse.
7. Parse `ReplayBlobV1.fromJson(..., verifyDigest: true)`.
8. Enforce manifest/replay binding equality:
   - `replayBlob.canonicalSha256 == manifest.replayDigest`
   - `replayBlob.runSessionId == manifest.runSessionId`
   - `replayBlob.boardId == manifest.boardId`

If cached file fails decode/validation, cache entry is deleted and treated as miss.

---

## 7) Cache file serialization details

Cache implementation: [lib/ui/state/ghost_replay_cache.dart](lib/ui/state/ghost_replay_cache.dart).

Directory:
- `<systemTemp>/rpg_runner/ghost_cache`

Filename derivation:
- prefix from sanitized `boardId_entryId`
- encoded suffix from `boardId|entryId|runSessionId|promotedReplayStorageGeneration|replayDigest|updatedAtMs` (base64url, no `=`)
- final suffix: `.replay.json`

Note:
- Extension is always `.replay.json`, even when payload bytes are gzip-compressed.

Pruning behavior:
- On successful write, older files with same board+entry prefix are best-effort deleted.

---

## 8) Playback deserialization boundary

Playback constructor:
- [lib/game/replay/ghost_playback_runner.dart](lib/game/replay/ghost_playback_runner.dart)

`GhostPlaybackRunner.fromReplayBlob(...)` maps serialized strings/objects to runtime objects:
- enum names (`levelId`, `playerCharacterId`) -> typed enums
- `loadoutSnapshot` object -> `EquippedLoadoutDef`
- `commandStream` array -> tick-indexed frame map

After that, playback is runtime-only deterministic stepping (`advanceToTick(...)`), not further wire deserialization.

---

## 9) Failure classes by layer

Manifest layer failures:
- non-map response
- missing/invalid required manifest keys
- backend not-found/not-active/not-exposed

Replay bytes layer failures:
- HTTP non-200
- expired URL
- gzip decode failure
- JSON parse failure

Replay protocol layer failures:
- digest mismatch
- malformed frame fields
- invariant violations (e.g., hold masks)
- manifest/replay ID mismatch

All fail closed; ghost bootstrap is not attached if decoding/validation fails.

---

## Related docs

- [Ghost run flow](ghost_run_flow.md)
- [Replay validator worker](replay_validator_worker.md)
- [Local cache and persistence](local_cache_and_persistence.md)
