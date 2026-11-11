# Campaign: Val Outpost

Implemented locally November 11, 2026; the four production layouts are excluded
drafts for the user to author in the editor. See the
[runtime and progression contract](../tdd/campaign_runtime.md).

Campaign has a third main-menu card alongside Level and Character Selection.
It shows the regional map cropped around Val Outpost. Open Campaign to see the
regional map fill the screen behind the toolbar, like Town and Library Locations.
Pan or pinch to explore the cropped artwork; Reset map restores the initial view.
Selecting Val opens chapter details and missions in a modal occupying the left
two-thirds and full height of the phone's safe area, clear of cutouts and system
bars. The map remains visible on the right. Details scroll below a fixed title and
Close button; Close, Back or a tap outside restores the same map view.

Mission one has no completion prerequisite; later missions require verified clears
of their predecessors. An unbuilt draft shows Coming soon. Each entry shows its
assignment, access/clear status and current content-version personal best.
Level titles match the chapter heading's font and size. Descriptions sit on the
left with the mission action button on the right in the same row.
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
omitting enemies, rescues, boss arenas and traps for this combat-free mission.

Missions contain an exact finite sequence of chunks. Players and camera move in
both directions without forced scrolling. Collected items and defeated enemies
stay consumed on return. All required targets/visit regions/rescues and authored
bosses must be completed before entering the exit. Death or required-objective
failure wins over success on the same tick. Restart resets the whole attempt.

Verified first completion of Reporting for Duty unlocks Éloïse's Double Jump.
It does not silently change builds; the results screen can equip it explicitly.
Four clears unlock Willow in every game mode. Existing pre-release accounts use
the same lock, retaining their equipment and builds. Developer local play has
all characters and skills but grants no account rewards.

First clears grant 224 XP in total, putting a new zero-XP account at the start of
level 3 under the unchanged XP curve. Failed attempts and repeats grant no XP;
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
