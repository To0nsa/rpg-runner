# Dev release — November 14, 2026

The owner-authorized game worktree was committed, deployed to dev and packaged
as Android APK 9. Issuance was restored at `2026-11-14T01:23:27.8271424Z`.
Final live inventory at `01:25:11Z` and integrity readback at `01:25:40Z` pass.
The separate parent repository's Brand/tabletop/website work was preserved.
Staging, prod, Play publication and account resets were outside this operation.

| Identity | Verified value |
| --- | --- |
| Frozen game commit | `d0563ac4ab3964e1c8665bb8c1a3d4bc4e548d5c` |
| Source digest | `54f6541c8e742215798a1c97baf581b240e770c272a773f24e459cf22a7aafb5` |
| Contract | `2026.11.14 / rules-v2 / score-v4 / ghost-v1` |
| Environment | `dev`, project `rpg-runner-d7add`, region `europe-west1` |
| Cloud Build | `6c83445c-9779-4d18-8d18-8cecc0d13a3f`, `SUCCESS` |
| Worker image digest | `sha256:0320cd8176a1765757b772b262200e618617dda30a7863dafe09440c016d03b4` |
| Worker revision | `replay-validator-00069-xtw`, Ready, 100% traffic |
| Restored issuer | `runsessioncreate-00104-nm4`, Ready, 100% traffic, pause override absent |
| Hosting | [dev Practice host](https://rpg-runner-d7add.web.app) |
| Published `main.dart.js` SHA-256 | `e976bc0d0fe529712a3ad3b4af95b157184e84fc69003894b43d44e6d99dcd9e` |
| Android | `com.example.rpg_runner.dev`, `1.0.0-dev`, code **9**, 197,583,909 bytes |
| APK SHA-256 | `c9f0c62705a31340cccd29cbd380a2251002b45a418710a94f509c28b24c6ecb` |
| Android navigation manifest | `fa574af6e6460615849ac24c1e8c01171778b6810bc920d66dd22c7c332dd791` |

The immutable image is under
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator`.
The inspected APK and matching delivery copy are retained at
`.tmp/dev-release-20261114/app-dev-release-v9.apk`. Actual packaged resources
match dev Firebase and Play Games. Inspection verifies min/target SDK 24/36,
three ABIs, 12 native libraries, 16-KiB ELF alignment, 3,740 navigation graphs
and the unchanged workstation debug signing certificate:
`001f8fe8d465d47b2aa1264fd8a00ac2221875aeef17ce1bfad5d1bf6d91f061`.
All three Dart symbol files and the R8 mapping are retained. Dev symbols were
not uploaded and no Play artifact was published.

Canonical actions used `tools/release/release.ps1 -Environment dev` from the
clean LF checkout `.tmp/release-checkouts/d0563ac4ab3964e1c8665bb8c1a3d4bc4e548d5c`:
Prepare, BuildImage, ImageStatus, BuildAndroid (`-AndroidVersionCode 9`), Inspect,
PauseIssuance, Deploy (`-CutoverReady`), Inspect and ResumeIssuance
(`-CutoverReady`), followed by final Inspect/readback. Preparation completed at
`00:37:56Z`; deployment completed at `01:17:36Z`. Reused components retain their
original provenance and current input/toolchain/artifact-match proof. Failed
preparations remain preserved separately.

| Verification scope | Actual result |
| --- | --- |
| Canonical local client | Clean analysis; 1,664 tests pass, one existing skip; optimized web build and Wasm compatibility dry run pass |
| Compiled web in Chrome | Current hub, Practice-only Options, readiness/start, timer and game-over pass; no browser exceptions or backend requests |
| Canonical local Core | Clean analysis; all 2,970 tests pass, including VM Campaign construction parity |
| Canonical local packages | Protocol 136, content 163 and terrain 25 tests pass; generated content/navigation revision checks pass |
| Functions/emulators | All 388 tests pass; production build passes; six offline inventory tests pass |
| Validator | Clean analysis; 367 tests pass, two skips; compiled AOT protocol probe passes |
| Shared tools/Admin | Clean analysis, generated backend catalog parity, all 12 Tool UI and seven Admin tests pass |
| Mocked release suites | PowerShell 7 and Windows PowerShell 5.1 each pass release 62, integration 121 and cache 59 checks; these are mocked checks |
| Instruction routing | `node tools/agents/check.mjs` passes all 37 guidance files |
| Exact final container, live Cloud Build | Strict 36,000-tick benchmark under one CPU / 512 MiB passes Field and Forest speed, deterministic outcome and sustained-progress gates |

BuildImage verified navigation provenance from previous dev build
`5887afd2-8465-4a96-9551-dc831a0a4224`, immutable image
`sha256:16ddacc34c3ad4ec244dd4130fdd2f39145c74233eb592faf0fcc96bd2108519`.
The current producer prepared 9,500 windows / 93,840 graph instances: **79,250
reused, 14,590 built** for the six changed ranked routes. Android reused all
3,740 client graphs. No valid pack was discarded.

Live review found an expired Campaign validation retry whose zero-gold provisional
grant lacked its mode binding. Upload finalization now uses the shared run-mode
definition; an emulator regression exercises real issuance, upload and repeated
finalization with one task and preserved Campaign identity. Inventory recognizes
boardless Campaign while retaining ranked-window checks. Full Core verification
also corrected two previously documented stale combat fixtures after reproducing
their exact failures and ordinary-combat trace on the original source; production
combat/navigation behavior was unchanged by those fixture corrections.

The previous issuer image had been removed from the registry. Canonical pause
recovered by rebuilding the prepared issuer with the explicit pause gate, then
verified the healthy serving revision. With issuance paused and the validation
queue fenced, the reviewed transaction cancelled **29** old-version blockers:
28 tickets without upload/reward/validated-run evidence and the one expired
Campaign retry. Plan SHA-256:
`71b2e7b985f265803e674342546646fe7908f56c01d1a1cb9683b67ecafd4506`.
Commit time: `2026-11-14T01:07:11.944143Z`. Transaction preconditions rechecked
document versions, linked-record absence and canonical ownership; validation
leases were fenced and only the malformed zero-gold grant was revoked. Readback
confirms canonical player data unchanged and zero accepted-run writes.

Final live readback confirms all **35 Functions ACTIVE**, all **three queues
RUNNING** and all **10 schedulers ENABLED**. Three `2026.11.14` boards are active,
three `2026.11.11` boards are disabled and no expected current board is missing.
All 101 sessions are terminal: 45 cancelled (16 prior + 29 reviewed), 22 expired
and 34 validated. The **34 accepted runs, 34 settled grants and 3,379 canonical
gold** are preserved; the remaining grant is `revoked_final` with zero gold.
There are no pending/quarantined settlements, identity/evidence/profile
inconsistencies or unauthorized selections. The verified baseline matches the
worker image and published JavaScript. Both the mutation lock and source-bound
cutover record are absent after canonical resume. Frozen source is clean and
the delivery APK still matches its inspected hash.

Phone installation and signed-in gameplay, replay/reward/leaderboard/ghost
acceptance, including retired-client rejection, were not performed. Targeted
Chrome widget suites still need the
Windows Flutter test-server CanvasKit routing issue resolved; compiled-artifact
Chrome smoke does not establish those suites. Physical ruler/monitor/native
interaction and device performance remain open in the
[shared runtime plan](../building/shared_gameplay_runtime.md) and
[Campaign acceptance checklist](../building/campaign/implementation.md).
The completed [operator checklist](../archive/2026-11-14/building/dev_release_2026_11_14.md)
is archived; broader acceptance plans remain active.

Ignored evidence is under the frozen checkout's
`.tmp/releases/rpg-runner-d7add/54f6541c8e742215798a1c97baf581b240e770c272a773f24e459cf22a7aafb5/`:
`release.json`, `cloud-build.json`, Android records/artifact/symbols, before/paused/
drained/pre-resume/final inventories, cancellation backup/receipt,
`post-resume-live.json` and `post-release-integrity.json`. Full operator logs and
the delivery copy are in `.tmp/dev-release-20261114/`; supplemental tool and Cloud
Build logs are in the frozen checkout's `.tmp/ops/`. Sensitive backups stay ignored.
