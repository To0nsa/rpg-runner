# Prepared navigation and reward verification

Implemented in source for compatibility `2026.10.11.1`. Production cutover and
device/end-to-end measurements remain release gates. Acceptance still requires
the authenticated ticket, digest-verified replay and deterministic Core; client
terrain and navigation uploads are never authority.

## Materialization and artifact trust

`GameCore` accepts `TerrainGraphMaterializer`. Live gameplay remains eager, with
complete immutable candidates admitted before a tick. The verifier constructs
geometry, collision, surfaces and placement immediately, resolving each profile's
graph on first use. Enumerating `publication.graphs` resolves every profile.
Version rebinding preserves deferred work and binds nodes to current surfaces.
Both paths use the same builder; missing prepared data changes only performance.

Core's binary codec keys include complete world-space geometry/source identity,
surface signatures, actor/traversal/jump parameters, codec version and a generated
algorithm revision. Publication counters are excluded; coordinates and source IDs
are retained. The revision fingerprints builder, extractor, codec and transitive
relative Core imports. After changing those sources run:

```powershell
dart run packages/runner_core/tool/update_navigation_revision.dart
dart run packages/runner_core/tool/update_navigation_revision.dart --check
```

Manifests bind exact keys to SHA-256 and byte length. Decode verifies integrity,
dimensions, canonical integers and graph invariants. The producer refuses a stale
source fingerprint before reading old pieces. Pieces are capped at 16 MiB,
manifests at 32 MiB. The worker reads only its image's `/navigation` directory
(operator override `NAVIGATION_ARTIFACT_DIRECTORY`) and retains a 32 MiB byte LRU.
Missing/corrupt pieces fall back. An invalid installed manifest fails startup.
The client consumes its packaged assets, never replay-supplied graphs.

## Routes, preparation and fallback

`functions/src/runs/navigation_routes.json` defines 16 Practice seeds per
selectable level, 60 Hz, a 128-chunk worker horizon, an eight-chunk client prefix
and explicit ranked windows. The producer enumerates production forward camera
selections at width 600 and all actor profiles. It verifies old pieces before
reuse, publishes the manifest after completion, and removes only obsolete flat
generated `.rng` files. `preparation.json` records plan/manifest digests and size.

This is not exhaustive selection coverage. Retained/skipped windows, different
tick rates, later ranked windows and endless continuation may miss. They use the
same deterministic builder: on demand on the worker, background preparation on
the client. There is no new run-length cap.

The client loads only one candidate's pieces, decodes them in a native isolate
(cooperatively on web), and retains Core's bounded lookahead cache. It keeps no
whole-route graph cache. Missing generated assets are supported in development.

Practice issuance chooses uniformly from the pool excluding the previous issued
seed. The Firestore issuance transaction writes both the session and
`practiceRouteHistory.<level>.seed` in canonical ownership. Idempotent retries
retain their ticket. Prefetch counts as issuance; played routes can still repeat.
Account deletion removes the containing ownership document. Pool rotation does
not alter issued tickets; local Developer Practice remains unrestricted.

Ranked seeds retain the production algorithm and immutable board windows. Before
a release/window, update explicit window IDs in the plan, then freeze the seeds:

```powershell
corepack pnpm --dir functions build
node functions/tool/refresh_navigation_routes.mjs
corepack pnpm --dir functions build
dart run packages/runner_core/tool/prepare_navigation.dart --client
```

The script is offline and never modifies boards. Tests check frozen seeds against
the production helper and compatibility. Custom provisioning overrides need
matching plan inputs or correctly fall back. Practice rotation is a reviewed
content release, with explicit traversal and coverage checks.

## Release and evidence

Web release preparation generates client assets. Mobile builds must run the same
`--client` command first. Docker generates the worker pack with its independent
locked Dart resolution. Generated binary packs are ignored by Git. Plan/producer
changes invalidate both consumers' cached release evidence; coordinated cutover
is required. Cloud Build allows 60 minutes including the final-image benchmark
at one CPU/512 MiB. Startup probes use a one-second interval/timeout and 60-failure
allowance. Minimum instances and billing settings are unchanged.

`services/replay_validator/tool/benchmark_reward_verification.dart` compares eager,
on-demand and captured prepared-cold/warm execution of a digest-verified replay.
It checks equal termination, distance, collectibles, kills, rescues and terrain
version. Captured graphs measure codec performance, not route coverage or server
acceptance. The existing strict 36,000-tick benchmark uses the worker materializer.

See [reward settlement operations](reward_settlement_operations.md) for durable
foreground completion and the [rollout plan](../building/reward_verification_latency.md)
for remaining live measurements.
