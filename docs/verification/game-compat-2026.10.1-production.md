# Production release `2026.10.1`

Deployed October 2, 2026 to `rpg-runner-d7add` in `europe-west1` from frozen
commit `0cb94b94d2ab56c1d616db8333862eab09fc569f`. Source fingerprint:
`3fe3bf0c6c57276bfa8dbc4056fef88fb81286ddaff5f4a8b3fe079976cee6c4`.
The client, Functions and replay worker agree on gameplay `2026.10.1`,
`rules-v2`, `score-v2` and `ghost-v1`; replay and command formats remain 1.

Compared with the preceding [production release](game-compat-2026.09.10-production.md),
this coordinated cutover includes projectile auto aim, NPC section guards,
Forest grove chunks and collision/layout repairs, and refreshed generated
terrain and chunk patterns. Release tooling and documentation also changed.
Four untracked `assets/images/Fogo_*.png` files appeared in the main checkout
after the frozen checkout was created; they were excluded from these artifacts.

## Preparation and artifacts

- [Exact-commit release preparation CI](https://github.com/To0nsa/rpg-runner/actions/runs/37043322271)
  passed all component jobs. `ImportCI` and `Prepare` verified the component
  evidence, source/environment tuple, artifact bytes, generated-content
  freshness and a fresh production dependency audit with no known
  vulnerabilities. The prepared web and Functions builds were reused without
  rerunning unchanged checks.
- Cloud Build `d52e5f02-aaf7-414f-b5f3-afba833265b2` succeeded. Its exact
  image passed the strict 36,000-tick, one-CPU/512-MiB replay benchmark for
  Forest, Field and `new_level`: all nine speed and deterministic-outcome gates
  passed. This fixture does not establish signed-in gameplay or crowded combat
  performance.
- Immutable worker image:
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:1f9a28bbc693123e389732e40ca760379a65208678023dc2a1a8fd2ca2fa41df`.
  Revision `replay-validator-00044-mx2` is Ready and serves 100% of traffic.
- Hosting release `1790966820614000`, version `b35a5c0cb54f4ac2`, was
  published at `2026-10-02T18:47:00.614Z`. The fetched live `main.dart.js`
  byte-matched the prepared build at SHA-256
  `60335FE0C9B6F065E5A2DC70941349BD30060C6E33357C74D6F85404F25D7ECB`.

## Drain and cutover

Normal ticket issuance was paused while both replay queues kept running.
The pre-cutover inventory found six issued `2026.09.10` sessions. Each was
unchanged since issuance and had no upload state, validated replay or reward
grant. The owner explicitly authorized cancelling those six sessions to
continue deployment. One atomic Firestore commit at
`2026-10-02T18:38:54.717247Z` changed only those six records to the terminal
`cancelled` state, with update-time preconditions and an explicit cutover
message. Their records were preserved; no rewards, replay artifacts or other
player data were reset. The subsequent read-only inventory confirmed zero
active runs and zero stale or quarantined settlements.

The release workflow then paused both queues and deployed all exported
Functions except `runSessionCreate`, Firestore rules and indexes, private
invocation bindings, the immutable worker, queue routing, board maintenance
and Hosting. After all six expected current/next boards existed and worker/web
identity checks passed, it resumed both queues and deployed `runSessionCreate`.
Issuance was restored at `2026-10-02T18:51:16.7030696Z`.

## Live verification and remaining checks

The final read-only inventory at `2026-10-02T18:52:13.444Z` showed 206
retained sessions: 176 validated, 21 expired and nine cancelled. All 176
reward grants were settled; there were no active runs, stale pending
settlements or quarantined settlements. All six expected `2026.10.1`
current/next boards existed. Both replay queues were RUNNING.

All 26 Functions reported ACTIVE, and all 11 composite indexes were READY.
The issuer revision `runsessioncreate-00029-xr4` was Ready with 100% traffic
and no temporary supported-version override. The verified production baseline
records the immutable worker digest, live web hash and ACTIVE Functions
identity.

Linked Play Games production smoke remains outstanding: fresh Practice and
ranked tickets, uploaded replay acceptance, once-only settlement, leaderboard
totals, generation-pinned ghost playback and retired-version rejection. No
anonymous or fabricated ticket was used to claim those checks. Native
Android/iOS distribution was outside this release.

Local preparation, Cloud Build and production checkpoints are retained under
`.tmp/release-checkouts/0cb94b94d2ab56c1d616db8333862eab09fc569f/.tmp/releases/rpg-runner-d7add/3fe3bf0c6c57276bfa8dbc4056fef88fb81286ddaff5f4a8b3fe079976cee6c4/`.
