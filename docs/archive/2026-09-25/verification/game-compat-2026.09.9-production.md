# Forest content release `2026.09.9`

Release source: `61e2c30b`. The owner supplied regenerated runtime data and
explicitly requested deployment without tests. This revision removes ten ambient
enemy placements from Forest: four early, one easy and five normal chunks.
Terrain, rescue rules, NPC health and score tuning are unchanged.

Client, Functions and validator use gameplay `2026.09.9`; ranked rules/score/ghost
remain `rules-v2`/`score-v2`/`ghost-v1`, and replay/command format remains 1.
Older compatibility values do not select historical Core implementations.

## Artifacts and deployment

All artifacts were built from an isolated archive of the release commit with the
existing production App Check and Functions environment configuration.

- Cloud Build `d57c2118-2fc0-4de5-b4ec-e2c90388baaa` succeeded.
- Worker image digest:
  `sha256:e2716e59c3db8bb6577b917ab12769b0a9b2faf38d5779afcc6b76f152717aa7`.
- Cloud Run revision `replay-validator-00042-g9g` is Ready with 100% traffic.
  The immutable image also has the `production` retention tag. Existing runtime
  configuration, service account, queue routing and IAM were preserved.
- Hosting version `89b7fd842663c191` serves <https://rpg-runner-d7add.web.app>.
  Its fetched `main.dart.js` byte-matched the release build, contains
  `2026.09.9`, and has SHA-256
  `B1DFD4DA8E886EFC53D0AF75B1471066FBB9B4B33D17207ED1E4BD5A065888F0`.
- All 26 Functions updated successfully. `runSessionCreate` is ACTIVE at
  revision `runsessioncreate-00021-yoj`, updated
  `2026-09-25T01:01:18.748776895Z`. No supported-version environment override
  remains. Firestore rules/indexes were unchanged.

## Cutover and verification scope

Ticket issuance and both queues were paused during the compatibility switch.
The cutover inventory at `2026-09-25T00:57:31.940Z` contained zero active sessions
and 90 settled grants. No runs required cancellation and no historical rewards
or replay artifacts were deleted.

Issuance and both replay queues were restored. The final inventory at
`2026-09-25T01:02:58.85Z` still contained zero active sessions, 90 settled grants
and no pending settlement. All six expected current/next `2026.09.9` boards
exist. The new worker revision had zero error log entries. Private settlement
and Eventarc invocation permissions retain their existing service-account scope.

Functions, worker and web builds succeeded. Tests, analysis, benchmarks and
gameplay smoke runs were not executed for this release, as requested. Deployment
state and published artifact identity are verified separately; no gameplay or
performance validation is claimed for the new content.

No native app binary was distributed. Android/iOS installations need a rebuilt
client with the matching compatibility and generated content.
