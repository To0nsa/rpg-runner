# Production release `2026.09.10`

Deployed October 1, 2026 to `rpg-runner-d7add` in `europe-west1`, from frozen
commit `6bfda4c8`. Source fingerprint:
`99cd2e64da53b257d1d2aa0ec8fa2e6ddd59f13f1c56392dedff6f5863a31471`.
The client, Functions and validator agree on gameplay `2026.09.10`,
`rules-v2`, `score-v2`, `ghost-v1`, and replay/command format 1.

This commit includes slower camera pacing, the early Forest prefab/layout
refinement and generated content, and the backend transitive dependency fixes.
Preparation ran in an isolated detached worktree because gameplay edits appeared
during the first preparation. That first attempt failed its source fence and
its artifacts were discarded for deployment. The owner instructed us to ignore
the new projectile edits. Auto aim commits `242aad28`/`61e996c0`, later authored
content edits, and subsequent workflow commits are excluded from these runtime
artifacts. Pending deterministic gameplay needs a new compatibility version
before another client/worker cutover.

## Artifacts

- [Cloud Build `ff639a57-362d-425b-a25c-ef7ab7dddca8`](https://console.cloud.google.com/cloud-build/builds/ff639a57-362d-425b-a25c-ef7ab7dddca8?project=964001571974)
  succeeded at `2026-10-01T19:44:24.971668Z`.
- Immutable worker image:
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:74182b3407b12f546049663d24d902f2a451d73c0c7fc7a1fde7bc8426efaf6a`.
- Worker revision `replay-validator-00043-qjg` is Ready with 100% traffic,
  one CPU and 512 MiB. The exact image has the `production` retention tag.
- Hosting release `1790885164174000`, version `0b38fe8d671eea9e`, published at
  `2026-10-01T20:06:04.174Z`, serves [the web client](https://rpg-runner-d7add.web.app).
  Fetched `main.dart.js` byte-matched the prepared client, with SHA-256
  `12909B3EB336815436B7E29B122684E84FC070ECB969DFA9C36E1D9BF98D0BB0`.
- All 26 Functions were deployed and reported ACTIVE. The restored issuer is
  `runsessioncreate-00026-56w`, Ready with 100% traffic, image digest
  `sha256:c478f71afae0523cbd450da54c569436964ebacad3da217cab71be389ab943b2`.
  Its temporary supported-version override is absent; compiled defaults accept
  the matching release.
- Firestore rules publication succeeded; all 11 composite indexes are READY.

## Preparation and container benchmark

Frozen dependencies resolved under Flutter 3.47.1/Dart 3.13.1, Node 24.16.0
and pnpm 11.22.0. Generated-content freshness passed for 54 chunks, three
included levels, three parallax themes and three terrain materials.

| Check | Result |
| --- | --- |
| Functions production dependency audit/build | Zero reported vulnerabilities; build passed |
| Functions Firestore emulator tests | 212 passed |
| Root Dart analysis and Flutter tests | Analysis clean; 869 passed |
| Core analysis/tests | Analysis clean; 707 passed |
| Shared protocol analysis/tests | Analysis clean; 44 passed |
| Content pipeline analysis/tests | Analysis clean; 81 passed |
| Validator analysis/tests | Analysis clean; 154 passed |
| Compiled AOT protocol-rejection probe | Passed |
| Release web build and final artifact/source fences | Passed |

Cloud Build ran the exact final worker image with `--cpus=1 --memory=512m`
and `benchmark --ticks=36000 --strict` before publication. Each level replayed
36,000 command frames, representing 600 seconds at 60 Hz:

| Level | Elapsed seconds | Multiple of real time | Deterministic outcome |
| --- | --- | --- | --- |
| Forest | 0.907446 | 661.20x | Passed |
| Field | 0.909053 | 660.03x | Passed |
| `new_level` | 0.882269 | 680.06x | Passed |

All nine benchmark gates passed. The fixture uses normal included terrain
streams without enemy streaming; these timings do not establish full combat,
spawn or device performance. No additional targeted enemy traversal run was
requested; the standard release suites were used. Editor tests and device
integration/performance tests were outside this release preparation. Cloud
Build benchmarking does not establish completion of separate CI image
vulnerability/configuration smoke gates. Firebase emitted an SDK upgrade
advisory; the frozen, tested dependency versions deployed successfully.

## Issuance pause recovery and cutover

The first environment-only issuer update failed because its old image tag was
missing. The preceding ready revision's digest was also absent from Artifact
Registry. The Firebase-managed `gcf-artifacts` repository reported its existing
one-day DELETE policy. The failed desired template contained the pause marker,
but old traffic was still serving, so it was not treated as a successful pause.

Recovery rebuilt only the prepared issuer with
`RUN_SUPPORTED_GAME_COMPAT_VERSIONS=release-paused` explicitly in its deployment
environment. The local project environment file was restored byte-for-byte in
finally. The ready revision and its 100% live traffic were checked before
recording the pause at `2026-10-01T19:59:36.686636Z`.

The pre-cutover inventory at `2026-10-01T19:59:56.779Z` contained 195 terminal
sessions: 171 validated, 21 expired and three previously cancelled. All 171
accepted validations had settled grants. There were no active runs, pending or
quarantined settlements, or active account deletion requests. No runs were
cancelled and no player data, rewards or replay artifacts were reset for this
release.

Both queues were paused after the drain. All Functions except the issuer and
rules/indexes deployed first; private settlement/Eventarc invocation bindings
were restored before the matching worker. Worker deployment reapplied the
existing prefix-scoped Storage IAM, queue routing/retry policies and build/image
retention policies. Board maintenance created all six expected current/next
`2026.09.10` boards. Hosting was published, then live image/traffic and client
bytes were verified before queues and the matching issuer were restored.
Issuance restoration completed at `2026-10-01T20:10:16.5681145Z`.

The follow-up workflow fix, `be28949e`, pins an available immutable issuer
image, automates explicit paused rebuilding when the old image is missing,
verifies the healthy serving revision, suppresses inherited Firebase debug
responses, and resolves the editor's independent dependencies in fresh
checkouts. Its 24 helper checks and 20 mocked integration checks passed under
Windows PowerShell 5.1 and PowerShell 7. These mocked checks are separate from
the manual recovery performed during this production deployment.

## Live verification and remaining checks

At `2026-10-01T20:11:54.0257822Z`, the verified worker and issuer each served
100% traffic, all 26 Functions were ACTIVE, and all 11 indexes were READY.
Both replay queues were RUNNING with their expected `/tasks/validate` and
`/tasks/project` routes and the task-dispatch OIDC identity. Authenticated
worker `/live` and `/ready` returned `ok` and `ready`; an anonymous health
request returned HTTP 403.

The worker, immediate settlement dispatcher and both Eventarc targets had
their required service-account invokers and no public invoker bindings.
The final read-only inventory at `2026-10-01T20:12:12.996Z` retained the 195
terminal sessions and 171 settled grants, zero pending/quarantined settlement,
and all six expected boards. Existing profile, ownership, leaderboard and
ghost consistency checks remained clean. Two historical terminal tickets retain
their previously recorded missing-window evidence; their canonical board
matches were unchanged.

Linked Play Games smoke remains outstanding: fresh Practice/ranked tickets,
uploaded replay acceptance, once-only settlement, leaderboard totals,
generation-pinned ghost playback, and live retired-version rejection. No
anonymous account or fabricated ticket was used to claim those checks. No
native Android/iOS binary was distributed, and monitoring alert-policy
publication was outside this coordinated release. See the
[active checklist](../building/rescue_release_operations.md).

Local logs, benchmark JSON, release checkpoints and PII-free inventory snapshots
are retained beneath `.tmp/deploy-2026-09-10/.tmp/releases/rpg-runner-d7add/`
and the source fingerprint above. Credentials are not included in this record.
