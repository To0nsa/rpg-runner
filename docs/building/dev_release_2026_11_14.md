# Dev release — November 14, 2026

The owner authorized committing the game worktree, deploying the current game to
dev and building its matching Android APK. Cancellation of blocking dev tickets
is authorized if needed. Account resets, staging/prod and Play publication are
outside this release.

- [x] Inspect the game worktree, existing evidence and release instructions.
- [x] Select coordinated scope; advance the matching gameplay tuple to
      `2026.11.14 / rules-v2 / score-v4 / ghost-v1` and refresh ranked seeds.
- [x] Review and commit the complete Campaign, shared-runtime and UI worktree
      (`33aebb79`; follow-up replay fixture correction below).
- [ ] Freeze a clean LF release checkout; complete canonical Prepare gates,
      reusing only matching component evidence.
- [ ] Build and verify the immutable worker image, seeded from the verified
      previous dev image's navigation pack.
- [ ] Build and inspect a matching dev Android APK with the next local dev code.
- [ ] Inspect live dev, pause issuance, review drain and cancel only blocking
      tickets if necessary; preserve accepted runs, settlement and player data.
- [ ] Deploy Functions, worker and Hosting; verify boards, resume issuance and
      inspect final live state, locks and checkout cleanliness.
- [ ] Record source/artifact identities, actual checks and acceptance limits.

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
