# Capsule Target Narrow Phase Production Rollout — August 12, 2026

## Decision

The repository owner authorized the hard `rules-v2` cutover and explicitly
accepted abandoning the one remaining pre-cutover `rules-v1` session. The
release does not retain a historical AABB-combat simulator. New ranked board
selection and validation use `rules-v2`; an old `rules-v1` submission is
rejected and its session may expire through normal cleanup.

## Release identity

- Reviewed release source: `7d1ef5d9196b0272e5be6e0877a67cfeabf10b63`.
- Validator Cloud Build: `55a5d1a6-27fb-413a-a962-1727d1172576`.
- Validator image tag:
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator:capsule-rules-v2-20260812-223208`.
- Immutable validator digest:
  `sha256:094c2b4009ea25c5baf2e737a98a00364a887a7c19ed1cb585e66a2b628c3580`.
- Cloud Run revision: `replay-validator-00035-8vn`, Ready and serving 100%.
- Function revisions:
  - `runSessionCreate`: `runsessioncreate-00016-wug`;
  - `runBoardsLoadActive`: `runboardsloadactive-00014-jum`;
  - `leaderboardLoadActiveBoardData`:
    `leaderboardloadactiveboarddata-00015-zet`;
  - `leaderboardBoardMaintenance`:
    `leaderboardboardmaintenance-00011-mur`.
- Firebase Hosting version: `69b8f5b6a39516dc`, released at
  `2026-08-12T19:42:49.955Z`.
- Served `main.dart.js` SHA-256:
  `a6fe439d43cf5b5c178ada6b64acbac0de075973e87018264364f3579c06a573`,
  exactly matching the local release bundle and containing game compatibility
  `2026.08.0` plus the production App Check configuration.

The operator-only release drill initially selected boards by game compatibility
alone. Preserving a same-window `rules-v1` board made that query ambiguous after
the cutover. Commit `fe68da88` changed the drill to select the complete managed
ruleset/score/ghost tuple before the production canary ran. The helper passed
Node syntax validation and the Functions TypeScript build; it is an operator
tool and required no Functions redeployment.

## Ordered deployment

1. Built the validator from a detached clean worktree so concurrent editor and
   chunk changes could not enter the release.
2. Deployed the immutable validator digest with the checked-in Cloud Run, IAM,
   probe, task-queue, and retention policy. Revision `00035-8vn` became Ready at
   `2026-08-12T19:34:07Z`.
3. Built and deployed Firestore indexes plus the four tuple-aware Functions.
   Firebase reported four successful updates and zero errors by
   `2026-08-12T19:39:11Z`.
4. Triggered board maintenance immediately. The production inventory found all
   six expected current/next `rules-v2` boards, including three active-current
   boards, with zero missing manifests or identity/window mismatches.
5. Built Flutter web with the production App Check key, verified the compatibility
   marker and local bundle hash, deployed Hosting, then downloaded the live
   bundle and proved exact SHA-256 equality.

## Live canary

The corrected operator drill created one disposable anonymous account and 16
isolated fixtures. The nine compatibility cases produced their expected live
results:

- current `2026.08.0` plus `rules-v2` returned HTTP 202, validated, and settled;
- retired game compatibility was rejected as
  `game_compat_version_unsupported`;
- retired ruleset, score, and ghost tuples were rejected as
  `board_compat_version_unsupported`;
- ticket identity, loadout digest, board binding, and board-window mutations
  reached their exact terminal reasons with revoked grants.

The accepted run projected onto its rules-v2 leaderboard, published an active
ghost, and a repeated validator request preserved the session, grant,
player-best source, and ghost digest. The owner waived a live action-sequence
canary spanning melee, projectile, and mobility contacts; the locally validated
seeded Core and validator fixtures remain the exact capsule-combat behavior
gate.

Cleanup used the deployed resumable account-deletion worker. It completed its
late-write-protected final pass after 366 bounded stage attempts, deleted the
Auth identity, and scrubbed local credentials. The independent verifier found
zero residual session, validation, grant, profile, leaderboard, ghost,
idempotency, or Storage objects for the canary UID.

## Final production audit

At `2026-08-12T20:14:29.805Z`:

- all six expected rules-v2 current/next boards existed; three were in their
  active windows;
- the preserved rules-v1 and rules-v2 partitions had no identity or window
  mismatch and old projections were not exposed through the rules-v2 tuple;
- both validation and projection task queues were empty;
- run identity, board-window, terminal-evidence, settlement, player-best-source,
  and ghost-source mismatch counters were all zero;
- active and retryable deletion counts were zero;
- the rollout log query found no error-severity records for the validator or
  the four deployed Functions since build start.

One issued pre-cutover `rules-v1` session remained active in storage. This is
the session the owner deliberately abandoned; it is not accepted by the new
validator and does not block rules-v2 issuance, boards, leaderboards, or ghosts.
