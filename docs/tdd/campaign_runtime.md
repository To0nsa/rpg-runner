# Campaign runtime and authoring

Movement, objectives, first-coin and three-step obstacle/jump explanations with progressive HUD are authored in **Tutorial sequences**;
see [tutorial presentation and input gating](campaign_tutorials.md).

Status: runtime, editor, campaign menus and authenticated progression implemented
locally November 11, 2026. Acceptance is recorded in the
[single checklist](../building/campaign/implementation.md). No deployment is implied.
Production mission layouts and build inclusion are authored by the user.

## Core ownership and lifetime

`CampaignMissionDefinition` captures an exact `FiniteChunkPatternSource`, terrain,
start, exit, authored gold/restoration pickups, surface interactions and required
visit/enemy/rescue targets.
Mission chunks have unique stable IDs; references remain attached when reordered.
Authored IDs use `mission_chunk_N`. Points, objectives and placement bindings use
`missionChunkId` in source JSON and Dart; each route entry keeps its `id` and
source `chunkKey`. This unpublished contract is renamed directly with its authored
data and generated catalogs, without legacy aliases or load-time migration.
Positions are local to 600×270 chunks. The initial resident-world admission cap
is 48 mission chunks, 256 combined pickups, 64 local interactions and 32 visit
regions, plus existing encounter capacities. These are capacity guards, not
measured mobile performance claims.

`GameCore.campaignPlaytest` and `CampaignPlaytestScenario` are tooling boundaries
without account or ticket authority. Runtime admission checks source ownership,
dimensions, active status, tier/group agreement, actual neighboring seams,
complete encounter/boss placements, stable enemy salts, guaranteed required
targets and exact supported start placement for both playable characters.
Mission combat comes only from authored content; there is no separate combat
permission flag. Mode copies omit enemy, rescue, boss content and traps; ordinary
chunk duplication preserves it.

All terrain and ordinary marker entities instantiate once and remain resident;
physics, statuses and lifecycle continue off screen. Ordinary enemy AI follows
the activation policy below. Campaign disables camera-based enemy/item culling,
rescue expiry and
behind-camera player death. Ordinary TTLs, damage, death cleanup and kill-plane
handling remain active. Projectiles resolve impacts normally, then retire during
cleanup after leaving finite horizontal bounds or the kill plane. Pickups cannot
respawn on return travel. Procedural coin/restoration spawning is disabled.

Existing actor motion bounds and the shared world motion authority enforce the
finite bounds for player, enemies and NPCs, including dash/blink/teleport. Bounds
apply before boss control narrows them. No continuation is generated after the exit.
`FiniteFollowCamera` follows both directions with fixed-tick smoothing, no scrolling
and finite framing. Boss framing reaches an exact framing tick. The runner keeps
its existing automatic camera and forward cleanup.

## Ordinary enemy activation and pursuit

Only `_spawnTrackEnemy` requests carrying mission chunk ID and marker salt are
registered in the lifecycle-owned `CampaignEnemyStore`. Rescue adapters, arena
actors, Runner and Training Field do not receive this component. The store retains
resolved home position/facing, return policy, `waiting`/`engaged`/`returning` phase
and a tick-based retaliation deadline. Entity destruction removes it before ID reuse.

`CampaignEnemySystem` runs after timer/lock maintenance and arena control, before
Derf transformation, guard rosters and shared AI target selection. A 280-unit
Euclidean player/home distance engages waiting or returning actors. Return-enabled
actors disengage beyond 600 units, unless positive damage has refreshed a two-second
retaliation window. Positive surviving HP loss invokes `recordDamage` during damage
resolution, including detached attacks and damage over time. Rejected or zero-damage
requests do not wake actors. The shared `combatTarget` gate returns null while
waiting or returning; it does not make those actors invulnerable or hide them from
rendering or player targeting. Hashash's reactive evade also respects the gate,
so an initial hit cannot strand a dormant actor in teleport-out.

Returning cancels pending actions and attached melee, retaining released projectiles,
world-anchored impacts, cooldowns, health and statuses. Ground navigation resolves a
stationary home snapshot through the current terrain bundle; no surrogate combat
entity is created. Existing graph planning, jumping, swimming and collision own
movement. Flying returns use the same clearance steering with home as the flight
goal. Arrival within four units on both axes returns to waiting without repositioning.
An unavailable route stays blocked instead of teleporting or resetting the actor.
Return-enabled navigation and actor motion share the home ±600 horizontal bounds,
intersected with mission bounds. Persistent followers retain only mission bounds.

The strict optional enemy placement boolean `returnWhenPlayerRetreats` defaults to
true; canonical source omits the default and preserves explicit false. The editor
switch uses the normal guarded command/Undo/Redo/Save path and survives moving,
duplicating and reordering markers. Compilation and generation project false values
into `CampaignMissionDefinition.persistentPursuitEnemies`, keyed by stable mission
chunk ID and salt; references must identify actual ordinary markers. Captured Play
and trusted runtime construction consume the same definition. No replay command or
snapshot shape changes. Existing campaign digests still bind authored policy bytes;
runtime behavior requires matching client/worker Core on the next authorized release.

## Objectives and terminal ordering

`CampaignSession` owns attempt-local progress. Required ambient targets bind to
mission chunk ID plus marker salt, then to the actual spawned entity. Missing required
placement rejects construction. Death is observed before cleanup; recycled IDs
cannot satisfy old targets. Losing an unresolved target fails the mission.
Required rescue outcomes are recorded once; failed required rescues fail the
mission. Authored bosses must be defeated and released before completion.

The optional mission `requiresFirstCoin` defaults to false. When enabled it adds
one objective and requires an authored coin at compilation/construction. During the
existing living-player objective phase, after pickup resolution, `CampaignSession`
latches the authoritative collected-coin count above zero. Snapshot fields
`firstCoinRequired`/`firstCoinCollected` drive the HUD count/checkmark. The completed
coin card retires after a short gameplay-time acknowledgement; this never clears
Core progress. Restart resets both.
Reporting for Duty enables this requirement; its revised content binding/digest
travels with the generated Core, client and issuer catalogs. No command or replay
encoding changes. Tutorial settings are independent and cannot satisfy the goal.

The optional `blessingObjectiveShrineId` selects one authored `CampaignShrineSource`.
It compiles to Core's `(missionChunkId, bindingKey)` required target and adds one
objective. Missing/null/invalid markers reject authoring; removing a selected shrine
requires reassigning/removing the objective first. Moving it preserves identity.
A matching committed interaction activation latches `blessingReceived`; proximity,
another shrine or tutorial completion cannot count. `blessingRequired` and the
shared `CampaignObjective` discriminator expose progress to HUD consumers.
The fire activation precedes the living-player objective/exit gate, after death
and objective-failure checks; the blessing and checkmark share one snapshot.
Reporting for Duty requires both coin and blessing; its revision/digest changes
in all generated catalogs. Guidance disablement has no effect on the requirement.

Visit regions record living-player center contact. After combat/death resolution,
Core requires every objective plus exit contact to emit `missionCompleted` once.
Player death takes precedence; failed required objectives emit `missionFailed`.
Terminal attempts freeze as normal. `CampaignSnapshot` exposes objective totals,
failure and exit coordinates. Events reuse statistics and gold. Campaign excludes
all elapsed ticks from survival score; distance remains furthest progress, so
idling and backtracking cannot add survival/distance points.

## Source and build contracts

`assets/authoring/campaign/chapter_defs.json` uses strict schema 1. Chapters
are grouped under one campaign with required English/French `title` and `map`
metadata (`assetPath`, intrinsic `width` and `height`). Map references use portable
lowercase snake_case paths under `assets/images/maps/`, with PNG, JPEG or WebP
artwork. The editor's Campaign settings dialog uses the native file explorer,
reads dimensions and previews the selected repository image. Cancel discards the
form; Apply dispatches one revision-guarded semantic edit, using ordinary
Undo/Redo and transactional Save. Changing artwork preserves chapter coordinates.
Build captures map files, rejects absent/invalid artwork or changed dimensions,
and projects the localized campaign name and map metadata to the game. The game
uses those dimensions for map framing and the selected image for warmup.

Campaign, chapter and mission forms share language tabs that retain both drafts
and reveal the first invalid language on Apply. Shared settings stay outside the
tabs. Chapter settings use the catalog map and workspace image in a zoomable
placement view. Shared `EditorLocationMap` owns view state and editor input;
inverse scene transforms keep clicks/drags and numeric X/Y fields in sync.
Its landscape/portrait Game preview uses the game's `MenuScaffold`, `MapViewport`,
`MapLocationLayer` and `MapLabelButton`, including live draft names and positions.
`MapLocationLayer` measures labels; `placeMapLabels` keeps them inside the initial visible map,
penalizes overlap with pins/earlier labels, then favors short leaders with stable
source-order ties. The shared leader geometry finishes at each measured label
edge without crossing it. Geographic dots remain attached to the same image
coordinates through zoom/pan. Crowded views choose the least-overlapping candidate;
placement view coordinates always refer to the complete image.
X runs left-to-right and Y top-to-bottom, each from 0 to 1. These remain dialog
drafts until Apply; Cancel leaves the plugin document unchanged. The chapter
sidebar omits descriptions and reward summaries while retaining their actions.

Deleting the selected mission requires its exact English title and a matching
mission snapshot. Chapters retain at least one mission; selection moves to the
next mission or previous last entry. Optional catalog `retiredMissionIds` is a
sorted source-only reservation list (absent means empty, null/duplicates/active
IDs reject). Delete adds the identity; draft allocation cannot reuse it after
Save/reopen. Undo/Redo may restore that same mission and removes its reservation
while active. Save still seals newly created identities; history cannot implicitly
remove persisted missions without an explicit deletion record. Chunk sources and
previous account progress are not deleted. Runtime generation projects only active
missions, using the usual authored inclusion and coordinated release workflow.

Mission order within each chapter defines sequential prerequisites; chapters have independent
mission progressions. Missions carry stable identity/revision,
English/French title and assignment, regional level/theme, explicit inclusion,
first-clear XP/gold/catalog-unlock policy, ordered mission chunks and local markers. Incomplete
route/start/exit drafts are saveable but cannot Play or enter Build.

The optional schema-1 `placements` array adds stable snake-case IDs (64 characters)
and typed `gold`, `gem`, `enemy`, `trap`, `rescue` and `shrine` records. Absence
means empty; explicit null, unknown keys/types and duplicate placement IDs fail.
Empty arrays are omitted on export, preserving the encoding of existing missions.
The source cap is 512 records; runtime admission applies the stricter type caps.
Points use existing mission chunk bounds. Trap and rescue records reuse the shared
decoders; incomplete rescue rosters can Save but cannot Play/Build. Required
local enemies/rescues project to the existing mission chunk-plus-salt/encounter
objectives. Duplicate enemy salts and encounter IDs within a mission chunk fail.

Compilation composes inherited chunk actors with each mission chunk's local actors.
Trap order uses the existing comparator and terrain-relative depth conversion;
encounters sort by ID, and enemy source order is retained. Terrain remains
deduplicated by shared chunk key. The generator emits separate effective patterns
when local actors exist, rather than collapsing repeated chunks to one pattern.
Authored pickups use existing Core collection/restoration systems. No new reward
or replay wire policy is introduced; placement source bytes enter the existing
content digest and are captured by Play.

Shrine records attach an effect to an existing flat, collidable top, identified by
prefab placement/shape lineage or a direct terrain shape. They add no geometry.
The shared Core surface resolver validates the exact center/activation width and
scale. Compilation also checks the saved surface height; changed support requires
reattachment. The binding is restricted to its stable mission chunk ID. Existing
manual bindings remain inherited, with conflicting identities rejected. Top
contact, once-per-instance fire state and the nonstacking blessing retain the
[world-interaction contract](world_interactions.md).

The pipeline compiles explicit strings without filesystem access. The root atomic
generator captures mission sources and transitive chunk/prefab/tile/material
dependencies, then emits Core missions, client display metadata and server policy
together with a SHA-256 content digest. Campaign terrain is independent of runner
pool inclusion. Generated files are outputs, never authoring input.

Chunk-v2 adds optional `usage: runner|campaign`; omission means runner and explicit
null is invalid. Campaign-only chunks retain their level ownership and directory.
Runner generation, scheduler/seam admission, level capacity and whole-Level Play
exclude them. Explicit missions and focused Chunk Play may consume them. Active
status is still required for Play; usage and lifecycle status remain independent.

## Editor lifecycle

Mission Play opens setup before capture/runtime creation, with mobile HUD enabled
by default and arrows/floating-joystick/fixed-joystick selection. Accepted choices
remain fixed through the attempt and Restart. Device presets and custom landscape
dimensions/DPR constrain the complete game/HUD preview; resizing the editor scales
that display together without changing its logical layout. The viewport covers
the simulated display; the default scenario uses the character catalog's starter equipment, including
Éloïse's shield. It reuses the game HUD and semantic input dispatcher while
retaining editor-owned lifecycle panels and backend isolation. See the
[playtest presentation contract](editor_chunk_playtest_host.md#presentation-and-input).

The Campaign plugin owns semantic edits, revisions and transactional Save. It
reuses shell history, pending-change handling, navigation, Build and captured Play.
Undo after Save retains current baselines; dependency drift blocks overwrites.
Mission reordering changes prerequisites explicitly. Route reordering preserves
mission chunk identity; the workspace blocks removing a mission chunk with markers.

The workspace uses the shared responsive 3:8:4 library/workspace/sidebar shell.
The left panel owns chapters and missions. Contents reuses `AuthoredChunkCard`
and `ChunkCompositionPreview` for searchable campaign-only chunks. Group and
difficulty filters intersect with text search; options come from the campaign
catalog, independently of the current search. Append chunk creates a stable route
mission chunk without changing tabs or clearing the browsing context. Runner layouts
must first be copied using Chunk Creator's Copy to Campaign action to appear in
Contents. Route owns exact mission chunk ordering. Markers gives the central scene
the available workspace height and puts its visual library, selected marker
properties, placed-marker list and shared objectives in one scrollable authoring
sidebar, using the same section cards as Chunk Creator. Tabs and scene tools stay
above the canvas. Narrow windows expose Chapters / Workspace / Authoring tabs;
choosing a placement brush returns to Workspace.
The library starts on None, which selects the scene selection tool and disables
Place. Placed markers starts collapsed; its rows and count show all mission
markers for None and only the chosen kind otherwise, including legacy coins in
Gold coin. The library choice persists through scene selection/tool changes;
filtering affects only the sidebar, leaving scene markers and hit testing intact.

Contents and Route retain their preview and lower browsing shelf. The shelf,
sidebar and route overview remain mounted across tab/responsive changes, with
hidden focus and animation disabled. The preview shows selected chunk art in
Contents or the assembled route in Route/Markers. Route art reuses
`ChunkCompositionPreview.joined`, including terrain, scenery, water and the
mission's parallax theme. The 600x270 mission chunks share a scale fitted to the
canvas height, with a horizontal scrollbar and lazy mission chunk rendering.
Below 100% zoom, the route stays vertically centered in the space above the
horizontal scrollbar. Enlarged routes retain vertical scrolling.
Marker overlays remain mission chunk-local; repeated chunks keep distinct content.
The shared Chunk/Campaign Select/Place/Move controls, 8-pixel snapping,
duplicate/delete, Escape cancellation, Ctrl+drag pan and Ctrl+scroll zoom use
existing scene utilities. Region corners
reuse the shared rectangle gesture. Each completed drag dispatches one revision-
checked mission replacement. Moving a local target rebinds explicit objectives;
deleting it explicitly removes its objective too. Duplicating a route mission chunk
copies local content with fresh placement/rescue IDs while preserving singleton
start/exit and mission chunk-scoped enemy salts. Geometry/source bytes stay shared.
Scroll positions are view state scoped by mission. Placement warnings overlay
the canvas without intercepting pointer input; showing or clearing feedback must
not resize the viewport or change the route scale under the pointer.

Scene controls reuse Chunk Creator's zoom widget and actor-terrain selector.
Show grid is independent of Snap 8 px. Visual preview shows only parallax,
terrain, scenery and water, hiding mission markers, actor previews and diagnostic
overlays; placement, properties and Delete are disabled, while pan/zoom remain
available. Entering preview resolves valid field drafts and rejects active
gestures or invalid fields. Leaving it restores tool, selection and overlay
preferences. Tool/tab changes retain the mounted overview's zoom and scroll
controllers; view-only controls never enter document history.

The viewport mechanics are shared with Chunk Creator through
`EditorSceneViewportController` and `EditorScenePointerRegion`: zoom limits and
stepping, reset/restore, centering, coordinate conversion, and pointer/wheel
ownership have one implementation. Chunk configures a centered free canvas;
Campaign configures a height-fitted route with bounded scroll controllers and
retains its lazy mission chunk renderer. Campaign input spans the full viewport
and resolves the current scroll transform before mapping to mission chunk-local
coordinates, so navigation works in empty margins and survives mission chunk
recycling. An edit drag blocks navigation until release/cancel; Ctrl changes
mid-drag cannot turn an edit into a pan. Shift+wheel scrolls the bounded route
horizontally. Source commands and semantic edit gestures remain domain-owned.

Actor terrain reuses `ChunkV2ActorTerrainProjection` and
`ChunkActorTerrainOverlayPainter`, including Éloïse, Grojib, Hashash, Unoco and
Derf policies. The existing per-visible-chunk geometry cache is reused across
pointer previews and actor switches. It displays local chunk evidence only;
it does not construct an assembled route graph or certify boundary traversal.
Unavailable accepted geometry is reported instead of inventing evidence.

In Markers the authoring sidebar reuses Chunk's enemy, trap and rescue inspectors;
pickup and fire properties edit position, resource, appearance and attachment
width/scale. Save and Play resolve valid field drafts and reject active gestures
or invalid fields. Undo cancels a local draft before undoing committed history.
Selected marker properties reuses `ToolSectionCard`, starting collapsed. Closing
it accepts valid field drafts; invalid drafts keep the section open.
Inherited actors use Chunk's existing resolved placement previews; shared targets
can still be linked through the objective dialog. Other tabs' right inspector
shows mission/reward status, selected chunk usage and validation,
with inline mission settings and revision-checked reward dialogs. Narrow panels remain mounted
behind tabs.
Geometry opens in Chunk Creator through guarded navigation. Back reloads
dependencies and restores mission, workspace tab, search, group/difficulty filters
and valid chunk/mission chunk selections. Missing filter options reset to All when
sources reload. These view values never enter content history. Play hides and
excludes the editing workspace from focus until the shared session returns to editing.

Chapter bars expand independently and contain their mission list, settings and
reward controls. Expansion is presentation state, never content history. Restored
mission selection expands its chapter. Create chapter collects bilingual metadata
and normalized map coordinates, allocates a unique stable ID and selects a fresh
excluded mission. Add mission appends and selects an excluded draft in that chapter.
Creation inherits only the current mission's region/theme (the chapter's last
mission when appending); no routes, objectives, pickups or rewards are copied.
Metadata edits preserve identities, missions and rewards and reject stale forms.
The source schema enforces 32 chapters and 16 missions per chapter.

Unsaved creations support Undo/Redo with valid selection fallback. Once saved,
their IDs form a history boundary: Undo cannot implicitly remove a persisted
creation. Confirmed mission deletion uses the reserved-ID history described above.
Ordinary value edits remain
undoable after Save. Revision reconciliation reuses current persisted revisions
when restored content matches the baseline, so Undo/Redo can become clean again.

The Mission Settings sidebar directly edits bilingual title/assignment, region,
background theme and Build inclusion. There is no mission-settings modal.
`CampaignMissionSettings` retains form drafts across panel/viewport changes;
Apply commits one revision-guarded edit, Reset discards fields, and shell Undo/Redo
discards a local draft before changing history. Save, Play, mission/tab changes
and source-changing actions first accept valid fields; invalid text reveals its
language tab and blocks the action. Repository writes remain plugin-owned.

The sidebar opens **First-clear mission rewards**. It shares
`CampaignRewardsDialog` with Chapter rewards: XP (0–100,000), gold
(0–1,000,000) and up to eight existing catalogue unlocks, with explicit skill
recipients. Chapters additionally support optional Willow. Mission schema 1 now
requires `firstClearXp`, `firstClearGold` and `firstClearItems`; authored sources
were updated explicitly, including Double Jump as an Éloïse jump unlock. The
removed `rewardAbilityId` and `combatAllowed` keys reject as unknown fields;
normal loading does not migrate old sources. Chapter fields retain their existing
absent-zero/empty defaults. Explicit null, duplicates, unsupported IDs/slots and
invalid skill recipients fail decoding. Gear is account-wide.

Apply dispatches one semantic edit, guarded by the mission revision or the entire
expected chapter reward snapshot; stale forms reject. Reward modals own cancellable
drafts; Apply commits through the page and Cancel leaves rewards untouched.
Save, source-drift guards and Undo/Redo remain plugin-owned.

The editor and Admin use `CatalogGiftPicker` from `game_presentation`, composed
from `tool_ui` catalogue controls. Core's `CatalogItemId`/`CatalogUnlock` derive
identities and recipient rules from the existing gear, ability, projectile and
character policies. `GameCatalogItem`/`CatalogGift` add shared names and icons.
The editor supplies an asset bundle redirect to its existing `rpg_runner`
dependency; no atlas copies or filesystem access enter either shared package.
A parity test compares the complete derived catalogue with Admin's backend fixture.

Copy to Campaign / Copy to Runner extends the existing stale-checked chunk lifecycle
transaction. The dialog suggests an available chunk name and accepts an edited
name using the lifecycle policy's identity/ownership validation. Each copy gets
a fresh key and revision 1, preserving terrain, prefabs, materials and water
while omitting enemy markers, rescue encounters, boss arenas and traps in both
directions. Ordinary Duplicate still preserves all source content.
Prefab/atlas/material assets remain shared. Mission-only start/exit/objectives
stay on the mission, as stated in the dialog. Campaign copies stay outside runner
pools; runner copies start deprecated until explicitly activated. Copying does
not rebind an existing mission chunk or prove reverse traversal.

Chunk Save reads current campaign references before staging and again before
replacement. Deleting, rekeying or moving a referenced chunk to another source
level is rejected until its mission chunks are rebound. In-place shared
geometry edits are allowed and invalidate the generated content digest.

Play freezes mission and dependency/image bytes, uses the shared host/input and
restores authoring on Stop. No runtime Build or canonical rewards are involved.

## Ticket, replay and account authority

`RunMode.campaign` is unranked. Only Competitive and Weekly require a board.
Campaign never creates a board, leaderboard or ghost, and cannot pass as Practice.
The create request adds `missionId` only in campaign mode. `levelId` continues to
identify the registered region. Server admission resolves the included mission,
checks all earlier missions in its chapter and the selected character/build, then
rechecks prerequisites in the issuance transaction. It uses a fixed combat seed 1.
Runner selection preferences are not changed by a campaign launch.

Ticket, replay and validated result carry `campaign: {missionId, contentDigest,
rewardPolicyVersion}`. Mission IDs are lowercase snake case of at most 64 characters;
digest is 64 lowercase hexadecimal characters; reward policy is currently 1.
Ticket/result require the binding exactly when mode is campaign. Replay includes
it in its canonical digest and prohibits boards alongside it. Old runner payloads
omit the field and retain their digest representation. Constructors and codecs
enforce these rules in AOT, not just assertions.

`GameCore.campaign` resolves only the compiled registry and matching digest. The
worker verifies ticket/replay bindings and resolves its own registry; it does not
trust client outcomes or source geometry. Missing compiled content is a worker
configuration retry, not a cheating verdict. The coordinated source compatibility
is `2026.11.11` across client, issuer and worker. Old incompatible tickets retain
existing retirement/recovery behavior. This source change does not update live
deployment identities or prepared board navigation route metadata.

Canonical `progression.campaign` is schema 1 with `missions` and optional
`chapters` maps. Missing state means no clears. A mission records cleared,
attempts, firstClearedAtMs and bests. New first clears also record `rewards` with `grantedAtMs`, `xp`, `gold` and `items`. Existing cleared
missions remain cleared without receiving retroactive rewards.
Bests compare completed score, then lower tick, under `contentDigest_v1`; historic
versions remain. Stable mission IDs prevent duplicate first-clear grants after a
content revision. The same Firestore settlement transaction updates wallet,
progress, ownership, player XP and its idempotent completion receipt. Retries and
concurrent distinct clears cannot grant first-clear rewards twice.

Verified accepted attempts keep collected gold. Only the first successful clear
grants the configured first-clear XP/gold/items, with no additional score-to-XP
conversion. Current defaults retain 40/48/60/76 XP (224 total) and zero bonus gold.
Failure/replay grants no first-clear rewards. Mission one adds `eloise.double_jump`
to ownership without changing a saved build; results offer an explicit equip action.
All four clears unlock `bountyHunter` (Willow). This gate applies to all accounts,
including existing pre-release accounts, without a grandfather migration. Locked
Willow selection normalizes to Éloïse while equipment/builds remain intact.

On a verified successful run that leaves every chapter mission cleared, settlement
also grants the configured chapter XP/gold/items if its stable chapter ID has no
receipt. `chapters[id]` records `grantedAtMs`, `xp`, `gold`, `items` and
`characterId` in the same canonical transaction. This receipt survives content
revisions, mission reorder and later additions, so completion grants do not repeat.
Mission XP and chapter XP pass through the existing player progression/level-up
flow; mission and chapter gold are added before collected-run-gold reconciliation.
Both reward bundles and their combined wallet total validate before any ownership
mutation. Overflow and invalid catalogue rewards reject settlement.
`ownership/catalog_rewards.ts` validates against the same store allowlist as Admin gifts, and
`grantCatalogOwnership` applies unlocks without equipping or duplicate compensation.
The inbox gift rollout gate is unchanged and does not govern campaign rewards.

New fields are included in the generated shared content digest. Reward policy
version remains 1: the ticket/evidence/catalogue digest match already fences
old content from this settlement policy. Client progress serialization preserves
mission and chapter receipts; results list configured mission gold and localized
catalogue names and acknowledge only settled rewards. The chapter modal
omits reward details.
Current Val Outpost completion XP/gold/items default to zero/zero/empty, preserving
the existing 224 mission XP and Willow balance until explicitly edited.

Campaign contributes verified player counters and discoveries; it is excluded
from runner achievements and competitive bests. Client previews may show earned
gold, but never authorize XP, mission clears, character availability or Next. Next
also waits for durable replay journaling. Existing submission recovery and account
deletion fences remain in force. Developer mode bypasses availability locally,
records no replay, and grants no account progress.

## Campaign Journal content and visibility

Campaign schema 1 accepts optional `journal` entries on the catalog, each chapter
and each mission. An entry contains exactly `title` and `body`, each with exactly
nonblank `en` and `fr` strings. Titles are bounded to 120 UTF-16 units and bodies
to 12,000. Absence means no entry; explicit null, partial translations, extra
fields and oversized text are rejected. Newlines are preserved. The immutable
`campaign_journal.dart` presentation contract is shared by source decoding,
the app catalog and editor preview; it imports no Flutter, I/O or Core authority.

Source Save/history and Build preserve Journal fields. Build includes them in
the existing shared content digest and client/backend metadata; excluded mission
updates are omitted from those projections. Core receives only the changed
digest, with identical mission geometry and behavior. Catalog updates therefore
retain the existing digest/compatibility release requirements; this feature does
not introduce deployment authority or alter settlement.

`CampaignJournalContent.visibleEntries` derives ordered passages from a supplied
confirmed `isCleared` predicate. The opening is unconditional. A chapter’s
introduction is visible when its first mission is available, or a published mission
in it has been cleared. Each available mission’s update is visible iff it is
cleared. Stable owner IDs identify passages; no separate Journal grant ledger,
endpoint, progress migration or completion-side mutation is needed. Replays,
failed/pending attempts and local Play do not earn Journal progress. Restored
clears work immediately; account replacement hides entries earned by the prior
account. Editorial corrections display from current built prose.

The editor embeds optional Journal fields in Campaign/chapter/mission forms.
Both translations participate in validation; hidden language errors are revealed.
Mission drafts join existing Apply/Reset, Save, Play and navigation guards.
Campaign settings use `settingsToJson` for optimistic guards including the opening.
All writes use CampaignDomainPlugin and its existing Save/drift/history transaction.
The preview resolves local drafts before reading the current document, then
`previewAfter` includes authored entries through the selected stable mission ID,
including excluded drafts. It never edits source or account state. Unknown
checkpoints fail explicitly. Opening-only preview reveals no chapter outcomes.

Library’s `CampaignJournalView` replaces the fixed opening ARB and reads
`progression.campaign.isCleared`; locale changes rebuild the same reading surface.
Future outcome titles are absent rather than shown as locked spoilers. The view
scrolls at compact widths and enlarged text. Generic empty-state/UI labels remain
app ARBs; authored story prose belongs solely to the campaign source.

## Campaign map presentation

`CampaignPage` keeps the regional map mounted beneath its transparent toolbar.
`CampaignRegionalMap` uses the same `MapViewport` as Town and Library
Locations for aspect-preserving full-screen artwork, pan/zoom, reset and
controller lifetime. Resize and reset restore the centered crop. Shared
`MapCallout` and `MapLabelButton` controls bind chapter coordinates to labels kept
inside the initial toolbar/system-safe area. Chapter selection opens a dialog
route containing `CampaignChapterDialog`. The route applies `SafeArea` outside
the dialog; its layout constraints size the panel to two-thirds of that safe
rectangle's width, including after rotation. The dialog's `ui.space.sm` outer
inset (12 logical pixels) adds a visible margin inside the safe area and limits
its otherwise full-height panel. All four corners are rounded. Its title and
dismiss control stay fixed; the chapter description and mission cards scroll below.
Mission headers use the smaller headline token in the chapter title's font
family. A leading disclosure arrow and single-line name share a row with the
action button. Arrow/name taps toggle description and progress below that row;
action taps remain independent. Expanded mission IDs are local dialog state,
preserved across run-route pushes and reset when the dialog closes. Disclosure
controls expose expanded semantics; truncated unlocked names retain full tooltips
and screen-reader labels. Locked entries render the localized Locked placeholder
instead of the mission name, omit the disclosure arrow, and disable expansion.
Their real names and descriptions are absent from tooltips and semantics as well
as the visible row. Canonical unlock updates reveal the name and enable expansion.
Draft availability takes precedence over progress: drafts show Coming soon;
built missions show disabled Locked with a lock icon or enabled uppercase PLAY
without an icon according to canonical unlocks (or the existing developer bypass).
The play label reuses `playButton`, as in the shared Play button. Every action
uses the same fixed small-button width from `UiButtonTheme`, independent of its
label or availability, with the existing compact text and touch-target height.
Close, system Back and the outside barrier dismiss it without resetting the map
transform. The dialog watches canonical `AppState` and retains the existing
mission availability/unlock checks and shared run-bootstrap route. Run launch is
pushed above the panel.

## Verification scope

Tests cover continuous outward/return travel across real joins for both characters,
combat, pickup persistence, exit/objective gating, bounds, terminal idempotency and
deterministic re-execution. Compiler tests cover draft round-trips, invalid sources,
duplicate mission chunks, unsupported start, strict usage and encounter preservation.
Editor tests cover Save/reopen/Undo, drift, captured Play, both copy directions,
referenced-source deletion and workspace controls. A generated temporary mission
crosses actual joins and returns through the real worker at 30 and 120 Hz with
matching terminal tick, gold and outcome. Local emulator tests verify progression
and concurrent settlement. Complete authored chapter traversal, live deployment
and device performance remain separate acceptance gates.
