# Player level and lifetime stats

Player level is an account-wide record of runs played, shared by both selectable
characters. Each newly reached level delivers a manually claimed 25-gold
[inbox gift](messages.md). Previously reached levels are not backfilled.
Confirmed account level unlocks Build 2 at level 5 and Build 3 at level 12 for
both characters. Build 1 is always available. These are saved configurations;
level itself grants no combat stat bonus. Developer Practice shows the same locks.
Locked build buttons show a lock and required level together instead of their
name. Each unlocked build can be named with up to 28 visible characters.

Each accepted, replay-validated Practice, Competitive or Weekly run earns
`floor(validatedScore / 200)` XP. A zero-score run earns zero XP but still counts
as a played run. Developer Practice, pending runs and rejected runs earn none.
XP is awarded once after settlement, even if a submission is delivered again.
Campaign instead awards catalog XP only on first successful clears: Val Outpost
grants 40/48/60/76, totaling 224 and reaching level 3 from a new account. Failure
and repeats give no XP; collected gold remains repeatable. Campaign XP and unlocks
wait for verification and never use the score-derived local XP preview. See
[Campaign](campaign.md).
The run result shows its gold and XP immediately without a pending label. Once
the replay is safely journaled, Hub and Profile include that local XP in the
displayed total and level. Settlement replaces this presentation without adding
the reward a second time. Level gifts are created only from confirmed levels.
An unsuccessful run verification removes its displayed reward and explains the
correction; connection failures keep the journal for automatic retry.

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
the displayed total, filling and resetting at each crossed level. Normal
settlement keeps that total steady, so it does not replay the animation.
The Profile page repeats the bar and shows lifetime XP, Practice runs
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
tracking is enabled; historical runs are not backfilled. Lifetime stats are descriptive, so score and gameplay tuning can evolve without
changing a previously earned level or replay outcome.
