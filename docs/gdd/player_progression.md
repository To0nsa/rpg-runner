# Player level and lifetime stats

Player level is an account-wide record of runs played, shared by both selectable
characters. Each newly reached level delivers a manually claimed 25-gold
[inbox gift](messages.md). Previously reached levels are not backfilled.
Level itself grants no combat stat bonus or direct leaderboard advantage.

Each accepted, replay-validated Practice, Competitive or Weekly run earns
`floor(validatedScore / 200)` XP. A zero-score run earns zero XP but still counts
as a played run. Developer Practice, pending runs and rejected runs earn none.
XP is awarded once after settlement, even if a submission is delivered again.

Level starts at 1. Advancing from level `L` (1–29) requires
`round(100 × 1.24^(L - 1))` XP. Each level cost is rounded before it is added
to the cumulative threshold, and surplus XP carries into following levels.
Level 30 begins at 212,895 lifetime XP and is the maximum. A 30,000-point run
earns 150 XP; level 19 to 20 costs 4,804 XP, about 33 such runs from an empty
bar. Validated runs keep adding to lifetime XP at level 30, while the bar stays
full and displays `MAX LEVEL`. The hub shows level and progress
on the same line as the player's name, with level and XP inside the bar. The
bar fills the available space before gold, battery and time at the far right
of the hub. After a run, the hub bar counts up from the XP shown before play to
the newly settled total, filling and resetting at each crossed level. If
validation finishes after the player returns, the bar fills when that XP
arrives. The Profile page repeats the bar and shows lifetime XP, Practice runs
played, Competitive runs played, enemies defeated, damage dealt and damage
taken.
Per-level run counts remain in account progress but are not shown on Profile.
Historical runs without a recorded mode remain in the account's accepted-run
total but do not appear in the displayed mode totals.

- Enemies defeated is the sum of the account's shared per-enemy defeat counts,
  including boss summons. Library discovery gates use those same counts.
- Damage dealt counts actual enemy HP removed by player-credited attacks after
  defenses and HP clamping. Allied damage and overkill are excluded.
- Damage taken counts actual player HP removed by hits and hazards. HP spent
  as an ability cost is excluded.

Damage displays in whole HP, rounded from stored hundredths. Existing Library
kills are preserved. XP, run count and damage totals begin with runs validated after
tracking is enabled; historical runs are not backfilled. The player level
and stats are descriptive, so score and gameplay tuning can evolve without
changing a previously earned level or replay outcome.
