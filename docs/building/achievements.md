# Hall of Honour - achievements

Status: working design, updated 2026-10-30. Implementation has not started.
This document captures the current discussion; thresholds, reward amounts and
the open questions below still need refinement before implementation planning.
It is the single active design/checklist for this workstream.

## Agreed direction

- Start with five milestone achievements: First Steps, Marathoner, Road Warrior,
  Still Standing and Slayer.
- Add **Hall of Honour** as a selectable location on the Town map, opening the
  achievements menu. The building and map position remain to be chosen.
- Use gold rewards for the initial version, claimed directly in the achievements
  UI. Achievement rewards are not delivered through Messages.
- A collapsed achievement shows only its next threshold and progress toward it.
  Clicking the row expands it to show the complete achievement: all thresholds,
  rewards, completion state and the dates on which tiers were achieved.
- Claim appears only while an earned reward is available. It disappears after
  claiming, until another reward is earned. Fully completed and claimed
  achievements remain available to inspect without a Claim button.

Hall of Honour is the chosen game destination name. Its institutional role,
staff and history have not been established as world canon. Creative references
consulted: the companion repository's `Brand/Naming&Terminology.md`,
`Brand/Identity.md`, `Brand/CrossMediaExpressionRules.md` and
`Brand/WorldSnapshot/`, under `C:/dev/Lothringen/`.

## Initial achievements and provisional thresholds

The thresholds below carry forward the starting values discussed from the
[earlier proposal](../archive/2026-10-30/gdd/12_achievements.md). They are tuning
candidates, not a final balance decision. In particular, check the 10 km
single-run target against real run lengths before retaining it.

| ID | Achievement | Metric | Bronze | Silver | Gold |
| --- | --- | --- | --- | --- | --- |
| M01 | First Steps | Qualifying runs ended | 1 | 10 | 50 |
| M02 | Marathoner | Best distance in a single qualifying run | 500 m | 2,000 m | 10,000 m |
| M03 | Road Warrior | Total distance across qualifying runs | 5 km | 50 km | 250 km |
| M04 | Still Standing | Total time alive across qualifying runs | 15 min | 3 hours | 20 hours |
| M05 | Slayer | Enemies defeated | 100 | 1,000 | 10,000 |

First Steps recognises meaningful attempts, including runs that end in death;
it does not require a victory. The proposed validity gate is at least 300 m
travelled OR 60 seconds survived. Whether to retain those values, which end
reasons qualify, and how the gate applies to kills are still open. Instant
quit/restart farming and failed startup must not create completion credit.

The proposed tuning aim is Bronze during the first few sessions, Silver as a
medium-term goal and Gold as a longer challenge. Distance and time achievements
need measured play data before those expectations can be treated as credible.

## Hall of Honour menu

### Collapsed row

Show the achievement name, a concise requirement, progress toward the next
unreached tier and that tier's gold reward. Do not show the full tier ladder
or all three thresholds in the collapsed view.

Progress and claiming are separate: an unclaimed Bronze reward does not prevent
progress toward Silver. For example, Slayer at 420 kills can show `420 / 1,000`
toward Silver and its proposed 75-gold reward, while a separate `Claim 25 gold`
action remains available for Bronze. The next target is the next unreached
threshold, not the next unclaimed reward.

Once the final threshold is reached, replace the next-target presentation with
a completed state. If any earned reward remains unclaimed, keep Claim available.
Reaching the final threshold must never make its reward inaccessible.

### Expanded row and completion dates

Clicking an achievement expands its row in place. The expanded view shows:

- The full achievement description and qualifying conditions.
- All Bronze, Silver and Gold thresholds and their gold rewards.
- Each tier's state: not reached, achieved with reward available, or claimed.
- The completion date for each achieved tier, retained after its reward is
  claimed. Unreached tiers have no completion date.

Completion dates describe when the accomplishment was earned, not when the
player opened the menu or claimed the reward. Claims must not replace those
dates. The full achievement completes when its last tier is reached; the
expanded record must retain the earlier tiers' dates as well.

The timestamp source still needs a decision: the qualifying run's recorded end
time versus the time its result is confirmed. Date formatting, time zone and
whether to display an additional overall completion date are also open. Do not
invent dates if existing account progress is eventually credited retroactively.

### Claim visibility

| State | Claim action | Achievement presentation |
| --- | --- | --- |
| No tier reward available | Hidden | Next target and progress |
| One or more earned rewards unclaimed | Visible, with the claimable gold amount | Next target, or completed if all thresholds are reached |
| Available rewards successfully claimed; tiers remain | Hidden until another reward is earned | Next target and progress |
| All tiers reached and every reward claimed | Hidden | Completed; row remains expandable |
| Claim fails or is still being processed | Preserve the available reward; prevent duplicate submission while processing and allow retry after failure | Do not mark rewards claimed before confirmation |

There is no permanently disabled Claimed button. Claimed state belongs in the
expanded tier history. A proposed convenience is one row-level Claim that
collects all currently available tier rewards for that achievement. Whether to
also allow individual tier claims or a menu-wide Claim all remains open.

A gold attention dot on the Hall of Honour map location for available rewards
was suggested; its inclusion and any additional Town/menu indicators still
need to be decided. Sorting, filters and expansion behaviour also remain open.

## Gold rewards

Gold is the agreed initial reward type. The proposed amounts are the same for
each of the five achievements:

| Tier | Additional gold on claim |
| --- | ---: |
| Bronze | 25 |
| Silver | 75 |
| Gold | 150 |

These amounts total 250 gold per achievement and 1,250 gold across all five.
Each tier pays in addition to previous tiers, rather than replacing their
rewards. Amounts remain provisional. For context, the current
[level reward](../../functions/src/inbox/level_rewards.ts) is 25 gold and the
[store's default unlock price](../../functions/src/ownership/store_pricing.ts)
is 150 gold. Gold buys existing store unlocks; achievements do not introduce
direct permanent combat stat bonuses.

Proposed reward guarantees for the eventual implementation:

- Each tier pays once per account, shared across characters and retained across
  sessions and devices. Concurrent or retried claims cannot grant gold twice.
- Unclaimed rewards remain available without expiry, including lower-tier
  rewards when later thresholds are reached.
- Reaching a tier makes its reward claimable; gold becomes spendable only after
  a successful claim in Hall of Honour.
- Record the promised amount when a tier is earned so later tuning does not
  alter an already earned reward.
- Keep achievement completion, completion dates and reward claim records
  distinct. A permanent achievement survives the claim that pays its reward.

Cosmetics, titles, frames and other reward types remain future ideas.

## Current foundations and proposed authority

Existing [player progression](../tdd/player_progression.md) and
[Codex discovery settlement](../tdd/codex.md) already provide persistent run
counts, shared enemy defeats and replay-verified progression. The
[validated run contract](../../packages/run_protocol/lib/validated_run.dart)
also contains distance, duration and the run end reason. These are foundations,
not an implemented achievement evaluator, completion history or claim system.

The proposed approach is to count verified ordinary Practice, Competitive and
Weekly runs, with account-wide progress and rewards. Pending or rejected runs
and Developer Practice would not count. Ordinary Practice should use the
existing verified path rather than the older proposal's local reward authority.

The current accepted-run counter includes short accepted runs and does not
enforce the proposed achievement validity gate. Lifetime achievement distance,
survival totals and per-tier dates also need their own defined persistence.
Whether existing enemy defeats or other historical progress should count has
not been decided; stored totals must not be mistaken for proof of historical
qualifying runs or completion dates.

Implementation ownership should follow the existing boundaries: Core supplies
gameplay facts, replay validation confirms run evidence, the backend owns
account progression and gold grants, and the UI displays and requests claims.
The storage schema, APIs and exact settlement/claim integration are still to be
designed. This document does not establish an implemented technical contract.

## Design checklist and next discussion

The next step is to settle qualifying runs and historical progress, then tune
thresholds and rewards against representative runs. Keep this as the only
active checklist; do not start an implementation checklist in parallel.

- [x] Record the initial five-achievement direction and gold reward choice.
- [x] Name the Town destination Hall of Honour and locate claims in its menu.
- [x] Record next-threshold-only collapsed rows and complete expanded details.
- [x] Include per-tier completion dates and separate them from reward claims.
- [x] Record conditional Claim visibility and retain the final unclaimed reward.
- [ ] Define qualifying run distance/time, end reasons and kill eligibility.
- [ ] Decide whether historical progress counts and how missing dates appear.
- [ ] Tune and confirm all five achievements' thresholds and gold amounts.
- [ ] Define the authoritative completion timestamp and displayed date format.
- [ ] Choose the Town building/marker position and visual identity.
- [ ] Settle multi-tier claims, Claim all, attention dots, ordering and expansion.
- [ ] Design persistence, settlement and claim contracts after the gameplay and
  UI decisions are sufficiently settled; then define implementation checks.

## Deferred ideas

The [archived 24-achievement proposal](../archive/2026-10-30/gdd/12_achievements.md)
preserves mastery, build exploration and Weekly ideas. They are not commitments
for the first five achievements. New tracking would be needed for several of
them. Before adding Weekly prestige, reconcile that draft's percentile awards
with the Top-10-at-rollover proposal in [run types](../gdd/05_run_types.md) and
[leaderboards](../gdd/07_leaderboard.md); the discrepancy remains unresolved.
