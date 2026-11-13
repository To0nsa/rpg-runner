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

Device installation and signed-in gameplay/replay/reward/leaderboard/ghost
acceptance require a device; packaging and live service verification do not
establish those results. Record any unrun checks explicitly.
