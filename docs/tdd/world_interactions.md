# World interactions

World interactions are deterministic, player-only top-contact activations.
The first preset grants a level regeneration blessing and displays a looping
fire on the Forest vasque. Gameplay is in `runner_core`; Flame and the HUD
consume immutable snapshots. Traps keep their existing attack/cooldown policy.

## Manual authoring

`packages/runner_core/lib/interactions/world_interaction_catalog.dart` is the
manual attachment catalog. Each record identifies a chunk, prefab key, collision
shape, interaction preset, stable binding key, and visual depth relative to
terrain. The shipped record selects `tiny_swords_fire_vasque_01` /
`collision_001` in `forest_default_early_008`.

Without an exact `placementKey`, one matching prefab/shape must exist in the
chunk's admitted placement lineage. This follows ordinary editor moves and
scaling. Duplicating that prefab in the same chunk requires an explicit compiled
placement key to disambiguate the selected instance; moving an explicitly keyed
placement requires updating the manual key. Removing or renaming a bound
prefab/chunk requires updating the catalog. Missing or ambiguous selected
targets fail binding rather than silently disabling gameplay.

The highest horizontal edge of the transformed collision polygon defines the
activation surface and effect anchor. Exactly one such edge is required.
Collision is still compiled from existing authored source; the interaction
does not add solid geometry or infer collision from artwork. Authored flip and
scale are already reflected in the compiled polygon. The effect remains upright
and scales with its prefab; depth is explicitly configured in the binding.

Existing Prefab-v3 and Chunk-v2 JSON are unchanged. There are no new editor
controls. Chunk/Level Play consumes the same Core catalog and captured compiled
terrain. Its existing Save path cannot strip the attachment configuration.
Run the normal generator after changing geometry and run the binding tests
after changing either geometry or manual bindings.

## Ordering and lifetime

`WorldInteractionStore.synchronize` runs after the matching terrain publication,
alongside trap/encounter registration. Runtime identity is the streamed chunk
index plus binding key, so repeated templates produce independent occurrences.
Active view records retire with chunks; activation ticks are retained for the
attempt to prevent duplicate grants on reentry.

`WorldInteractionSystem` runs after final movement and death resolution, before
resource regeneration. A living player's final support must have the current
geometry version and tick, an upward normal, the selected prefab/shape lineage,
and a contact point on the bound top interval. Airborne contacts, sides,
underneath contacts, other actors, and stale support cannot activate it. Camera
visibility does not gate activation or remove the effect. A fatal tick cannot
be rescued by a new blessing.

Activation happens once per occurrence. `LevelBlessingStore` owns player effects
independently of source chunks. Blessing IDs are stacking keys: repeat grants
preserve the first grant tick and never add another copy. Different IDs can
contribute additive rates. Rates are integer hundredths of resource per second,
added after loadout-derived base rates in `ResourceRegenSystem`, using its
existing fixed-tick accumulators and maximum-resource clamps. Base rates and
equipment are never mutated. There is no instant restoration.

The blessing lives for the current attempt, including every streamed chunk.
Player entity teardown removes it, and every normal/playtest restart constructs
fresh state. Pausing, death freeze, and run end stop gameplay progression. The
effect is never written to a profile, ticket, loadout, or account persistence.

## Rendering and assets

`GameStateSnapshot.interactions` contains occurrence identity, active state,
surface position, scale, depth, and simulation elapsed ticks. The renderer can
mount an already-lit occurrence without an activation event. It samples the
four-frame loop at 10 frames/second using integer tick arithmetic; renderer
elapsed time has no authority and pause/death freeze retain the last frame.

`WorldInteractionRenderCatalog` defines a shared `(586,586,134,156)` source crop
and `(67,154)` pivot for all four supplied Fogo frames. Their bytes are preserved
under `assets/images/entities/effects/world_interactions/fire_01.png` through
`fire_04.png`. Display scale is 0.2 times prefab scale; the base sits one world
unit below the top surface. This retains source alignment and all opaque pixels.
The registry validates image bounds, joins the run-owned awaited registry loading,
and uses the existing camera-space pixel snapping and prefab depth scale.

Captured editor Play includes all four exact images, rejects missing/corrupt or
undersized frames, and the editor build watcher fingerprints this asset folder.
HUD blessing snapshots retain grant ticks: the initial two-second message and
persistent indicator use simulation time, so pause and remount do not create
timers or duplicate gameplay effects.

## Compatibility and checks

Game compatibility `2026.10.4` introduced equal flat regeneration bonuses of
0.10 health, mana, and stamina per second. Current `2026.10.6` source retains
those rates across the client, Functions issuance defaults, and validator. The HUD names it
“Bénédiction des Dames de la forêt”. The worker rejects prior gameplay versions,
including `2026.10.4`, because current Core also changes deterministic pickup
placement over non-collidable terrain and combat pose geometry.
Command/replay encoding is unchanged, and ranked scoring remains `score-v3`.
Ship matching client, Functions, and worker through the coordinated
[release workflow](deployment_workflow.md).

Focused checks cover actual landings on generated Forest terrain for both
characters at 30/60/120 Hz, normal versus captured Level Play, protocol replay,
invalid contacts, nonstacking grants, stream retirement/reentry, entity teardown,
restart, exact resource totals, clamps, fire frame/pivot/crop, and HUD feedback.
The airborne-start integration fixture isolates the mechanic; it does not
claim traversal of the preceding chunks, combat balance, or live release smoke.
