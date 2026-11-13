# Campaign tutorials and progressive HUD

Campaign missions can author movement, objectives, first-coin, obstacle/jump, water,
decoration, gap, platform, blessing, mobility and combat explanations, plus an optional first-swim hint.
Reporting for Duty uses all twelve. Guidance is presentation and input policy for an
attempt; Core separately owns its coin and selected-shrine objectives.
Tutorial text, visibility and completion never grant objectives or rewards.

## Authored contract

Schema-1 `chapter_defs.json` has optional mission `initialTutorialHud` and
`tutorialSequences`. Missing HUD settings preserve the full normal HUD. An explicit
initial set must retain movement. Features are movement, resources, objectives,
runStats, jump, primary, secondary, projectile, spell, mobility and blessings
(the blessing indicator beneath resources). Pause/Exit use
the existing host lifecycle and are independent of this selection.

Sequences admit at most one of each `missionStart`/`movement`,
`movementStarted`/`objectives`, `firstCoinCollected`/`firstCoin` and
`chunkEntered`/`obstaclesAndJump`, `waterApproached`/`water` and
`firstSwimming`/`swimming`, `waterCleared`/`decoration` and `gapApproached`/`gap`, then `platformApproached`/`platform` and `blessingApproached`/`blessing`, in that source order,
followed by `mobilityReached`/`mobility` and `enemyApproached`/`combat`, with unique stable IDs. Disabled entries are still validated. All have author names,
enabled flags, English/French
titles and cumulative `reveals`. Movement retains independent instructions for
arrows/fixed/floating/keyboard and three touch spotlights; its default reveal is
movement. Objectives and coin lessons share `CampaignPanelTutorial`: one
localized instruction, a panel spotlight and a mandatory objectives/runStats reveal,
respectively. Unknown fields, nulls, unsupported kinds, duplicate
features, incomplete languages and invalid geometry fail strict decoding.

`CampaignSteppedTutorial` and immutable `CampaignTutorialStep` share the bounded
page contract for jump and blessing introductions. `CampaignJumpTutorial` has
exactly three ordered steps: obstacle, jump, resources.
Each step owns bilingual title/instruction, a spotlight and cumulative reveals.
Jump/resources steps must reveal their target. Its stable `missionChunkId` must
exist in the source route, including for disabled sequences. Reordering keeps the
attachment; remove or reattach the sequence before deleting its chunk. The obstacle
uses explicit visual bounds within the 600×270 chunk. It does not infer collision
geometry or mutate terrain. Next advances the first two steps; only a fresh Jump
press finishes the third. This remains a bounded sequence, not arbitrary scripting.

`CampaignWaterTutorial` reuses the localized panel contract and references a stable
`missionChunkId` plus `waterRegionId`. `approachDistance` is 1–600 world units before
the pool's left bank. Its spotlight follows the referenced water's current bounds;
there is no duplicated authored water rectangle. Source decode checks the route
reference, and compilation plus runtime binding validate the water against the
actual captured/generated mission, including disabled lessons. Missing references
must be repaired before Build/Play. Chunk removal guards cover all world lessons.
`CampaignSwimmingTutorial` reuses the Jump target and retains Jump/resource reveals.
Its trigger is optional: the player can bypass every pool without delaying other
lessons. It remains eligible for swimming in any later pool during the attempt.

`CampaignDecorationTutorial` shares the panel and water-reference resolver. Its
`decorationPrefabKey` selects exactly one collision-free visual sprite in the
referenced mission chunk. The materializer and generator preserve `prefabKey`
in `ChunkVisualSpriteRel` as visual metadata, including through rotation. Missing,
solid, repeated or multi-sprite prefab targets fail compilation/binding, even for
disabled lessons. The editor uses the same eligibility rule. Position, scale,
reflection and rotation do not change the reference; the spotlight uses current
rendered bounds, including center rotation, rather than a copied authored rectangle.

`CampaignGapTutorial` references `missionChunkId`, `nearGroundShapeId` and
`farGroundShapeId`, plus a 1–600 world-unit `approachDistance`. The shared
`campaignTutorialGaps` selector reads actual compiled terrain: adjacent rectangular
solid ground shapes with level exposed ledges, no collision spanning the opening,
and no overlapping water. Visual-only pit dressing is ignored. This deliberately
supports the current flat, dry, single-chunk lesson, not arbitrary slopes or
platform routes. Missing/rekeyed/filled/wet targets fail Build/Play, even disabled.
Moving the banks updates the trigger and spotlight without copying coordinates.
The spotlight target extends 24 units above and 48 below the ledges; authored
fractions control its padding and shape. This selector is presentation validation,
not a reachability solver or a new collision authority.

`CampaignPlatformTutorial` references `missionChunkId` and `platformPrefabKey`,
with an approach distance of 1–600 world units. `campaignTutorialPlatforms` uses
compiled placement lineage to require exactly one instance of that prefab, only
one-way collision, an exposed upper surface and rendered visuals. Multiple visual
tiles or collision shapes within that placement remain one target. Repeated prefab
instances, removed targets or changed-to-solid collision fail Build/Play even for
disabled lessons. Moving/resizing the instance retains the reference. Its spotlight
unions current sprite bounds using the shared `campaignTutorialSpriteBounds` helper;
its approach edges come from compiled collision, independent of visual padding.
Core terrain and render contracts are unchanged.

`CampaignBlessingTutorial` selects the mission's `blessingObjectiveShrineId` through
its own `shrineId`, with a 1–600 world-unit approach distance. All three pages own
bilingual text, reveals and manually editable spotlights. Ordered targets are
shrine, shrine, blessingResources; continuations are movement, Next, movement.
The first page requires objectives and Jump; the last requires resources and the
blessing indicator. Source validation requires the selected marker and objective
to agree, even when guidance is disabled. Removing guidance does not remove the
Core objective. Editor mission settings can remove it after its lesson is removed.

`campaignTutorialShrine` reuses the real interaction-surface resolver and exact
placement identity. Bounds include the top and room for fire, unioned with prefab
art when its instance is unambiguous. Repeated prefabs and direct terrain tops
remain selectable through exact marker bindings; sprite metadata does not have
instance identity, so ambiguous art uses the surface envelope. Moving the marker
across chunks follows its stable ID. Missing support rejects compilation/Play.

`CampaignMobilityTutorial` shares the single-panel contract and requires a mobility
reveal. It references a stable mission chunk and `triggerX` in 0–600 chunk-local
world units. Reporting for Duty uses chunk eight X 522 (world X 4722), at the bush
beyond the pool and before the downhill seam. The manual spotlight targets the
real Mobility control. Source validation rejects missing chunks even if disabled.

The route order follows blessing. A committed player snapshot must be grounded,
not swimming, at or beyond the trigger, with valid affordable mobility, zero
mobility cooldown and no dash/stun lock. Delayed readiness or an airborne crossing
retains the lesson until the next eligible grounded snapshot. These are existing
HUD facts; Core still owns activation, cost and cooldown. Fresh mobility continues
through the same host admission and semantic dispatcher as Jump. Touch tap and
Shift resume and enqueue the actual action; old holds, repeats and unrelated
actions cannot dismiss it. Pause preserves guidance, backtracking does not repeat
it, and restart resets it. Éloïse Dash/Double Dash and Willow Dash use this card.
Other equipped skills retire the Dash-specific card and reveal their control at
the grounded trigger, preserving the build and avoiding impossible instructions.

The editor reuses `CampaignTutorialDialog`, bilingual fields, mandatory reveals
and manual spotlight editing. `CampaignTutorialPositionPicker` edits chunk/X and
previews a trigger line over captured chunk art. Apply uses the existing revision
guard and command history. `TapAbilityControl` shares actual button geometry,
radial placement and resource/cooldown feedback between Jump, tap Mobility and the
authoring canvas. Non-tap mobility retains its existing controls.

The pure-Dart `runner_content_pipeline/campaign_tutorial.dart` owns immutable
presentation values. UI uses that narrow library without repository I/O or compiler
state. Core has no tutorial fields. The generator projects source to Campaign
metadata and its existing content digest. Guidance adds no replay commands or rewards;
the independent blessing goal and same-tick interaction ordering are described in
[campaign runtime](campaign_runtime.md) and [simulation ordering](runner_core_simulation_contract.md).

The editor's **Tutorial sequences** tab selects **Visible at mission start**,
edits each lesson and its **Reveal and keep visible** set, and previews through
the standard launch dialog. Edits use revision-guarded mission replacement,
Undo/Redo and transactional Save. Dialog Cancel discards drafts; stale results
cannot replace a newer document. `RunnerPlaytestAppearance` captures the sequences
and initial HUD immutably. Restart reuses that capture with fresh progression;
fresh Play captures accepted edits. Previewing the coin lesson starts the actual
mission and requires collecting its coin.

## Combat encounter

`CampaignCombatTutorial` is the third `CampaignSteppedTutorial`: ordered enemy,
Projectile and Primary pages. It binds an exact `missionChunkId`/`markerSalt` and
requires a guaranteed spawn in the captured mission, even while disabled. Source
values include approach distance, bilingual practice hint, per-page text/reveals
and relative spotlights. Primary cannot be revealed by its first two pages.

Core's `CampaignSession` retains ordinary marker identities independently of
required kill objectives and removes dead bindings before cleanup/recycling.
`GameCore.campaignCombatOpportunity` projects a read-only current-tick result
through `GameController`: live actor identity/position, stationary target and player idle state, blade
capsule overlap against the current vulnerable body, and projectile lifetime reach
with the shared terrain sightline. It neither predicts a guaranteed future hit
nor changes damage, aim, movement or AI. Tutorial policy requires the entire enemy
body and authored spotlight to fit inside the visible device viewport, plus grounding, slot validity,
affordability and cooldown readiness before pausing. Runtime and editor share the
same spotlight geometry. The mounted `RunnerGameplaySurface` lends a layout resolver
that intersects the camera canvas with the actual device crop. It is rebound on
attempt replacement and detached on disposal; no state is mutated during build.
Melee guidance
waits for the real approach to stop: homing forecasts cannot anticipate an AI stop
during windup, so an opening at the outer reach edge can otherwise miss.

`PlayerAttackExecutedEvent` is emitted once when a player melee delivery or
projectile volley is actually created, after windup. Rejected presses and cancelled
windups emit nothing. Both execution systems expose optional event callbacks;
GameCore supplies its normal event queue. No command encoding, simulation ordering,
resource deduction or replay result changes. Events arrive before the completed-tick
snapshot listener; the tutorial records them and publishes presentation after that
snapshot is installed.

`CampaignCombatGuidance` owns only approach/projectile-practice/melee-practice/done
phases. The real ranged execution locks further Projectile input through shared
semantic admission, including touch, keys, mouse and programmatic actions. The HUD
keeps the control visible and dimmed; cooldown values stay genuine. At melee reach
the controller reveals Primary and pauses. Its fresh press resumes through normal
host/router admission. Only real melee execution completes practice and unlocks
Projectile. Cancelled windups leave the corresponding action retryable. Early target
death/missing spawn retires guidance and reveals both controls. Unsupported builds
are preserved and reveal both at the approach; the current prose supports Éloïse's
starting Snap Shot and Seeker Slash only.

The shared `CampaignTutorialPracticeHint` renders authored localized text in mobile
HUD, desktop HUD and HUD-free editor Play. It never captures movement or attack
input. Pause/lifecycle cancellation, disposal and restart remain owned by the shared
attempt bindings. Editor forms reuse three-page editing, marker selection, language
tabs, spotlight canvas and revision-guarded domain commands.

## Attempt ownership and tick ordering

`RunnerGameplayBindings` owns `CampaignTutorialController` alongside the semantic
dispatcher and input cancellation. Product and editor configure the same controller;
other hosts default to no lessons and all HUD features. The controller owns the
active lesson and step, completed lesson IDs, suspended flag and cumulative visible feature set.
Stop detaches its GameController tick listener before runtime retirement; bindings
owns disposal. No completion is persisted across attempts or accounts.

After readiness (including product recorder readiness), the movement card holds
tick zero. Start/Enter cannot bypass it. A fresh admitted movement down event asks
the host to accept the lesson and unpause synchronously, then follows normal device
source tracking, dispatcher/router and tick commands. The same hold continues into
play. The transition preserves the movement cancellation epoch and focus ownership.

The GameController completed-tick hook runs after the committed snapshot and before
another fixed tick. Once started, three metres of cumulative horizontal walking
in either direction activates the pending objectives lesson and reveals objectives.
`CampaignTutorialController.objectivesWalkDistance` uses the shared world/metre
scale. Per-tick observed travel is capped by horizontal velocity to exclude visual
anchor shifts on turns or settling; idle time, wall-clock waits and pauses do not
advance practice. The trigger remains `movementStarted` in existing authored data.
The first nonterminal snapshot with collectibles above zero activates the pending
coin lesson. The coin lesson reveals runStats. Each interruption cancels pending,
held and preview input, then pauses. The pickup and replay frame are already
committed; later ticks in that frame cannot advance. Terminal outcomes take priority.
Touch pointers are invalidated and keyboard repeat events cannot accept guidance.
A new movement press resumes those lessons with its own hold.

The chunk lesson activates on the first committed player snapshot at or beyond its
chunk origin. The controller receives the actual mission definition: generated
product mission or captured editor mission, never a separate route lookup in Play.
Next cancels input, advances a step and reveals its features without unpausing.
On the resource page, only fresh Jump passes host admission; that same physical
press follows the normal dispatcher/router and produces the real Core jump command.
Held keys, repeats, movement and premature Jump cannot dismiss it. Hosts preserve
the admitted press while restoring focus. Next does not take desktop gameplay focus.
Suspend/resume retains the current step; Stop rejects stale Next and Jump callbacks.
Introduced features remain visible. Stamina cost and regeneration remain Core-owned.

Route lessons retain source order. The first pending route lesson has priority when
ready; otherwise an eligible optional hint may interrupt without blocking it.
The water approach compares committed player X with the referenced bank minus the
authored distance, without a grounded requirement. Reporting for Duty uses 20
world units: world X 868, after its rock and before water at X 888. Fresh movement
dismisses this card. Swimming uses the existing authoritative `isSwimming` snapshot,
not a presentation overlap approximation. It waits for a valid, affordable stroke
and no jump/stun lock so paused clocks cannot strand the player on an unavailable
action. Fresh Jump dismisses the hint and follows ordinary input routing to the
real stroke. Each lesson completes once per attempt, regardless of backtracking.

Decoration guidance requires a committed grounded, non-swimming player at or
beyond the referenced water's right bank. It never pauses an airborne crossing
or requires first completing the optional swim hint. Reporting for Duty targets
`mission_chunk_2` / `water_1` / `pixel_fantasy_caves_tree_02` (bank world X 984).
Fresh movement resumes through the existing input gate. Its default reveals set
is empty. The renderer's existing 30% white decoration blend is unchanged.

Gap guidance waits for a committed grounded, non-swimming snapshot between the
near bank minus the approach distance and the bank itself. Reporting for Duty
uses `mission_chunk_3`, `ground_001` → `solid_002`: ledges at world X 1421/1490,
96-unit approach (X 1325). Fresh movement resumes; it never synthesizes Jump.
The player walks closer and times the existing jump. No success popup or default
HUD reveal follows. An airborne approach waits for safe ground; landing beyond
the far bank retires an unshown lesson, retaining any authored reveals, so an
early successful crossing cannot produce a stale warning or block later lessons.
Per-attempt completion also prevents backtracking repeats; restart resets it.

Platform guidance shares the gap's grounded approach and safe-bypass handling.
Reporting for Duty selects `mission_chunk_4` /
`tiny_swords_ground_platform_04_64x32_platform`. The default 64-unit approach
pauses at world X 1896, before the physical left edge at X 1960. The visual target
is X 1960–2024, Y 160–192; its physical right edge is X 2022. Fresh movement
resumes without synthesizing Jump or revealing additional HUD. An airborne arrival
is not interrupted; a grounded arrival beyond the physical right edge retires an
unshown explanation. There is no landing objective or success popup. Ordinary
Core one-way collision permits upward passage and descending top support.

Blessing guidance first waits for a grounded, non-swimming snapshot at or beyond
the selected top's left edge minus the approach distance. Reporting for Duty uses
marker `shrine` in `mission_chunk_7`, whose activation top is world X 3828–3852,
Y 160. Its 96-unit approach pauses at X 3732. Movement dismisses page one and starts
practice without marking the sequence complete. The objective stays visible;
walking past or missing the basin leaves it pending, including on return.

Only `CampaignSnapshot.blessingReceived` opens page two, after the actual grant.
A prior/early grant skips the obsolete objective prompt. Next opens page three,
revealing the existing blessing badge beside the resource bars; fresh movement
finishes the sequence and resumes. Suspended/stopped guidance cannot advance.
No timers or proximity checks grant success. This bounded practice phase does not
add a general branching or scripting engine.

Hidden abilities are gated in `RunnerSemanticActionDispatcher` for begin, trigger,
commit and aiming. Desktop adapters reject hidden actions before retaining keys.
Release/cancel paths still work. HUD button visibility alone is never the input
boundary. This is client guidance, not a new server anti-cheat rule.

Hosts retain readiness, foreground, calibration, exit and restart authority.
Manual pause suspends an active lesson; Resume restores guidance while simulation
remains paused. Product mobile background/resume restores guidance only if that
lifecycle transition owned the pause; desktop/editor retain their explicit resume
policy. Calibration cannot resume play. Restart creates a new tutorial controller.
The editor phase remains running during guidance, with its controller paused;
manual/lifecycle/calibration suspension uses the ordinary paused phase.

## Geometry and presentation

`CampaignTutorialOverlay` renders the shared card and paint-only grey veil.
`MovementControlPlacement` supplies the movement authoring layout;
`CampaignObjectivesPanel`, `RunStatsPanel` and `RunHudActionsRow` provide the actual
objective panel, counters and adjacent actions in both HUD and authoring canvas.
`JumpControl` and `ResourceBarsPanel` also supply the real runtime/authoring targets;
shared run control tuning preserves the existing layout and feedback behavior.
Obstacle, water, decoration, gap, platform and shrine bounds add their mission chunk origin and use the snapshot camera plus
fitted viewport metrics to reach HUD coordinates. The authoring canvas fits the
actual captured chunk composition with the same local bounds. Jump and blessing pages share `CampaignStepsTutorialDialog`: independent text,
reveals and spotlights in one transactional edit. Blessing Apply sets the selected
mission shrine objective atomically; the standard revision guard protects stale dialogs.
Its third page previews the real `ResourceBarsPanel` and `LevelBlessingsHud`.
Water and swimming use the existing localized panel dialog. Water adds chunk/region
selection and approach distance; its canvas previews the captured chunk and reuses
the same manual spotlight drawing/dragging. Invalid or missing regions cannot be
silently rebound by Apply. Swimming previews the actual shared Jump control.
Decoration shares that dialog and canvas, adding the eligible-prefab picker and
using the selected water only for the landing trigger. Missing or ambiguous
prefab references remain invalid until explicitly repaired.
Gap and platform share the panel and canvas, with compiled target selection and
approach distance. Water, gap and platform use one target-picker and distance-field implementation;
missing selections remain invalid until explicitly repaired. Existing Save,
Undo/Redo, stale-dialog guards and captured Play ownership remain unchanged.
The objective card stays horizontally centred on the game display, independently
of side-panel visibility/width and its own text or completion checkmark.
Named coin and blessing objectives use the shared `HudPanel`, with localized `Collect a coin 0/1`,
then `Collect a coin 1/1` and the theme's green success check. The blessing row uses
`Receive a blessing 0/1`, then `Receive a blessing 1/1` with the same check. The row
waits for its introduction, unless that guidance is absent/disabled or the grant
already occurred. Named goals are excluded from aggregate counts even while hidden.
Other objective types retain their aggregate/exit presentation.

`CampaignHud` owns a presentation-only completion tick per named objective and its controller listener.
It rebinds on controller replacement and unsubscribes on disposal. Each completed
row holds for three seconds of committed gameplay, then fades over 250 ms of
play and is removed, including the empty frame. Tutorial/manual/lifecycle pauses
and terrain waits preserve the acknowledgement. A new attempt resets it. The
stateless `CampaignObjectivesPanel` accepts completion age; the authoring preview
uses zero age and cannot expire while editing. Runtime target bounds are measured
in HUD logical coordinates. The calibrated device transform applies to game, HUD and guidance.

Spotlight x/y and width/height are fractions of the target. Shapes are ellipse or
rounded rectangle; offsets are bounded to [-2, 2], sizes to [0.25, 4]. Authors draw,
move and resize with shared scene rectangle math. Movement variants keep independent
shapes; floating joystick targets its activation area. Painting clips to device
bounds and never changes interactive hitboxes. Long cards scroll above movement;
three-step cards keep their Next action outside the scrolling text. When the
normal card would overlap a world spotlight, shared placement uses available
space beside it, or above it on a narrow display; the content remains scrollable.

Hidden-HUD Play retains the explanatory card and keyboard continuation without
inventing an invisible spotlight target. Visible-HUD Play uses the selected touch
variant even when keyboard input is available. Text follows the host language with
English fallback. The authoring diagram fits its panel; actual Play retains the
existing calibrated physical size.

## Scope

Only these twelve bounded sequence types exist. No annotation arrows, arbitrary world
entity tracking, general branching, configurable practice conditions or account
persistence are implemented. Reporting for Duty targets its existing second-chunk
rock, water and tree, third-chunk gap, fourth-chunk platform, seventh-chunk basin
and eighth-chunk Dash trigger.
Authored geometry, replay commands and regeneration tuning are unchanged. The
Dash verification extends continuous traversal into the ninth chunk. It does not claim full-route, phone
hardware or physical monitor calibration acceptance.

Local timing, card and lifecycle evidence: [2026-11-13 verification](../verification/campaign-objective-card-2026-11-13.md).

Jump sequence evidence: [2026-11-13 verification](../verification/campaign-jump-tutorial-2026-11-13.md).

Water sequence evidence: [2026-11-13 verification](../verification/campaign-water-tutorial-2026-11-13.md).

Decoration sequence evidence: [2026-11-13 verification](../verification/campaign-decoration-tutorial-2026-11-13.md).

Gap sequence evidence: [2026-11-13 verification](../verification/campaign-gap-tutorial-2026-11-13.md).

Platform sequence evidence: [2026-11-13 verification](../verification/campaign-platform-tutorial-2026-11-13.md).

Blessing objective/sequence evidence: [2026-11-13 verification](../verification/campaign-blessing-tutorial-2026-11-13.md).

Dash sequence evidence: [2026-11-13 verification](../verification/campaign-dash-tutorial-2026-11-13.md).
