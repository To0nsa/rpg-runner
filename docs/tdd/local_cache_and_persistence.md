# Local Cache And Persistence (What Is Stored On Device)

This doc lists what the app caches locally today, where it is stored, how it is used, and why it exists.

## 1) Quick summary

Local storage in the current app is split into:

- persistent key-value data (SharedPreferences),
- temporary replay/ghost files on device temp storage,
- in-memory runtime caches (not persisted across app restarts).

Authoritative gameplay/profile/progression state is still server-backed and fetched through callables.

## 2) Persistent local data (SharedPreferences)

## A) Practice leaderboard entries

Implementation:

- `lib/ui/leaderboard/shared_prefs_leaderboard_store.dart`

Keys:

- v3 entries: `leaderboard_v3_entries_<levelId>_<runMode>`
- v3 next id: `leaderboard_v3_next_id_<levelId>_<runMode>`
- legacy v2 migration read path:
  - `leaderboard_v2_entries_<levelId>`
  - `leaderboard_v2_next_id_<levelId>`

Data shape:

- JSON list of `RunResult` rows (top-10 after sort/dedupe).

How used:

- Written from game-over panel for Practice runs.
- Read in Practice leaderboards page.
- Competitive/Weekly leaderboards use online APIs, not this local store.

Why:

- Practice mode keeps a lightweight local PB/top-10 history without requiring online authority.

## B) Run submission spool (retry/resume queue)

Implementation:

- `lib/ui/state/run_submission_spool_store.dart`
- coordinator consumer: `lib/ui/state/run_submission_coordinator.dart`

Key:

- `run_submission_spool_v1_entries`

Data shape:

- JSON list of `PendingRunSubmission` entries, including:
  - `runSessionId`, `runMode`
  - `replayFilePath`, `canonicalSha256`, `contentLengthBytes`, `contentType`
  - lifecycle step (`queued`, `uploading`, `awaitingServerStatus`, etc.)
  - retry metadata (`attemptCount`, `nextAttemptAtMs`)
  - optional server/object/error fields

How used:

- Added when a replay is queued for submission.
- Updated through grant/upload/finalize/status steps.
- Removed when terminal status is reached.
- Reloaded on app warmup to resume pending submissions.

Why:

- Makes replay submission resilient across app pause/kill/restart.

## 3) Local temporary files

## A) Recorded replay spool + finalized replay blob

Implementation:

- recorder: `lib/game/replay/run_recorder.dart`
- recorder setup: `lib/ui/runner_game_widget.dart`

Directory:

- `<systemTemp>/rpg_runner/replay_spool`

Files per run session:

- `<runSessionId>.frames.ndjson` (frame spool)
- `<runSessionId>.replay.json` (final replay blob used for upload)

How used:

- Commands are appended per tick during a run.
- On run end, recorder finalizes replay blob.
- Submission pipeline uploads using the local replay file path.

Why:

- Needed for deterministic replay submission and validation pipeline.

Note:

- These are temp files, not long-term profile/progression data.
- They may remain until overwritten/cleaned by temp-storage lifecycle.

## B) Ghost replay cache files

Implementation:

- `lib/ui/state/ghost_replay_cache.dart`

Directory:

- `<systemTemp>/rpg_runner/ghost_cache`

File naming:

- `ghost_<boardId_entryId>_<encodedKey>.replay.json`

How used:

- When opening ghost playback, app checks local cache first.
- If absent/invalid, downloads from signed URL and writes cache file.
- Cache is validated against manifest (`runSessionId`, `boardId`).
- Superseded cache files for same entry are pruned.

Why:

- Faster ghost load and reduced repeated network fetches.

## 4) In-memory caches (not persisted)

## A) UI asset lifecycle caches

Implementation:

- `lib/ui/assets/ui_asset_lifecycle.dart`
- LRU utility: `lib/ui/assets/lru_cache.dart`

What is cached in memory:

- parallax `AssetImage` layer lists (hub/run scopes),
- player idle animation bundles,
- in-flight precache futures.

How used:

- warmup for hub selection,
- reduced repeated decode/load work for UI assets.

Why:

- smoother navigation and lower repeated asset load overhead.

Lifecycle:

- run caches can be purged on run exit,
- all caches are cleared on lifecycle disposal.

## B) Firebase auth cached-read fallback (SDK state)

Implementation touchpoint:

- `lib/ui/state/firebase_auth_api.dart` (`readCachedCurrent()` fallback)

What this means:

- On network request failures, auth adapter can use currently cached Firebase user/session snapshot from SDK state.

Why:

- auth/session resilience during transient connectivity failures.

## 5) What is intentionally not persisted locally by this layer

The app-level state objects are held in memory and reloaded from backend on bootstrap:

- profile data (`playerProfileLoad`)
- ownership/progression canonical state (`loadoutOwnershipLoadCanonicalState`)

So local persistence is mainly for:

- practice-only local leaderboard convenience,
- submission reliability,
- temp replay/ghost artifacts,
- in-memory performance caches.

## 6) Operational notes

- SharedPreferences stores plain JSON payloads under stable keys listed above.
- Temp directories are OS-managed locations (`Directory.systemTemp`).
- If cache behavior changes, update this doc alongside:
  - storage key names,
  - file locations,
  - retention/cleanup behavior.