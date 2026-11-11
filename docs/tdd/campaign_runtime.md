# Campaign runtime and authoring

Status: runtime, editor, campaign menus and authenticated progression implemented
locally November 11, 2026. Acceptance is recorded in the
[single checklist](../building/campaign/implementation.md). No deployment is implied.
The four production missions are excluded drafts awaiting the user's layouts.

## Core ownership and lifetime

`CampaignMissionDefinition` captures an exact `FiniteChunkPatternSource`, terrain,
start, exit, authored gold pickups and required visit/enemy/rescue targets.
Occurrences have unique stable IDs; references remain attached when reordered.
Positions are local to 600×270 chunks. The initial resident-world admission cap
is 16 occurrences, 256 pickups and 32 visit regions, plus existing encounter
capacities. These are capacity guards, not measured mobile performance claims.

`GameCore.campaignPlaytest` and `CampaignPlaytestScenario` are tooling boundaries
without account or ticket authority. Runtime admission checks source ownership,
dimensions, active status, tier/group agreement, actual neighboring seams,
complete encounter/boss placements, stable enemy salts, guaranteed required
targets and exact supported start placement for both playable characters.
Combat-free missions reject enemy, rescue and boss content. Mode copies omit
that content and traps; ordinary chunk duplication preserves it.

All terrain and source entities instantiate once, remain resident and keep ticking
off screen. Campaign disables camera-based enemy/item culling, rescue expiry and
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

## Objectives and terminal ordering

`CampaignSession` owns attempt-local progress. Required ambient targets bind to
occurrence ID plus marker salt, then to the actual spawned entity. Missing required
placement rejects construction. Death is observed before cleanup; recycled IDs
cannot satisfy old targets. Losing an unresolved target fails the mission.
Required rescue outcomes are recorded once; failed required rescues fail the
mission. Authored bosses must be defeated and released before completion.

Visit regions record living-player center contact. After combat/death resolution,
Core requires every objective plus exit contact to emit `missionCompleted` once.
Player death takes precedence; failed required objectives emit `missionFailed`.
Terminal attempts freeze as normal. `CampaignSnapshot` exposes objective totals,
failure and exit coordinates. Events reuse statistics and gold. Campaign excludes
all elapsed ticks from survival score; distance remains furthest progress, so
idling and backtracking cannot add survival/distance points.

## Source and build contracts

`assets/authoring/campaign/chapter_defs.json` uses strict schema 1. Mission order
within each chapter defines sequential prerequisites; chapters have independent
mission progressions. Missions carry stable identity/revision,
English/French title and assignment, regional level/theme, explicit inclusion,
first-clear XP/ability policy, ordered occurrences and local markers. Incomplete
route/start/exit drafts are saveable but cannot Play or enter Build.

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

The Campaign plugin owns semantic edits, revisions and transactional Save. It
reuses shell history, pending-change handling, navigation, Build and captured Play.
Undo after Save retains current baselines; dependency drift blocks overwrites.
Mission reordering changes prerequisites explicitly. Route reordering preserves
occurrence identity; the workspace blocks removing an occurrence with markers.

The workspace follows Level Creator's 3:8:4 library/workspace/settings layout,
using the same responsive panel shell and `ToolPreviewWorkspace` preview/tab
sizing. The left panel owns chapters and missions. Contents reuses
`AuthoredChunkCard` and `ChunkCompositionPreview` for searchable campaign-only
chunks. Runner layouts must first be copied using Chunk Creator's Copy to Campaign
action to appear in Contents. Route owns exact occurrence ordering, while Markers
owns typed start/exit/objective/pickup controls. The persistent preview shows
selected chunk art in Contents or the assembled route in Route/Markers. Route art
reuses `ChunkCompositionPreview.joined`, including terrain, scenery, water and
the mission's parallax theme. The 600x270 occurrences share a scale fitted to
the preview height, with a horizontal scrollbar and lazy occurrence rendering.
Start, pickup, exit and required-region overlays remain occurrence-local; repeated
chunks keep distinct markers. Scroll positions are view state scoped by mission.
The right inspector shows mission/reward status, selected chunk usage and validation,
with the existing revision-checked settings dialogs. Narrow panels remain mounted
behind tabs.
Geometry opens in Chunk Creator through guarded navigation. Back reloads
dependencies and restores mission, workspace tab, search and valid chunk/occurrence
selections. These view values never enter content history. Play hides and excludes
the editing workspace from focus until the shared session returns to editing.

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
their IDs form a history boundary: Undo cannot delete a persisted chapter or
mission whose identity may own account progress. Ordinary value edits remain
undoable after Save. Revision reconciliation reuses current persisted revisions
when restored content matches the baseline, so Undo/Redo can become clean again.

Mission settings edits first-clear XP and the optional Double Jump reward. Chapter
rewards edits completion XP (0–100,000), gold (0–1,000,000), up to eight existing
catalogue unlocks, and optional Willow. Absent numeric/item fields in schema 1
mean zero/empty; explicit null, duplicates, unsupported IDs/slots and invalid
skill recipients fail decoding. Gear is account-wide; skills target a character.
Apply dispatches one semantic edit with the entire expected reward snapshot;
stale forms reject. Cancel leaves the document untouched. Save, source-drift
guards and Undo/Redo remain plugin-owned.

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
not rebind an existing mission occurrence or prove reverse traversal.

Chunk Save reads current campaign references before staging and again before
replacement. Deleting, rekeying or moving a referenced chunk to another source
level is rejected until its mission occurrences are rebound. In-place shared
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
`chapters` maps. Missing state means no clears. A mission records cleared, attempts, firstClearedAtMs and bests.
Bests compare completed score, then lower tick, under `contentDigest_v1`; historic
versions remain. Stable mission IDs prevent duplicate first-clear grants after a
content revision. The same Firestore settlement transaction updates wallet,
progress, ownership, player XP and its idempotent completion receipt. Retries and
concurrent distinct clears cannot grant first-clear XP twice.

Verified accepted attempts keep collected gold. Only the first successful clear
grants the catalog XP (40/48/60/76, totaling 224), with no additional score-to-XP
conversion. Failure/replay grants zero XP. Mission one adds `eloise.double_jump`
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
flow; chapter gold is added before collected-run-gold reconciliation. Overflow
and invalid catalogue rewards reject settlement. `ownership/catalog_rewards.ts`
validates against the same store allowlist as Admin gifts, and
`grantCatalogOwnership` applies unlocks without equipping or duplicate compensation.
The inbox gift rollout gate is unchanged and does not govern campaign rewards.

New fields are included in the generated shared content digest. Reward policy
version remains 1: the ticket/evidence/catalogue digest match already fences
old content from this settlement policy. Client progress serialization preserves
chapter receipts; results acknowledge only settled rewards. The chapter modal
omits reward details.
Current Val Outpost completion XP/gold/items default to zero/zero/empty, preserving
the existing 224 mission XP and Willow balance until explicitly edited.

Campaign contributes verified player counters and discoveries; it is excluded
from runner achievements and competitive bests. Client previews may show earned
gold, but never authorize XP, mission clears, character availability or Next. Next
also waits for durable replay journaling. Existing submission recovery and account
deletion fences remain in force. Developer mode bypasses availability locally,
records no replay, and grants no account progress.

## Campaign map presentation

`CampaignPage` keeps the regional map mounted beneath its transparent toolbar.
`CampaignRegionalMap` uses the same `MapViewport` as Town and Library
Locations for aspect-preserving full-screen artwork, pan/zoom, reset and
controller lifetime. Resize and reset restore the centered crop. Shared
`MapCallout` and `MapLabelButton` controls bind chapter coordinates to labels kept
inside the initial toolbar/system-safe area. Chapter selection opens a dialog
route containing `CampaignChapterDialog`. The route applies `SafeArea` outside
the dialog; its layout constraints size the panel to the left two-thirds and full
height of that safe rectangle, including after rotation. Its title and dismiss
control stay fixed; the chapter description and mission cards scroll below.
Chapter and mission headings use the same explicit title style. Mission
descriptions and progress sit left of a compact action button in one row.
Close, system Back and the outside barrier dismiss it without resetting the map
transform. The dialog watches canonical `AppState` and retains the existing
mission availability/unlock checks and shared run-bootstrap route. Run launch is
pushed above the panel.

## Verification scope

Tests cover continuous outward/return travel across real joins for both characters,
combat, pickup persistence, exit/objective gating, bounds, terminal idempotency and
deterministic re-execution. Compiler tests cover draft round-trips, invalid sources,
duplicate occurrences, unsupported start, strict usage and encounter preservation.
Editor tests cover Save/reopen/Undo, drift, captured Play, both copy directions,
referenced-source deletion and workspace controls. A generated temporary mission
crosses actual joins and returns through the real worker at 30 and 120 Hz with
matching terminal tick, gold and outcome. Local emulator tests verify progression
and concurrent settlement. Complete authored chapter traversal, live deployment
and device performance remain separate acceptance gates.
