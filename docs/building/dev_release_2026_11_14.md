# Dev release — November 14, 2026

The owner authorized committing the game worktree, deploying the current game to
dev and building its matching Android APK. Cancellation of blocking dev tickets
is authorized if needed. Account resets, staging/prod and Play publication are
outside this release.

- [x] Inspect the game worktree, existing evidence and release instructions.
- [x] Select coordinated scope; advance the matching gameplay tuple to
      `2026.11.14 / rules-v2 / score-v4 / ghost-v1` and refresh ranked seeds.
- [ ] Review and commit the complete Campaign, shared-runtime and UI worktree.
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

Device installation and signed-in gameplay/replay/reward/leaderboard/ghost
acceptance require a device; packaging and live service verification do not
establish those results. Record any unrun checks explicitly.
