# Campaign experience and Val Outpost proposal

Status: design reference for the implemented campaign platform. The
[current technical contract](../../tdd/campaign_runtime.md) and
[game behavior](../../gdd/campaign.md) supersede tentative choices below.
The [single checklist](implementation.md) records local evidence and remaining
production-layout/device acceptance; this document is not a second task ledger.

## Story placement and content ownership

These events follow chapter 3, **Le feu de joie**, of **Les Soleils d'or**.
Cultists have been spotted at several locations and Val Outpost calls the player
for help getting rid of them. The user supplied this chronology and premise.
The chapter-3 scenario text was not available among the inspected local Markdown
sources; do not infer named cultists, rituals, outcomes, or a connection to Willow
from the title. Additional story details require user-provided or inspected canon.

The user will build the levels by hand. The implementation supplies authoring
capabilities, progression, and runtime validation; it does not choose or overwrite
their final geometry. Small disposable technical fixtures establish behavior
before the authored production layouts exist. The bidirectional chunk converter
in [Authoring](authoring.md) helps prepare independent layouts for either mode.

## Entry and navigation

```text
Main menu: [Level Selection] [Character Selection] [Campaign]
                                                   |
                                            Regional map
                                                   |
                                               Val Outpost
                                                   |
                                           Mission selection
                                                   |
                                      Mission details and Start
                                                   |
                                   Results: Retry / Next / Chapter
```

All three hub cards share available content width after sidebar, safe areas,
padding, and gaps. Replace the fixed-width wrapping behavior with a constrained
row and compact card content. Preserve legible labels and usable targets at the
smallest supported viewport and enlarged text; validate English and French.
Use bounded/wrapping text within each card rather than a second card row or
horizontal scrolling. Keep the existing runner Play button's meaning intact;
Campaign launches a mission from its own details screen.

Campaign card artwork uses a focused crop of
`assets/images/maps/theodonis_region_unlabelled.png` around the existing Val
Outpost anchor. Show the Campaign label and, when space permits, chapter progress.
Reuse artwork and neutral map/callout components; separate map geometry from
Library discovery state. Campaign opens the regional map with Val Outpost clearly
clickable and an accessible label. Panning/zooming and a reset view may reuse
existing map behavior. Unavailable future locations do not imply playable content.

Val Outpost opens the ordered mission selection. Mission one is immediately
available without a Competitive score or Library discovery. Later missions show
their prerequisite, then unlock through verified completion. Preserve the last
selected chapter/mission as navigation preference without treating it as progress.
Back returns through mission list, map, and main menu coherently.

## Mission selection, play, and results

Each mission entry shows title, availability/completion, personal best (or an
honest unplayed state), and reward information. Details show the short assignment,
required objectives, selected character/build, skill/character unlocks, first-clear
entitlement, and any repeat reward. Distinguish score from currency/XP. Avoid
adding star/medal systems until a concrete design need is agreed.

Fresh accounts begin the chapter with Éloïse. Willow is visibly locked in character
selection with the requirement to complete Val Outpost's four missions. The lock
applies to gameplay selection/admission across modes, including Training Field;
it is not just a campaign menu restriction. Chapter completion unlocks Willow,
with a clear character reward presentation and her valid starter build. Do not
automatically replace the player's current character or saved builds.

Use an owned, available character/build. Mission one must work with Éloïse's basic
jump and no optional purchases. Missions two through four can introduce the
Double Jump earned at mission one; if needed for traversal, provide an explicit
equip opportunity and check the actual loadout before launch. Unlocking a skill
does not silently overwrite the selected build. After Willow is unlocked, verify
replaying all missions with her available starter abilities and any explicitly
required earned skills; do not assume her separate Double Jump is already owned.
Explain relevant controls through brief contextual prompts derived from the
current input method and equipped actions. Do not demand an unavailable named
skill or gate success on dismissing a UI prompt. Accessible objective text stays
available after a transient hint disappears.

The world follows the player in both directions. Introduce pressure through
encounters, hazards, and resource decisions rather than automatic camera motion.
Allow returning through the designed route; objective gates should not trap the
player behind an unintended one-way jump or a permanently locked arena.

Show required objective progress and the exit condition without overcrowding the
combat HUD. Completion has a success presentation distinct from defeat. Results
show score breakdown, best-score comparison within the compatible rules version,
and applicable rewards. Retry creates a new attempt. Next Mission becomes
available after canonical progression admits it; verification/recovery feedback
must make a delay understandable and offer return to chapter. Reuse existing
reward presentation and recovery patterns rather than inventing a second wallet.

## Opening chapter outline

The chapter contains four missions. Reporting for Duty has the defined arrival
objective below. Missions two through four still need assignments, titles, and
encounters within the cultist premise; no rescue or boss is currently required.

| Mission | Confirmed content | Reward/progression |
| --- | --- | --- |
| 1. Reporting for Duty | Cross the Forêt des Moyen-Ducs to reach Val Outpost; introduce movement and jumping; no encounters | Double Jump unlock, earned XP and collected gold |
| 2. Title pending | Address the reported cultist presence; exact assignment and route pending | Mission-specific XP/gold policy pending |
| 3. Title pending | Address the reported cultist presence; exact assignment and route pending | Mission-specific XP/gold policy pending |
| 4. Title pending | Conclude the Val Outpost chapter; exact assignment and encounter pending | Earned XP/gold plus Willow unlock on chapter completion |

### Reporting for Duty

The route begins in the forest and ends on arrival at the outpost, using Forest
`rocky_grove` chunks in `easy` and `normal` tiers before `trainingcamp` chunks.
The user's "medium" and "training_camp" correspond to those existing authored
IDs. Exact chunk IDs, order, length, and edits belong to the user. The internal
return-trip test fixture is not this mission's story or production layout.

The initial crossing teaches ordinary movement and jumping. Completion is reaching
the authored outpost arrival region, without a combat, rescue, or boss objective.
Free backtracking remains supported before completion.
Both outward and intended return paths must be valid with the basic jump. Do not
place a Double Jump requirement before awarding the skill at the end.

Several reusable grove sources contain guaranteed enemy markers, including Derf.
The converter preserves supported encounter content. The user will edit the copied
chunks to remove unwanted ambient enemies, rescue groups, bosses, and combat spawn
placements. There is no converter removal option or encounter-free preset. Validate
the final mission content and any remaining hazards for the introductory traversal;
absence of enemies does not itself prove a forgiving route. Shared runner sources
remain unchanged.

First verified completion grants Double Jump once. The initial ability mapping is
`eloise.double_jump`, since Willow is locked; awarding `bounty_hunter.double_jump`
as well remains a separate scope decision. Already-owned skills are idempotent,
with no automatic compensation or duplicate grant. The current Training catalogue
offers Double Jump; this reward does not implicitly remove its existing purchase
path. Show an explicit equip action after earning it, preserving saved builds.

The user calls the route the Middle Dukes forest. Existing game copy uses
Forêt des Moyen-Ducs in French and Long-Eared Owls' Forest in English, documented
in the [Codex GDD](../../gdd/codex.md). Use the canonical French location identity
in planning and settle player-facing English naming through localization; do not
silently rename the existing region across the game.

### Chapter rewards and XP target

Willow is a once-only chapter-completion entitlement for clearing all four required
missions. Her internal character ID remains `bountyHunter`; do not introduce a
second Willow identity. Repeating the final mission cannot reinitialize her builds
or re-grant ownership. Existing profiles/builds and currently selected Willow
require a deliberate compatibility path when the new lock is introduced.

For a fresh account at level 1 and zero XP, the target is the **start of level 3**:
100 XP to level 2 plus 124 XP to level 3, totaling **224 XP**. Allocate that budget
across the four missions' intended first-clear rewards. Exact distribution and
gold amounts are not set. The target is not a cap or reset for players who have
earned XP through retries, other modes, or prior play.

Current runner XP is `floor(validatedScore / 200)`. A quiet introductory mission
and a fixed chapter XP target need an explicit campaign XP policy; do not distort
score or accidentally add both the old score-derived grant and the new budget.
Settle how earned/collected XP maps to verified completion and any pickup evidence
before M3, without assuming a new physical XP collectible is already implemented.
Budget the intended first-clear collection path, and state how skipped optional
pickups, failure, and replay affect the total. The account's level formula stays
unchanged. Level 3 does not unlock Build 2, which currently requires level 5.

World references consulted in the parent repository are creative guidance, not
runtime dependencies: [Identity](../../../../Brand/Identity.md),
[Cross-media rules](../../../../Brand/CrossMediaExpressionRules.md),
[Visual identity](../../../../Brand/VisualIdentity.md),
[Visual tokens](../../../../Brand/VisuelTokens.md),
[Naming](../../../../Brand/Naming%26Terminology.md), and
[Geography](../../../../Brand/WorldSnapshot/GeographicIdentity.md).
Use the local palette/theme and existing map artwork for the first delivery.

## Economy and scope decisions

| Decision | Requirement or remaining default | Resolve by |
| --- | --- | --- |
| Mission count and titles | Four; Reporting for Duty confirmed, other titles/assignments pending | User content design before production identity freeze |
| First mission layout | User-authored rocky_grove easy/normal to trainingcamp; no encounters; basic jump | M2 authoring support, then user layout validation |
| Character/build access | Éloïse initially; Willow locked until chapter clear; preserve builds | M0 entitlement contract, M3 admission, M4 replay balance |
| Unlock rule | Clear previous required mission; no minimum score | M0 contract, implemented in M3 |
| Skill reward | Mission one grants Double Jump once; Éloïse mapping initially; Willow variant not decided | M3 trusted ability grant and equip presentation |
| Chapter reward | Unlock Willow once after four clears | M3 trusted chapter entitlement |
| Chapter XP | Target 224 XP for the intended fresh-account first pass, reaching level 3; mission split pending | M3 policy, M4 economy verification |
| Gold | Earned/collected mission gold; amounts untuned | M3 trusted reward policy, finalized in M4 |
| Repeat reward | Explicit bounded policy; no repeat first-clear bonus; prototype can use zero | M3 before rewarded integration |
| Score formula | Objective/combat/rescue performance; no idle-time income; optional capped efficiency bonus | M1 deterministic prototype, final version at M4 |
| Failure/abandonment rewards | No campaign completion or first-clear reward; any ordinary earned reward requires explicit policy | M3 settlement contract |
| Shared progression eligibility | Preserve current ranked-only discovery/achievement rules; enumerate lifetime-stat eligibility | M3 projection audit |
| Retry and persistence | Restart mission; save verified account progress between attempts | M1 lifecycle and M3 persistence |
| Arena locks | Only explicit temporary encounter locks; reopen on success | M1 if used, otherwise M4 encounter selection |

Defaults permit implementation planning without claiming user approval of final
tuning. Escalate only choices that would materially change the requested scope
or require reworking already published identities/contracts.
