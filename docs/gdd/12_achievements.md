# Hall of Honour achievements

Implemented on 2026-10-30. Dev backend/web are deployed and Android build 4 is
verified; device installation and live menu acceptance remain pending. See the
[release evidence](../verification/achievements-dev-2026-10-30.md) and
[technical contract](../tdd/achievements.md).

The **Hall of Honour** opens from the southern courtyard building on the
Théodonis Town map, selected by the owner. Its label and building marker both
open the menu; Back returns to Town. A gold attention dot appears on its label
while any achievement reward is available. The name is a game destination;
its staff, history and institutional role are not established world canon.

## First five achievements

| Achievement | Metric | Bronze | Silver | Gold |
| --- | --- | --- | --- | --- |
| First Steps | Qualifying runs ended | 1 | 10 | 50 |
| Marathoner | Best distance in one qualifying run | 500 m | 1,000 m | 2,500 m |
| Road Warrior | Total distance across qualifying runs | 1,000 m | 10,000 m | 50,000 m |
| Still Standing | Total time alive across qualifying runs | 5 minutes | 1 hour | 5 hours |
| Slayer | Enemies defeated across qualifying runs | 25 | 250 | 2,500 |

Each achievement pays **25 / 75 / 150 gold**, respectively. Rewards are additive:
250 gold per achievement and 1,250 gold across all five. These are conservative
starting defaults, not a measured claim about session length or economy balance.
Future tuning must preserve already earned rewards and completion history.

## Qualifying progress

An ordinary Practice, Competitive or Weekly run must end naturally, pass replay
validation and reach **at least 10 metres OR 10 seconds**. Death, falling into a
gap, falling behind the camera and a failed boss encounter count. Manually
quitting does not. The same qualifying gate applies to all five metrics,
including kills; failed startup, pending/rejected validation and local Developer
Practice grant no achievement progress.

Progress belongs to the account across characters, sessions, devices and board
windows. Previously accumulated stats, distances and enemy defeats are not
credited. Only newly settled qualifying runs count. An accepted run may advance
multiple achievements and pass multiple tiers at once. Marathoner keeps the
best single-run distance; Road Warrior and Still Standing accumulate runs.
Slayer uses the same replay-confirmed defeat attribution as Profile and Library,
including bosses and summons, but only from qualifying runs. Consequently its
total can differ from the ungated lifetime Profile total.

## Menu and claims

The gold balance appears at the far right of the app bar as a number and coin
icon, without a label.

Collapsed rows show the name, next unreached requirement, current progress and
that next tier's gold reward. They hide the other thresholds and tier names.
An earned but unclaimed tier does not block progress toward later tiers: at
30 defeats, Slayer shows `30 / 250` with the next 75-gold reward, while
`Claim 25 gold` collects the earned Bronze reward.

Clicking a row expands all three tiers with their requirements, gold amounts,
states and each earned tier's completion date. Dates use server confirmation
time, displayed as `30 Oct 2026 (UTC)`, identically across devices. Claiming
never replaces an achievement's date. Unreached tiers have no date. Multiple
rows can stay expanded; order is the table order, with no filters or sorting.

One row-level Claim collects all available tiers of that achievement. Claim all
appears when rewards are available on more than one achievement. Gold becomes
spendable only after the backend confirms the claim. While a request is pending,
claim actions are disabled; failure preserves rewards and allows retry.

Claim is hidden when no earned reward is available. After the final threshold,
the row shows Completed and keeps Claim until all rewards are collected. The
expanded history then shows Claimed; there is no persistent disabled Claimed
button. Unclaimed rewards do not expire. Opening the menu refreshes confirmed
progress, and a manual refresh control is available.

## Future design

Cosmetics, titles, frames, mastery and build exploration remain ideas in the
[archived proposal](../archive/2026-10-30/gdd/12_achievements.md). They are not
part of these five achievements. Weekly prestige still needs the earlier
percentile proposal reconciled with Top-10-at-rollover proposals in
[run types](05_run_types.md) and [leaderboards](07_leaderboard.md).
