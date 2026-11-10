# Equipment and Training Hall verification — November 10, 2026

Implementation: [player rules](../gdd/town_services.md),
[catalogue contract](../tdd/town_catalogue.md),
[workstream checklist](../building/town_services.md).

## Source and scope

- Frozen source: `02ea118adced9d0ed00c423ee092bf84e96ae87f`, on
  `release/town-services-20261110-v2`.
- Release source digest:
  `b3069af37cc2a89667bcd61f658f3812d5444e634b78b540f606788893f11523`.
- Environment: dev, project `rpg-runner-d7add`, region `europe-west1`.
- Compatibility: `2026.11.10 / rules-v2 / score-v4 / ghost-v1`.
- The snapshot includes the pre-existing completed localization, inbox and Admin
  work required by the current client. The original working branch and index
  were preserved. The source checkout remains clean after Android packaging.
- Offline Plan selected Coordinated scope because tracked tool/workspace inputs
  changed since the verified dev baseline. No gameplay mechanics were changed
  by the town-service implementation.

The initial release snapshot failed two backend expectations: a formerly future
compatibility version had become obsolete, and the settlement receipt fixture
still contained the rotating store. The compatibility cases were corrected and
the receipt regenerated through its real emulator transaction. The corrected
snapshot passed all release preparation gates before any deployment.

## Local validation

Canonical command, from the frozen checkout:
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/release/release.ps1 -Action Prepare -Environment dev`.

| Check | Observed result |
| --- | --- |
| Functions build and Firestore emulator suite | 370 passed, none skipped |
| Production-inventory tool tests | 5 passed |
| Client analysis (`lib`, `test`, `test_driver`) | No issues |
| Client suite, excluding integration-tagged tests | 1,509 passed, one existing skip |
| Replay validator analysis/tests and AOT protocol probe | 367 passed; probe passed |
| Core analysis/tests | 2,636 passed |
| Protocol analysis/tests | 133 passed |
| Content pipeline analysis/tests | 103 passed |
| Terrain analysis/tests | 25 passed |
| Navigation revision and generated-content freshness | Passed |
| Production dependency audit | Passed |
| Release web build and Chrome artifact smoke | Passed |
| English/French localization check | Passed |

The skipped client test is `launch flag reaches the hub on a fresh install
without Firebase` in `developer_mode_ui_test.dart`. The separate release web
smoke reached the Developer Practice hub, checked Practice-only Options, and
completed readiness/start/game-over without browser exceptions or backend
requests. Windows preparation does not run the Linux browser-widget CI tests.

Focused tests additionally cover explicit purchase recipients across stale
revisions, shared-accessory duplicate prevention, authoritative pricing,
legacy refresh rejection without charging, canonical receipt decoding, retained
profiles, provisional funds, character browsing without changing saved builds,
French enlarged text, and town-map labels/pins in portrait and landscape.
Rendered catalogue previews were inspected with loaded fonts and artwork.

## Android artifact

Canonical build: `release.ps1 -Action BuildAndroid -Environment dev -AndroidVersionCode 7`.
The fresh checkout's ignored Gradle wrapper was initialized first; the tree
remained clean. Android preparation reused all 3,750 client navigation graphs.

- Delivery: `.tmp/dev-release-20261110/app-dev-release-v7.apk`.
- Package: `com.example.rpg_runner.dev`; version `1.0.0-dev`, code `7`.
- SHA-256: `caaee106000c615d84a3985629a071792c5123d7c38147ae9b872243e4d95845`.
- Size: 189,555,621 bytes; minimum SDK 24, target SDK 36.
- Inspection passed for actual manifest/resources, dev Firebase identity,
  signature, required assets, native page alignment, and release symbols.
- The delivery copy's hash matches the inspected original. Delivery metadata is
  `.tmp/dev-release-20261110/delivery.json`.

This is artifact verification. No phone installation, linked Play Games run,
live purchase, or physical-device gameplay acceptance is claimed.

## Dev release

Deployment and issuance restoration completed. Pre-cutover read-only inspection found all 35 Functions
ACTIVE, all three queues RUNNING, no active runs, no stale settlement backlog,
and no invalid gold or unauthorized saved builds.

Cloud Build: `3ae33c96-472f-4d0f-ac92-7edee7a8f684`. Navigation is seeded from the
previous verified immutable dev image
`sha256:99b30cacbdb8f2867a0755278de90260347d2503af474f75b9b0f80a98afbaef`.
The final pack contains 93,770 graphs: 79,270 reused and 14,500 newly built for
the updated ranked routes. The strict final-image benchmark passed all forest
and field performance, determinism and sustained-progress gates at 36,000 ticks.

- Worker image:
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:883967a63ae494b667733d51e25c62224e110b7cd7a7c31db060cefc0005454f`.
- The prior issuer image had been removed from the registry. The canonical
  recovery rebuilt the prepared issuer with the explicit pause gate and
  verified its healthy serving revision before cutover.
- Fresh drain review at `2026-11-10T08:31:00Z`: no active runs, stale settlement
  or quarantined settlement. No cancellation or data reset was performed.
- Artifacts deployed at `2026-11-10T08:40:51Z`; issuance restored at
  `2026-11-10T08:47:37Z`. The dev baseline was verified and the source-bound
  maintenance record completed; mutation locks were released normally.
- All three expected current boards exist for `2026.11.10`.
- Final live readback at `2026-11-10T08:50:39Z`: all 35 Functions ACTIVE and all
  three queues RUNNING. Worker `replay-validator-00067-jj8` and issuer
  `runsessioncreate-00098-chz` are Ready with 100% traffic. The serving issuer
  has no `release-paused` gate; the worker serves the exact image above.
- Live empty unauthenticated requests to both ownership endpoints returned
  HTTP 401 / `UNAUTHENTICATED`. These probes did not submit a purchase.
- Prepared Practice Hosting artifact deployed; verified `main.dart.js` SHA-256:
  `a01f83762e63482c8935e90faf17a5939f2cf5123f2ee7d6668853ad49ebd854`.

Canonical release actions were `Inspect`, `BuildImage`, `ImageStatus`,
`PauseIssuance`, `Deploy -CutoverReady`, and `ResumeIssuance -CutoverReady`, all
with explicit `-Environment dev`, from the same clean frozen checkout.

## Evidence and remaining acceptance

Canonical evidence lives below the frozen checkout at
`.tmp/releases/rpg-runner-d7add/b3069af37cc2a89667bcd61f658f3812d5444e634b78b540f606788893f11523/`.
Working logs, initial-worktree records, focused tests and previews are in
`.tmp/town-services/`. Failed first-candidate evidence is retained separately.

Device authentication/App Check, a linked Play Games end-to-end run, live
purchase/settlement/leaderboard/ghost acceptance, full French editorial review,
and economy/playtesting remain separate from the automated and artifact checks.
