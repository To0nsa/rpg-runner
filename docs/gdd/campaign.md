# Campaign: Val Outpost

## Story Journal

The story begins after *Le feu de joie*: the tabletop survivors have arrived in
Théodonis, while Éloïse is summoned to investigate cultists around Val Outpost.
They appear different from the undead goddess’s followers. The suspicious timing
requires investigation, without establishing that the groups are connected.

Campaign settings author the opening; chapter settings author an introduction;
mission settings author an optional completion update. Each has an English/French
title and body. Library Journal accumulates the appropriate passages from confirmed
mission clears in chapter/mission order, with no duplicate entries on replay.
Draft mission text stays hidden in the game. The editor’s **Preview Journal after
this mission** also shows draft story passages through a selected checkpoint.

Val’s campaign opening contains the complete spoiler-free location
description: the tent camp, Théo’s twenty-four guards, Hanna, the bugbear threat,
and the camp’s message-relay and refuge duties. The chapter introduction,
**After Le feu de joie**, follows that baseline with the investigation setup.
Mission outcomes follow both entries, in English and French.

The Journal is available independently of Competitive location discovery scores.
See [Library behavior](codex.md) and [authoring/runtime ownership](../tdd/campaign_runtime.md).

Implemented locally November 11–12, 2026; production layouts and build inclusion
are authored by the user in the editor. See the
[runtime and progression contract](../tdd/campaign_runtime.md).

Campaign has a third main-menu card alongside Level and Character Selection.
Chapter location labels are automatically placed around their geographic white
dots, with connecting leader lines. Placement accounts for measured translated
labels, map edges and nearby locations; the editor's Game preview uses the same
map presentation. Authored missions can contain up to 48 chunks.
The campaign screen displays the authored campaign name in the current language
and the map selected in the editor's Campaign settings. There is currently one
campaign; naming it does not add a campaign-selection screen. Chapter positions
remain attached to normalized map coordinates when the artwork changes.
It shows the regional map cropped around Val Outpost. Open Campaign to see the
regional map fill the screen behind the toolbar, like Town and Library Locations.
Pan or pinch to explore the cropped artwork; Reset map restores the initial view.
Selecting Val opens chapter details and missions in a modal occupying the left
two-thirds of the phone's safe width, clear of cutouts and system bars. A
12-logical-pixel outer margin keeps the panel off the screen edges even in
fullscreen mode with no system insets. The map remains visible on the right.
Details scroll below a fixed title and Close button; Close, Back or a tap outside
restores the same map view.

Mission one has no completion prerequisite; later missions require verified clears
of their predecessors. An unbuilt draft shows Coming soon. Built missions show a
disabled Locked button with a lock icon until unlocked, then an uppercase PLAY
button without an icon, including on repeat attempts. All mission action buttons
have the same width. Locked entries replace their level name with Locked and hide
their descriptions, tooltips and disclosure arrows until progress unlocks them.
Unlocked entries start collapsed with a leading disclosure arrow, level name and
action button in one compact row.
Level names use the chapter heading's font family at a smaller size. Long names
truncate to one line, with the full name available in a tooltip and to screen
readers. Tap the arrow or name to show the assignment, completion status and
current content-version personal best below the row; tap again to collapse it.
The button communicates locked access without a separate prerequisite sentence.
The modal omits the selected character/build and chapter/mission reward details.
Missions use the selected character/build.

The chapter follows **Le feu de joie**, chapter 3 of **Les Soleils d'or**, using
the user's supplied premise: cultists have been seen nearby and Val needs help.
No additional scenario canon is assumed. The opening teaches through play without
calling itself a tutorial. The editable mission defaults are:

| Mission | Assignment | First-clear XP |
| --- | --- | ---: |
| Reporting for Duty | Cross the Forêt des Moyen-Ducs and reach Val Outpost; movement and basic jumping, no encounters | 40 |
| Signs in the Grove | Investigate cultist activity in the grove | 48 |
| The Supply Trail | Clear cultists threatening the outpost's supply route | 60 |
| Holding the Outpost | Remove the remaining cultist threat around Val | 76 |

The user builds the exact layouts, objectives and encounter distribution. The
first mission starts from Forest rocky_grove easy/normal copies and ends in
trainingcamp copies. Copy to Campaign preserves the layout and water while
omitting enemies, rescues, boss arenas and traps from the copies. Reporting for Duty
then authors its own Grojib marker for the combat introduction.
Combat is determined by what is placed in the route; there is no combat toggle.

Reporting for Duty begins with a paused movement explanation: a grey veil,
clear opening around the movement controls and an English/French card. Pressing
an arrow or touching the joystick area dismisses it and begins play with that
same gesture. Keyboard movement also starts it. Text and spotlight adapt to the
selected controls; keyboard-only play shows the card without a touch spotlight.
Other actions and empty-space taps do not start. Fresh attempts repeat the
lesson; pause/resume does not.

Reporting for Duty initially exposes only movement. Jump, attacks, shield, magic,
mobility, resource bars, objectives and run counters stay hidden; keyboard/mouse
cannot use those hidden abilities. After roughly three metres of walking in either
direction, the game pauses to introduce the objectives card: **Collect a coin 0/1**.
The card stays horizontally centred on the game display as HUD elements appear.
Release and move again to continue towards the coin. The actual pickup changes it
to **Collect a coin 1/1** with a green checkmark. The completed card stays for three
seconds of gameplay, fades over a quarter second, then disappears. Pauses and the
coin explanation do not consume that time. This card has no objectives header or
exit instruction. The coin remains a real requirement for completing the mission.
The first collected coin then pauses the world and
reveals Distance and Collectibles beneath a manually authored spotlight. The card
explains that each coin gives 1 gold, Collectibles counts coins, and Distance tracks
furthest forward progress. Release movement and press it again to continue. Existing
holds cannot dismiss this lesson. The counters stay visible for that attempt;
restart resets them and repeats all authored lessons. Pause/Exit retain their normal roles.

At entry to the second chunk, one paused sequence has three steps:
1. Highlight the existing rock and explain that obstacles interrupt the path.
2. Select **Next** to reveal and explain the Jump button.
3. Select **Next** to reveal the resource bars: red health, the middle ability resource,
   green stamina. Explain that jumping spends stamina, which recovers over time.

A fresh Jump press (Space on keyboard) finishes the sequence and performs a real
jump. Movement and held/repeated input cannot dismiss this last step. Jump and the
resource bars remain available afterward; attacks, shield, magic and mobility stay
hidden until introduced. Pause/Resume preserves the current step.

After the rock, approaching the first pool pauses play with **Water ahead** and a
spotlight on the water: jump across or swim through it, with slower movement in
water. Release movement and engage it again to continue; airborne approaches also
trigger the card. The first actual swim, in this pool or a later one, introduces
**Swim upward** on the existing Jump button. A fresh Jump/Space resumes play with
an upward stroke, spending stamina. This hint waits until the stroke is available.
Jumping across leaves it eligible without delaying subsequent lessons. Neither
lesson repeats on backtracking; restart resets both. Pool geometry is unchanged.

Once grounded beyond that pool, **Scenery or obstacle?** highlights the pale tree
on the far bank. Decorations have a pale white tint and can be walked through;
solid obstacles such as the previous rock block the path. The card waits until
the player lands, including after jumping across. Release and move again to
resume and walk through the tree. It reveals no additional HUD, completes once
per attempt and resets on restart. Skipping swimming does not block this lesson.

After the decoration lesson, **Mind the gap** introduces the first dry opening
in chunk three. Play pauses on safe ground 96 world units before its near edge;
the spotlight shows the 69-unit opening and both ledges. Release and move again,
then time a normal jump to cross. Falling too far ends the attempt. Dismissing
the card does not jump, reveal more HUD or grant progress. There is no crossing
confirmation popup. Early airborne crossings are not interrupted; landing safely
beyond the gap skips the now-unnecessary warning. Backtracking does not repeat it;
restart does. **Gap crossing** in Tutorial sequences edits both languages, the
selected ground banks, approach distance and manual spotlight.

Before the first raised platform in chunk four, **Platforms** pauses on safe
ground and highlights that platform, including its top. The card explains jumping
up through it and landing above while descending, then using platforms to reach
higher places and cross gaps. Release and move again to continue and time the
jump. The HUD stays unchanged; landing does not open another card. The lesson
uses a 64-world-unit approach. An early airborne bypass is not interrupted, and
passing the platform safely retires an unshown explanation. Restart resets it.
Its target, approach distance, English/French text and manual spotlight are editable.

Before the basin in chunk seven, **Receive a blessing** pauses on safe ground and
highlights the basin. The objective card reads **Receive a blessing 0/1**. Release
and move again, then jump onto it. The actual landing lights the fire and changes
the objective to **Receive a blessing 1/1 ✓**; the game pauses to explain the
**Bénédiction des Dames de la forêt**. Next highlights resources and the newly
revealed fire indicator: health, ability resource and stamina regenerate faster,
without an instant refill. The bonus lasts for this attempt and does not stack
with another basin. Fresh movement resumes. The completed row holds for three
seconds of gameplay and fades independently of the earlier coin row. Missing the
basin leaves the goal pending; the player can return. Restart resets everything.
This selected shrine is required before exiting even when guidance is disabled.

After the next pool, **Mobility: Dash** pauses near the bush in chunk eight,
before the downhill stretch. It waits for dry ground and a ready, affordable Dash,
without interrupting an airborne crossing or freezing a recharge. It reveals and
highlights Mobility, explaining the speed burst, stamina cost and recharge. A fresh
Mobility press (Shift on keyboard) resumes and performs the dash. Existing holds,
movement and Jump cannot dismiss it. Mobility stays available; no objective or
completion popup is added. Restart repeats the lesson. Replaying with another
mobility skill reveals that control at the same point without the Dash-specific
explanation or changing the build.

After Dash, the Grojib marker in chunk ten introduces **Projectiles and sword**.
The visible enemy is highlighted at an approach distance of 250 world units, when
the player is grounded and the opening shot is ready. Next reveals Projectile and
explains its mana cost. A fresh press (K/right mouse on keyboard and mouse) resumes
play and fires. Only the actual launch locks further shots; the visible button dims
and a bilingual practice hint asks the player to let the enemy approach. Movement,
Jump and Mobility stay available. Once the enemy stops within sword reach, when Sword is affordable and
ready, the world pauses and reveals Sword. A fresh press (J/left mouse) performs the
strike. Its actual execution unlocks Projectile; an interrupted windup remains
retryable. Cooldowns, resource costs, health and AI are unchanged.

This lesson teaches the starting Éloïse Snap Shot/Seeker Slash pair. Other builds
retain their equipment and reveal both controls at the approach without incorrect
tap/mana instructions. If the marked enemy dies early or is unavailable, both
controls unlock and the lesson retires without a stale enemy card. It adds no
required kill objective. Restart restores the initial HUD and all practice state.
The marker, approach distance, three bilingual pages, practice hint and spotlights
are editable through the existing atomic tutorial form.

The **Tutorial sequences** tab selects the initial HUD and edits, disables or
removes each lesson, including which features it reveals. Authors draw, move and
resize each control variant's spotlight and the objective/counter panel openings.
The obstacle sequence edits its three pages together, with a chunk attachment,
obstacle bounds and independent spotlights for obstacle, Jump and resources.
**Water introduction** selects a mission chunk, an existing water region and an
approach distance, with editable bilingual text and a manually adjustable spotlight.
**First swim** edits the optional swimming card and Jump spotlight independently.
**Decorations and obstacles** selects the preceding water and a unique decoration
prefab in that chunk, with bilingual text and a manually adjustable spotlight.
The mission settings switch **Collect a coin before exiting** controls the actual
objective independently of whether its explanation is enabled.
**Preview sequence** uses normal prelaunch device/HUD/control choices and calibrated
Play. To reach the coin explanation, play from the start and collect a coin.

Missions contain an exact finite sequence of chunks. Players and camera move in
both directions without forced scrolling. Collected items and defeated enemies
stay consumed on return. All required targets/visit regions/rescues and authored
bosses must be completed before entering the exit. Death or required-objective
failure wins over success on the same tick. Restart resets the whole attempt.

Campaign Markers offers visual placement of enemies, traps, rescue groups, gold
coins, health/mana/stamina gems and blessing fires, plus start/exit/visit regions.
Each placement belongs to one mission chunk. Coins grant the existing
one gold each; gems use existing restoration amounts. Blessing fire attaches to
an existing flat shrine/platform top and grants the existing regeneration bonus
on actual top contact. Fire stays lit and the bonus does not stack. Pickup
consumption and fire activation persist during backtracking and reset on restart.

Ordinary enemy markers create their actors during loading. They wait at their
terrain-resolved positions until the player comes within 280 world units of
their home, from either direction, or they take positive damage. Waiting enemies
remain visible, damageable and subject to normal terrain physics. They cannot
pursue, cast or ambush distant targets. Derf begins his one-way transformation
when engaged in Campaign, then uses his normal ground combat.

Each enemy marker has **Return when player retreats**, enabled by default. With
it enabled, the enemy stops fighting when the player moves more than 600 world
units from its home and returns using its normal movement, jumps or flight. Its
horizontal territory is also limited to 600 units either side of home. A hit
allows two seconds of retaliation before distance can disengage it again. With
the switch disabled, the enemy keeps following throughout the mission once
activated. Camera visibility never ends combat. Returning does not respawn,
teleport or reset health; normal regeneration still applies. An unreachable home
does not grant movement through blocked terrain. Approaching home or damaging
the enemy can engage it again. Defeated enemies remain defeated.

These rules apply to ordinary Campaign enemy markers. Rescue participants and
bosses retain their separate activation and combat rules.

Verified first completion of Reporting for Duty unlocks Éloïse's Double Jump.
It does not silently change builds; the results screen can equip it explicitly.
Four clears unlock Willow in every game mode. Existing pre-release accounts use
the same lock, retaining their equipment and builds. Developer local play has
all characters and skills but grants no account rewards.

Mission first-clear rewards can award XP, gold and up to eight existing items or
skills through the same picker as chapter rewards. Skills name their recipient;
items unlock ownership without equipping or duplicate compensation. Rewards are
granted once after verified completion. Current first clears grant 224 XP in total,
putting a new zero-XP account at the start of level 3 under the unchanged XP curve.
Failed attempts and repeats grant no first-clear rewards;
every verified attempt keeps collected gold. Score uses finite progress, combat
and pickups without survival-time points. Backtracking and waiting do not farm
score. There are no campaign boards, ghosts, stars, checkpoints or mid-mission
saves. Next becomes available after verification, using a fresh ticket.

Each chapter can also award configurable completion XP, gold and up to eight
existing equipment items or skills. These rewards are granted once after all
missions are verified complete, in addition to mission XP and collected gold.
Gear is account-wide; each skill names its recipient character. Rewards unlock
ownership without changing the current build. Already-owned items grant no
additional copy or compensation. Replays and later edits to the chapter do not
repeat a previously received chapter reward. Val Outpost currently adds no extra
XP, gold or items, preserving the level-3 target and Willow unlock.
