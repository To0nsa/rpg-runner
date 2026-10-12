# Release verification: gameplay 2026.10.12

Status: prepared; image build and production cutover are in progress. Production
still runs 2026.10.11.1. The owner authorized deployment, requested focused
validation, accepted traversal failures and separately approved cancelling the
four reviewed unsubmitted old-version tickets after a fresh cutover recheck.

## Frozen source and authored changes

Frozen commit: `77525d318ca96c87ce2f4fe356d6b00bfa091baf`.
Source digest: `eac5b845203b2841c288bad61b13354bb655c56e86ee78d66e8c512c1489f2e4`.
Runtime and fixture changes match main `bca13b47`. The detached release adds
only its validation recipe and explicit exception record; main retains the normal
release recipe.

Field's eight active chunks and ground reference use Y=224. Its authored assembly
loops one early chunk and seven distinct easy chunks, with the first three chunks
suppressing enemies/encounters. The current rescue in `field_default_easy_004`
contains Huntress2 and Warrior. Forest retains all nine distinct hard Rocky Grove
chunks after Goddess, with the repaired `forest_rocky_grove_hard_003` exit landing.
Generated content admits 87 chunks, three levels, three parallax themes and three
terrain materials. See [level composition](../gdd/level_composition.md).

Client, Functions and worker share gameplay compatibility `2026.10.12`, with
`rules-v2`, `score-v4`, `ghost-v1` and replay/command formats 1 unchanged.

## Local preparation

Canonical preparation completed at 2026-10-12 21:16:57 UTC.

| Gate | Result |
| --- | --- |
| Focused client analysis/tests and release web build | 16 passed; build passed |
| Focused Core assembly and traversal-harness controls | 50 passed |
| Focused Functions compatibility, retirement and route-seed tests; build | 7 passed |
| Focused validator/replay/artifact tests and compiled AOT protocol probe | 102 passed; probe passed |
| Protocol analysis/tests | 44 passed |
| Content-pipeline analysis/tests | 98 passed |
| Terrain-material analysis/tests | 25 passed |
| Production dependency audit | No known vulnerabilities |
| Generated-content and navigation revision freshness | Passed |

The full client, Core, Functions and validator suites were omitted under the
owner's requested scope. Main's normal release recipe is unchanged. The detached
recipe hash prevents this focused evidence from satisfying the normal recipe.
Earlier preparation attempts failed on obsolete Field fixture assumptions and
were not recorded as passing releases. The fixtures now check the authored loop,
use a current flat chunk, and replay actual jump input over rocks. Rescue cases
at seeds 15/250 and 30/60 Hz require both current NPCs to survive and produce the
same server-authoritative 500 rescue points, rewards and score; client-supplied
inflated summaries remain ignored.

The broad generator fixture suite was stopped after its decoration, encounter
and compiled-trap probes passed; it was omitted from the final focused recipe.
Current-source generator dry-run freshness remained a required gate.

Client navigation: 3,720 graphs, 25,179,855 bytes, 38 declared routes and an
8-chunk horizon. This is an artifact inventory, not exhaustive route coverage.

Prepared `main.dart.js` SHA-256:
`9098548edfb43d6d717d44f96c96859619a1db2d2c4548d881676437c8e46665`.

### Separately recorded traversal diagnostics

At seed 42, Forest Grojib crossed the complete 85-chunk finite assembly, and
Field Unoco crossed its declared 32-chunk horizon. Field Grojib, Hashash and Derf
failed on chunk 8, `field_default_easy_007`, with no forward progress for 600
ticks. Their local X positions were 101.44, 109.94 and 113.44; failure ticks were
1414, 1418 and 1419 respectively. These are unresolved, owner-waived failures.
No movement capability, tolerance or runtime geometry was weakened to pass them.
The other seeds and full matrix were omitted. Pursuit diagnostics do not establish
player, spawn/combat, arena-boss, camera, rendering or performance acceptance.

## Image build

Cloud Build `1068079f-4923-413b-95e2-c051aa7bf0b2` started at
2026-10-12 21:18:10 UTC. Its final-image benchmark and immutable image identity
are pending.

## Pre-cutover live evidence

Read-only inventory at 2026-10-12 21:04:40 UTC found 280 session records:
226 validated, 26 cancelled, 24 expired and four issued old-version tickets.
All 226 accepted validations had settled reward grants. There was no pending or
quarantined settlement. The current release's six boards are not yet published.

The four-ticket candidate identity hash is
`eb4a98a74b1ed7dc58a276f6d45de2f98fe185441167f5ba0ab7b4910f4b9191`.
Cancellation has not yet been applied. The guarded operation requires healthy
paused issuance, the exact approved set, unchanged session versions/update times,
no upload/validation lease, no replay object and no reward or validation document.

Local evidence is in the frozen checkout's
`.tmp/releases/rpg-runner-d7add/eac5b845203b2841c288bad61b13354bb655c56e86ee78d66e8c512c1489f2e4/`.

## Remaining live acceptance

Image publication/benchmark, cutover, final live artifact checks and restoration
of issuance remain pending. Controlled signed-in Play Games issuance, replay
acceptance, once-only settlement, background wallet catch-up, leaderboard/ghost
playback and retired-version rejection are not yet verified by this release.
No native package has been built or installed. The prior web unsupported-services
startup limitation remains historical evidence until retested.
