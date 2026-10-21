# Player progression and combat statistics

## Authority and data flow

Core records actual HP lost in `DamageSystem`'s post-mitigation callback.
`GameCore` adds it to `RunEndStats.damageDealt100` only when the target is an
enemy and `DamageCredit.player` owns the hit, or to `damageTaken100` when the
target is the player. Both fields use integer hundredths of HP. They do not
affect gameplay or score calculation.

The validator replays Core and includes a typed `ValidatedRun.playerRunStats`
payload with schema version 1 and both damage counts. This optional
`PlayerRunStats` contract rejects negative, fractional or non-JavaScript-safe
values; rejected runs cannot carry it. Old accepted results without it retain
their reward behavior and earn no XP, run count or damage totals. Existing
`ValidatedRun.codex` evidence still updates shared enemy defeats.

`settleAcceptedRunSession` reads the validator-owned score and stat evidence
inside its existing Firestore transaction. The canonical
`ownership_profiles.progression.playerProgress` subtree contains:

```json
{
  "schemaVersion": 1,
  "totalXp": 112,
  "acceptedRuns": 3,
  "runsByLevel": {"forest": {"practice": 1, "competitive": 1, "weekly": 1}},
  "damageDealt100": 12845,
  "damageTaken100": 1078
}
```

For each accepted result carrying version 1 player-stat evidence, settlement
adds `floor(score / 200)` XP, one run and both damage totals. The
`runsByLevel` map records the accepted run under its server-issued level and
mode in the same transaction. Existing accounts with a version 1 total but no
map retain the historical `acceptedRuns` total; those runs have no invented
level or mode breakdown. The Profile derives its Practice and Competitive
totals from the map without displaying the per-level breakdown or persisting
a second total. The separate `progression.enemyDefeats.byEnemy` map owns each
enemy's lifetime defeat count.
The existing `ValidatedRun.codex` field carries replay-derived per-enemy
evidence for compatibility, while `progression.codex` version 2 keeps only
Competitive best scores.
All additions must remain non-negative JavaScript-safe integers. Malformed
evidence aborts the whole transaction. Terminal run-session state fences
duplicate deliveries; canonical revision advances once with the reward and
progression write. Old Codex version 1 kills move once to the shared defeat map
at the first settlement carrying discovery evidence; a present shared map takes
precedence. The client projects old kills before settlement without storing a
second copy.
Missing player progression on an old account starts empty. Account deletion
removes all progression with canonical ownership.

## Client projection

Settlement also compares old and new XP-derived levels and atomically creates
25-gold system inbox gifts for new milestones. These are manually claimed,
separate from ordinary run gold, with no historical backfill. See
[system inbox](system_inbox.md) for delivery and claim invariants.

`ProgressionState.playerProgress` decodes the canonical subtree. The client
derives level from lifetime XP. For levels 1–29, the XP needed for level `L` to
`L + 1` is `round(100 × 1.24^(L - 1))`; round each cost before summing the
cumulative thresholds. Level 30 starts at 212,895 XP and is the display cap.
At the cap, `xpInLevel` and `xpForNextLevel` are zero, and the bar shows a full
`MAX LEVEL` state instead of dividing by a next-level cost. Settlement still
adds lifetime XP after the cap and continues all other run statistics; level is
not stored separately. The existing final-reward canonical refresh
updates both Profile and Hub. Library enemy gates read
`ProgressionState.enemyDefeats.byEnemy`; Profile sums that map for total defeats.
Neither the Library nor Profile stores a second kill count.
Developer Practice shows no hub XP bar and cannot settle progress.

Online Competitive and Weekly leaderboard reads add an optional `playerLevel`
to each returned top entry. The Functions reader looks up each entry's current
canonical `ownership_profiles.progression.playerProgress.totalXp` and applies
the same rounded thresholds as the client. Stored player bests and Top-10 views
do not copy account level because XP can change without a new best run. Missing
or unreadable progression omits `playerLevel`; the board still loads and the UI
shows a dash. The field is display-only and does not enter sorting, replay
validation, or the materialized Top-10 revision.

The hub captures lifetime XP when Run is pressed. When its route becomes current
again, `PlayerLevelBar` animates that visual value toward canonical
`ProgressionState.playerProgress.totalXp`; later canonical increases continue
from the currently displayed value. The bar derives each intermediate level
from lifetime XP, so crossing a threshold fills the prior level and begins the
next. The Profile bar and initial hub load display canonical progress
immediately. The UI's `UiProgressAnimator` owns only count interpolation and
ticker lifetime; `PlayerLevelBar` decides when to start and how to derive level
from the displayed XP. Animation state never changes account progress or the
server settlement flow.

## Compatibility and release

This feature changes run-result evidence and account progression, not replay
inputs, gameplay behavior or score rules. Deploy the Functions reader before
the validator writer and release the client with the coordinated workflow.
Historical accepted results are not backfilled. Focused checks cover Core
damage accounting, protocol validation and legacy omission, validator output,
atomic and duplicate settlement, XP thresholds and both UI surfaces.
