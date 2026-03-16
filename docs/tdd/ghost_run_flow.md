# Ghost Run Flow (What / How / Why)

This document explains the full ghost-run pipeline in the current codebase: how a ghost becomes available, how a player starts a ghost race, how replay data is fetched and validated, and how it is rendered in-run.

## Scope

Included:
- Ghost publication lifecycle (validator + leaderboard + ghost manifest)
- Client start flow from Leaderboards UI
- Backend authorization and manifest signing
- Local replay cache behavior
- Deterministic ghost playback and render bridge
- Cleanup / retention behavior

Not included:
- General auth bootstrap (see `authentication_flow_and_authorization.md`)
- Generic cloud function catalog (see `firebase_cloud_functions_overview.md`)
- Non-ghost local caches (see `local_cache_and_persistence.md`)

---

## 1) What a “ghost run” is in this repo

A ghost run is a **read-only deterministic replay** of a previously validated leaderboard run.

- It is represented by a replay blob (`ReplayBlobV1`) and associated ghost manifest metadata.
- It is rendered as a separate, translucent ghost layer in Flame.
- It never becomes gameplay authority for the player’s live run.

Core idea:
- **Live run** = authoritative gameplay state for the current user.
- **Ghost run** = deterministic playback used only for visual/race reference.

---

## 2) Why the architecture is split this way

### A) Security and fairness

Ghost fetches are auth-gated callable requests. The backend verifies auth identity and only returns manifests marked active/exposed.

Why:
- Prevents unauthenticated scraping of replay artifacts.
- Prevents clients from bypassing publication state by directly discovering storage paths.

### B) Determinism and portability

The client re-simulates the replay command stream using `GameCore` in `GhostPlaybackRunner`.

Why:
- Keeps ghost behavior aligned with deterministic simulation rules.
- Avoids shipping large per-frame state recordings.

### C) Operational control

Ghost publication is decoupled from client runtime and handled by replay validation/projector services.

Why:
- Top-N policy can evolve independently.
- Demotion/exposure lifecycle can be centrally enforced.

### D) Performance and resilience

Client uses temp-file cache and validates replay integrity + manifest matching before use.

Why:
- Repeated ghost starts do not always require network.
- Corrupt or mismatched artifacts fail closed.

---

## 3) End-to-end flow

## 3.1 Publish pipeline (server side)

1. A submitted run is validated by replay validator worker.
2. For board modes, validator projects leaderboard state.
3. Top entries are marked ghost-eligible and top10 view is refreshed.
4. Ghost publisher promotes replay artifacts to ghost storage path and upserts ghost manifests.

Key details:
- Candidate leaderboard entries start with `ghostEligible: false` then top10 refresh marks top entries as `ghostEligible: true`.
- Promoted ghost object path is canonicalized as:
  - `ghosts/<boardId>/<entryId>/ghost.bin.gz`
- Ghost manifest status/exposure drives client visibility:
  - active + exposed => available
  - demoted / not exposed => not available

## 3.2 Player starts “VS Ghost” (client UI)

1. Leaderboards page shows a trailing `VS Ghost` action only when:
   - `entry.ghostEligible == true`
   - `entry.entryId` is non-empty
2. On tap:
   - UI aligns app selection to target run mode + level.
   - `AppState.prepareRunStartDescriptor(ghostEntryId: entryId)` is called.

## 3.3 Run start descriptor + ghost bootstrap

Inside `prepareRunStartDescriptor(...)`:
1. Ensures auth session.
2. Forces canonical ownership/state refresh from backend.
3. Creates a run session ticket (`runSessionCreate`).
4. If board-bound and `ghostEntryId` exists:
   - calls `loadGhostReplayBootstrap(boardId, entryId)`.

`loadGhostReplayBootstrap(...)` does:
1. `loadGhostManifest(...)` via ghost API callable.
2. `GhostReplayCache.loadReplay(manifest)` to resolve replay bytes.
3. Returns `GhostReplayBootstrap` attached to `RunStartDescriptor`.

## 3.4 Ghost manifest load (callable)

Client calls `ghostLoadManifest` with `userId/sessionId/boardId/entryId`.

Backend handler:
1. Requires authenticated callable context.
2. Validates `userId == auth.uid`.
3. Loads manifest from:
   - `leaderboard_boards/{boardId}/ghost_manifests/{entryId}`
4. Requires manifest state:
   - `status == "active"`
   - `exposed == true`
5. Requires storage path to be under `ghosts/` prefix.
6. Signs short-lived download URL (TTL 15 minutes).
7. Returns manifest + signed URL + expiry.

## 3.5 Replay cache + validation (client)

`FileGhostReplayCache` behavior:
1. Cache directory: system temp under `rpg_runner/ghost_cache`.
2. Cache key includes board/entry/runSession/updated timestamp.
3. Attempts to read existing cached file first.
4. If cache miss:
   - validates download URL is not already expired,
   - downloads bytes,
   - optionally gzip-decompresses,
   - parses `ReplayBlobV1` with digest verification,
   - verifies replay `runSessionId` and `boardId` match manifest,
   - writes bytes to cache,
   - prunes superseded cache files for same board+entry.

Failure behavior: invalid data is rejected; bad cached files are deleted and re-fetched.

## 3.6 In-run playback + rendering

When `RunnerGameWidget` initializes:
1. If `ghostReplayBootstrap` exists, it creates `GhostPlaybackRunner.fromReplayBlob(...)`.
2. On each controller tick, ghost runner advances to player tick:
   - `runner.advanceToTick(_controller.tick)`
3. Widget publishes ghost render feed via notifiers:
   - replay blob
   - latest ghost snapshot
   - drained ghost events

`RunnerFlameGame` listens to those notifiers and maintains a dedicated ghost layer:
- ghost player/enemy/projectile views
- ghost-specific visual style (`RenderVisualStyle.ghost`)
- ghost event cues (projectile hit flashes, visual cue pulses)

The ghost layer is fail-safe:
- if required ghost inputs are missing/malformed, layer is cleared or disabled.

What is intentionally **not** rendered from ghost data:
- Manifest-only metadata is not drawn in-world:
   - `uid`, `sourceReplayStorageRef`, `downloadUrl`, `downloadUrlExpiresAtMs`
   - leaderboard context fields (`score`, `distanceMeters`, `durationSeconds`, `sortKey`, `rank`, `updatedAtMs`)
- Replay integrity/binding fields are validation inputs, not visuals:
   - replay digest (`canonicalSha256`), `runSessionId`, and board binding fields
- Ghost layer renders a subset of snapshot/entity data only:
   - player, enemies, and projectiles
   - it does **not** spawn ghost pickups/HUD/state panels from manifest metadata
- Ghost playback does not drive gameplay authority:
   - no collision/score/reward ownership is taken from ghost data; live run state remains authoritative.

---

## 4) Data contracts and ownership

## 4.1 Leaderboard entry (online view)

Used by leaderboards page to decide if ghost action is available:
- `entryId`
- `ghostEligible`
- rank/score/distance/duration metadata

## 4.2 Ghost manifest

Carries publication + download metadata:
- identity: `boardId`, `entryId`, `runSessionId`, `uid`
- storage refs: `replayStorageRef`, `sourceReplayStorageRef`
- signed fetch: `downloadUrl`, `downloadUrlExpiresAtMs`
- leaderboard context: `score`, `distanceMeters`, `durationSeconds`, `sortKey`, `rank`, `updatedAtMs`

## 4.3 Ghost replay bootstrap

Client-side run attachment:
- manifest
- verified `ReplayBlobV1`
- cached file handle + cache timestamp

---

## 5) Authorization and trust boundaries

Trusted server responsibilities:
- Manifest availability (`active` + `exposed`)
- Signed URL issuance
- Path restriction (`ghosts/`)

Client responsibilities:
- Verify replay digest
- Verify replay identifiers against manifest (`runSessionId`, `boardId`)
- Treat ghost as render-only signal

Result:
- Client can render a ghost only when server policy allows it and replay payload validates.

---

## 6) Lifecycle and retention behavior

### Promotion / demotion

Ghost publisher:
- promotes top entries to active/exposed manifests,
- demotes previous manifests leaving top set,
- sets demoted manifests non-exposed,
- eventually deletes demoted ghost objects/manifests after grace period (default 7 days).

### Cleanup safety

Run-submission cleanup checks whether a run session is still ghost-exposed before deleting validated replay artifacts.

Why:
- Avoid removing replay data still needed by active ghost manifests.

---

## 7) Failure modes and user-visible outcomes

Common fail-closed cases:
- Ghost not active/exposed anymore => manifest load behaves as unavailable.
- URL already expired before fetch => start blocked.
- Replay decode/digest mismatch => start blocked (or cache invalidated + retry path).
- Board/run mismatch between manifest and replay => start blocked.
- Ghost playback init/runtime failure => ghost layer is cleared/disabled; live run remains playable.

UI behavior:
- Start failures surface snackbar messages and return player to normal flow.

---

## 8) Practical debugging checklist

1. Verify board entry has `ghostEligible: true` and valid `entryId`.
2. Verify callable auth context exists and `userId` matches auth uid.
3. Verify manifest doc exists and is `active + exposed`.
4. Verify manifest `replayStorageRef` under `ghosts/`.
5. Verify signed URL freshness (`downloadUrlExpiresAtMs`).
6. Verify replay digest + manifest ID matching in cache loader.
7. Verify `RunnerGameWidget` publishes ghost notifiers each tick.
8. Verify `RunnerFlameGame` ghost layer is not disabled and has ghost views.

---

## 9) Related docs

- `docs/tdd/authentication_flow_and_authorization.md`
- `docs/tdd/firebase_cloud_functions_overview.md`
- `docs/tdd/local_cache_and_persistence.md`
- `docs/tdd/ghost_run_serialization_deserialization.md`
