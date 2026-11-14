# Dev release — November 14, 2026

Status: completed. The [release record](../../../verification/dev-release-2026-11-14.md)
contains final identities and live readback. Earlier checkpoints below retain
the preparation findings and their resolutions.

The owner authorized committing the game worktree, deploying the current game to
dev and building its matching Android APK. Cancellation of blocking dev tickets
is authorized if needed. Account resets, staging/prod and Play publication are
outside this release.

- [x] Inspect the game worktree, existing evidence and release instructions.
- [x] Select coordinated scope; advance the matching gameplay tuple to
      `2026.11.14 / rules-v2 / score-v4 / ghost-v1` and refresh ranked seeds.
- [x] Review and commit the complete Campaign, shared-runtime and UI worktree
      (`33aebb79`; follow-up replay fixture correction below).
- [x] Freeze a clean LF release checkout; complete canonical Prepare gates,
      reusing only matching component evidence.
- [x] Build and verify the immutable worker image, seeded from the verified
      previous dev image's navigation pack.
- [x] Build and inspect a matching dev Android APK with the next local dev code.
- [x] Inspect live dev, pause issuance, review drain and cancel only blocking
      tickets if necessary; preserve accepted runs, settlement and player data.
- [x] Deploy Functions, worker and Hosting; verify boards, resume issuance and
      inspect final live state, locks and checkout cleanliness.
- [x] Record source/artifact identities, actual checks and acceptance limits.

The initial offline Plan correctly rejected changed deterministic gameplay under
the deployed `2026.11.11` tuple. The tuple and route seeds are being updated
together before freezing source. Existing task verification is under
`docs/verification/` and the Campaign/shared-runtime plans. The canonical release
evidence will remain under the frozen checkout's ignored `.tmp/releases/`.

The first frozen preparation passed client-source and validator analysis and the
current production dependency audit, then test analysis found the ghost replay
fixture's missing `PlayerAttackExecutedEvent` case. The comparison now includes
its tick, slot and ability rather than discarding the new event. That failed
preparation remains preserved; the corrected candidate will run the gates again.
The previous verified dev APK is code 8, so this release allocates dev code 9.

The second frozen preparation passed all 387 Functions emulator tests, the
production build, five inventory tests, validator analysis/367 tests (two skips)
and the compiled protocol probe. The full client suite found three UI fixture
failures: the compact character test had not loaded the application fonts, and
the two town-navigation cases lacked `isCharacterUnlocked` on their fake state.
All 42 affected screen tests pass after those fixture corrections; the product
layout is unchanged. Matching backend/validator component evidence is reusable.

Live inspection found 28 unsubmitted tickets and one expired Campaign ticket
retrying validation (206 observed attempts), with a zero-gold provisional grant
and no validated-run record. Submission decoding omitted Campaign from its local
mode list, so the provisional grant lacked the worker-required mode binding.
Finalization now uses the shared mode definition; a real issuance/upload/retry
regression passes. All 388 Functions emulator tests and six offline inventory
tests pass. Inventory also recognizes boardless Campaign tickets while retaining
missing-window warnings for ranked/unknown modes. This backend correction does
not change client or worker inputs, so their matching evidence remains reusable.

Before cancellation, the live baseline has 34 accepted runs and settled grants,
3,379 canonical gold and zero pending/quarantined settlement. Cancellation tooling
is prepared in ignored `.tmp/dev-release-20261114/`; it requires the environment
mutation lock, matching cutover owner and a healthy paused issuer, and atomically
fences reviewed tickets/revokes only the zero-gold provisional grant. Accepted
evidence and canonical player data are protected by transaction read checks.

Client checks from `36410db5` passed all 1,664 tests (one existing skip). The web
artifact compiled in 353.3 seconds and its Wasm compatibility dry run passed.
Its browser gate then exposed retired hub labels in `web_smoke.mjs`. The corrected
gate recognizes Local practice and the separate Runner/Campaign actions, and
passes real Chrome hub, Options, readiness/start and game-over checks with no
browser exceptions or backend requests against the unchanged compiled artifact.
The release, integration and cache suites pass on both PowerShell 7 and Windows
PowerShell 5.1 (62, 121 and 59 checks per shell). The shared preparation recipe
fingerprint includes this script, so a new frozen preparation is required; the
failed prior preparation remains preserved.

The corrected-recipe candidate `3646d904` passed all client/backend/validator
checks, the optimized web build, Wasm dry run and real-artifact Chrome smoke.
Core analysis then encountered VM-only mirrors references in the full-state
Campaign construction parity test. The unchanged test passes both characters on
the Dart VM; only those five platform-specific analyzer diagnostics are now
scoped to their individual references. Full Core analysis is clean and both VM
cases still pass. No assertions, projections, runtime source or shared release
recipe changed, so matching completed components remain reusable. The final
preparation must still run the complete Core suite and remaining package gates.

The first complete Core run passed 2,968 cases and reproduced the two stale
fixtures already documented in `derf-running-target-2026-11-13.md`. An isolated
checkout of the original `69a250be` source reproduces both failures and the exact
same 939-tick ordinary-combat digest as the current Campaign source:
`0b1ac845386776ebab20caeaa122af6eb4745b8fc83f401a39c204ac4e802671`.
The target-identity fixture now uses 36 units inside Grojib's existing 34–40
commit band and explicitly checks the selected NPC. The golden retains all
roster, transformation, facing and complete-trace checks, with the reviewed
checksum and duration. All 139 focused combat cases pass, as does a second-process
trace repeat. No production combat or navigation code changed.

Device installation and signed-in gameplay/replay/reward/leaderboard/ghost
acceptance require a device; packaging and live service verification do not
establish those results. Record any unrun checks explicitly.

Final candidate `d0563ac4` completed canonical Prepare at
`2026-11-14T00:37:56Z`, source digest
`54f6541c8e742215798a1c97baf581b240e770c272a773f24e459cf22a7aafb5`.
All 2,970 Core tests and the remaining protocol/content/terrain/freshness gates
pass. Canonical reuse verified the matching client/backend/validator evidence
and artifact bytes. Supplemental shared presentation analysis, generated Admin
catalog parity, all 12 Tool UI tests and all seven Admin tests pass. Cloud Build
`6c83445c-9779-4d18-8d18-8cecc0d13a3f` is seeded from the previous verified dev
image; Android code 9 reused all 3,740 client navigation graphs. Neither result
is considered complete until its required artifact verification finishes.

Android code 9 completed at `2026-11-14T00:52:37Z`: package
`com.example.rpg_runner.dev`, version `1.0.0-dev`, min/target SDK 24/36, correct
dev Firebase/Play Games resources and unchanged workstation debug certificate.
All three ABIs, 12 native libraries, 16-KiB ELF alignment, all 3,740 graphs and
the navigation manifest hash passed inspection. The 197,583,909-byte delivery
copy `.tmp/dev-release-20261114/app-dev-release-v9.apk` matches SHA-256
`c9f0c62705a31340cccd29cbd380a2251002b45a418710a94f509c28b24c6ecb`.
All three Dart symbol files and the R8 mapping are retained with the evidence.
The frozen checkout remains clean. No phone install or Play publication occurred.

Cloud Build `6c83445c-9779-4d18-8d18-8cecc0d13a3f` succeeded after preparing
9,500 navigation windows / 93,840 graph instances (14,590 built, 79,250 reused).
The exact final container passed all strict 36,000-tick, one-CPU/512-MiB gates
for Field and Forest. Its immutable image digest is
`sha256:0320cd8176a1765757b772b262200e618617dda30a7863dafe09440c016d03b4`.

The previous issuer image had been removed from the registry. Canonical
PauseIssuance rebuilt the prepared issuer with the explicit pause gate and
verified the healthy revision serving all traffic. The source-bound cutover
record remains owned by this candidate. Paused inventory confirmed the same
29 blockers and protected player baseline. Under the dev mutation lock, plan
`71b2e7b985f265803e674342546646fe7908f56c01d1a1cb9683b67ecafd4506`
cancelled 28 unsubmitted tickets and the one reviewed expired Campaign retry at
`2026-11-14T01:07:11.944143Z`. The transaction fenced validation leases and revoked
only its malformed zero-gold provisional grant. Readback confirms all 29 terminal,
no accepted-run writes and byte-structure equality of canonical player data.
Sensitive full backups and the commit receipt remain in ignored release evidence.

Deployment completed at `01:17:36Z`; canonical resume restored issuance at
`01:23:27Z`, saved the verified worker/Hosting baseline and cleared the matching
cutover record. Final inventory at `01:25:11Z` confirms 35 active Functions,
three running queues, ten enabled schedulers, three active current boards and
three disabled old boards, no active sessions or settlement backlog, and all
34 accepted runs / settled grants / 3,379 gold preserved. Issuer revision
`runsessioncreate-00104-nm4` is healthy at 100% traffic with no pause override;
worker `replay-validator-00069-xtw` serves the exact verified image at 100%.
Final marker/integrity readback confirms no mutation lock or cutover record,
a clean frozen checkout and a matching delivery APK hash.

The owner-authorized commit/deploy/build operation is complete. Broader device,
signed-in and physical/browser-widget acceptance remains with the active
Campaign and shared-runtime plans. Final artifact identities, command scopes,
results and limitations are in the
[November 14 release record](../../../verification/dev-release-2026-11-14.md).
