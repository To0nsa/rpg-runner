# Leaderboard player level production release

Deployed October 18, 2026 UTC to `rpg-runner-d7add` / `europe-west1` through
the coordinated Functions, Cloud Run worker, and web Hosting workflow. Normal
ticket issuance and both replay queues are restored. The ranked tuple remains
`2026.10.17` / `rules-v2` / `score-v4` / `ghost-v1`.

## Frozen source and preparation

The deployed source is detached commit `1a8e899c69d3d078f26ea33168497a21afaffff5`
with source digest
`2798d1b462fdc0111363f97dc59d3f761116e80c81469d3d3c8e1d37e914f239`.
Its diff against the preceding production source `21b60c70` contains only 12
leaderboard-related contract, Functions, Flutter, test, and documentation files.
Later mainline gameplay and XP tuning were excluded. The level calculation
matches the deployed linear XP thresholds. The online Competitive and Weekly
boards show an optional `Lvl` column next to the player name, populated from
the current canonical player XP when each board is loaded.

`Prepare` passed all ten required components: Functions emulator tests and
build, client analysis and 1,256 Flutter tests, web build, Core and shared
package checks, validator analysis and 270 tests with an AOT protocol probe,
and generated-content freshness. Functions reported 230 passing tests; the
shared protocol reported 55. The production dependency audit found no known
vulnerabilities. Verified cache entries were reused only for unchanged inputs.

Cloud Build `151c4339-65d6-4df5-b40a-68910d25cd20` ran from 00:14:28 to
01:25:17 UTC. It prepared 9,500 windows and 93,840 navigation graphs, built
the final worker image, and passed all six strict 36,000-tick benchmark gates
at one CPU and 512 MiB. The immutable image is
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:0856c7f6d3c79b53f819660610da3326d248103a6feb35b3e0ebcea094bf4437`.

## Drain and cutover

Read-only inspection before pause found one issued `2026.10.17` ticket, 333
accepted validations with 333 settled grants, no pending or quarantined
settlement, and all six expected current/next boards. Ticket issuance was
paused at 05:35:22 UTC while both replay queues continued draining. A fresh
paused-state review found exactly the same ticket with no upload lease, replay
object, validated run, or reward grant. Under the owner's separate approval, a
guarded transaction cancelled only that unsubmitted ticket at 05:36:33 UTC.
Its reviewed candidate-set SHA-256 was
`64c51cbeca20b237377a01d99d6dbe47e4d9f99cdf8707a49e233522adcdd6b1`.
No profile, validated run, or reward was changed or deleted. The following
inventory had zero active sessions and the same 333 settled grants.

The workflow deployed 25 non-issuer Functions and Firestore rules/indexes by
05:41:44 UTC, worker revision `replay-validator-00057-7jb` by 05:45:01 UTC,
and Hosting by 05:45:31 UTC. All six expected boards were present before both
queues and issuance were restored at 05:49:27 UTC. Healthy issuer revision
`runsessioncreate-00068-jdn` serves 100% without the temporary pause gate.

Final inspection at 05:50:12 UTC found all 26 Functions ACTIVE, both queues
RUNNING, the worker serving 100% on the exact image above, and no missing
expected boards or pending/quarantined settlement. All 333 accepted validations
and settled grants remained. Two new tickets were issued after resumption.
The live `main.dart.js` SHA-256 matched the prepared artifact:
`f01d729320da556ea5bee59f43c15da63fbef9926439f78bdd36335a982bccbe`.
The verified production baseline was updated to these worker and web bytes.

Release manifests, logs, cancellation receipts, inventories, and live web bytes
are under the frozen checkout's
`.tmp/releases/rpg-runner-d7add/2798d1b462fdc0111363f97dc59d3f761116e80c81469d3d3c8e1d37e914f239/`.

## Remaining verification

Controlled signed-in Play Games leaderboard display, accepted replay,
once-only settlement, wallet catch-up, ghost playback, and target-device
performance were not exercised during this release. The Functions tests cover
the level enrichment and Flutter tests cover the column, but the live level
value has not been observed through a linked Play Games account. No native
Android or iOS package was built or distributed. The
[release checklist](../building/rescue_release_operations.md) retains these
checks.
