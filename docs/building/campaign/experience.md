# Campaign experience and Val Outpost proposal

Status: proposed design. The [plan index](README.md) distinguishes confirmed
requirements from defaults. Mission titles, count within the requested range,
encounters, and economy below are not established canon or final tuning.

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
required objectives, selected character/build, first-clear entitlement, and any
repeat reward. Distinguish score from currency/XP. Avoid adding star/medal systems
until a concrete design need is agreed.

Use the player's selected character and build as the default. The first chapter
must be completable with both starter builds and without optional purchases.
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

Four missions are the working baseline; three remain within the user's scope.
Teaching is embedded in assignments and spatial design, never a chapter named
Tutorial. These titles and situations are proposals to validate against local
canon and playtesting:

| Order and working title | Assignment and teaching focus | Content direction |
| --- | --- | --- |
| 1. Reporting for Duty | Reach a marked destination; learn movement, jumping, and returning along a safe path | Outpost/camp scenery, forgiving geometry, clear landmarks, an optional return trip before exit |
| 2. The Forest Road | Clear a short patrol route; introduce basic combat, mobility, and resource use | A few guaranteed regular enemies, deliberate attack spacing, readable resource placement |
| 3. The Missing Patrol | Complete an ally rescue; combine threat prioritization and resource management | Reuse the rescue encounter system with explicit mission targets and recoverable approaches |
| 4. Hold the Road | Complete a modest concluding encounter and reach the exit | Combine movement, combat, and support decisions; a boss is optional and requires separate beginner tuning |

If playtesting favors three missions, combine the second and third only if the
learning load remains manageable. Finalize count/order before persistent public
mission IDs and rewards are released. Titles can change later without changing
identity. All missions use explicit chunk sequences, with custom variants where
the original runner geometry cannot support safe return travel.

Start by surveying existing Forest entrance, camp, grove, and encounter sources;
do not promise that an existing chunk is bidirectionally traversable before
testing it. Favor adaptation of a few coherent sources over importing the full
endless Forest progression or its boss sequence.

Val Outpost is already described as a road-patrol and survival-training post in
the [Codex GDD](../../gdd/codex.md). Keep narrative brief, grounded in patrols,
travelers, duty, and limited resources. Named personnel, plot developments, and
new institutions need canon support before becoming authored text.

World references consulted in the parent repository are creative guidance, not
runtime dependencies: [Identity](../../../../Brand/Identity.md),
[Cross-media rules](../../../../Brand/CrossMediaExpressionRules.md),
[Visual identity](../../../../Brand/VisualIdentity.md),
[Visual tokens](../../../../Brand/VisuelTokens.md),
[Naming](../../../../Brand/Naming%26Terminology.md), and
[Geography](../../../../Brand/WorldSnapshot/GeographicIdentity.md).
Use the local palette/theme and existing map artwork for the first delivery.

## Economy and scope decisions

| Decision | Proposed default | Resolve by |
| --- | --- | --- |
| Mission count and titles | Four working missions as above; three allowed | M4 before final chapter authoring and persistent public identity freeze |
| Character/build access | Current selected build; both starter builds viable | M1 acceptance, then M4 content balance |
| Unlock rule | Clear previous required mission; no minimum score | M0 contract, implemented in M3 |
| First-clear reward | Once-only gold/XP; exact amounts untuned | M3 trusted reward policy, finalized in M4 |
| Repeat reward | Explicit bounded policy; no repeat first-clear bonus; prototype can use zero | M3 before rewarded integration |
| Score formula | Objective/combat/rescue performance; no idle-time income; optional capped efficiency bonus | M1 deterministic prototype, final version at M4 |
| Failure/abandonment rewards | No campaign completion or first-clear reward; any ordinary earned reward requires explicit policy | M3 settlement contract |
| Shared progression eligibility | Preserve current ranked-only discovery/achievement rules; enumerate lifetime-stat eligibility | M3 projection audit |
| Retry and persistence | Restart mission; save verified account progress between attempts | M1 lifecycle and M3 persistence |
| Arena locks | Only explicit temporary encounter locks; reopen on success | M1 if used, otherwise M4 encounter selection |

Defaults permit implementation planning without claiming user approval of final
tuning. Escalate only choices that would materially change the requested scope
or require reworking already published identities/contracts.
