# Platform services

Gameplay and UI share the same deterministic Core and rendering/input bridge.
Native filesystem and raw HTTP work is selected at compile time through
`dart.library.io` conditional imports, rather than platform checks at call sites.

## Replay artifacts and transport

`RunRecorder` exposes canonical frames, finalized replay values, an opaque
artifact ID and its byte length. `run_recorder_io.dart` owns the native spool,
`File` handles and incremental digest. `replay_spool_directory_io.dart` defines
the directory shared with native account-deletion cleanup. The existing native
directory, filenames, replay bytes and digest behavior are unchanged.

`RunReplayUploader` interprets the artifact ID only inside its platform adapter.
The native adapter reads that file and sends the existing signed multipart form;
the submission coordinator owns journaling, retry and settlement without
importing `dart:io`. Pending submissions retain the persisted `replayFilePath`
JSON key, while Dart callers use `replayArtifactId`. Existing account queues
remain readable without migration or deletion.

`GhostReplayBootstrap` carries the verified replay and an opaque cache key.
Native download, gzip decoding and file-cache management live in
`ghost_replay_cache_io.dart`; no filesystem handle reaches the run descriptor.
Developer profiles use an unavailable ghost adapter without creating a cache.

Browser replay storage, upload and ghost retrieval are explicitly unavailable.
Their adapters construct without native APIs and reject operations rather than
silently claiming success. Local Practice does not invoke them. Browser online
support requires real browser persistence/transport adapters before enabling
account-backed runs.

## Verification

Native tests exercise deterministic recording, cached-replay integrity, signed
multipart upload, submission retries and persisted queue compatibility.
`test/ui/state/platform_replay_adapters_browser_test.dart` runs in Chrome and
covers adapter selection and local-profile startup without native filesystem
access. Browser tests are additional evidence; native widget tests and a web
compile alone do not establish browser runtime support.
