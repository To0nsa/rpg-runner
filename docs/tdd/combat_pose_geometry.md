# Combat pose geometry

Implemented for source compatibility `2026.10.6`. Core owns combat geometry and
its fixed-tick pose selection; Flame reads snapshots. Runtime collision never
loads images. Replay/command format 1, `rules-v2`, `score-v3`, and `ghost-v1`
remain unchanged. This revision requires the coordinated release workflow.

## Geometry ownership

`CombatCapsule` explicitly stores two anchor-relative spine endpoints and a
radius in world units. Its bounds include rounded ends. Melee delivery authors
a `CombatStrikeProfile`: a capsule list for every source pose, with empty
windup/recovery poses. Compound blade arcs are unioned in stable entity-ID
order before applying the delivery's hit policy. Overlapping arc segments
cannot duplicate damage, even under `everyTick`.

`CombatPoseCatalog` holds the player directional variants, Warrior and Huntress
melee, Grojib's two strikes, Hashash strike/ambush, Unoco strike, and Derf impact.
Coordinates include presentation scale and use the catalog sprite anchor.
Player back-strike art faces left; its snapshot and geometry mirror together.
Aimed player melee rotates the complete action pose around that anchor, using
the committed direction. Horizontal front/back attacks remain upright.

`WorldContactCapsuleStore` remains the immutable, quantized terrain/navigation
shape. `CombatHurtboxStore` is the separately resolved vulnerable body. Roll,
leaning strike, air, hit and selected enemy poses can change combat bounds
without changing support, placement, movement capability, or terrain signatures.
Stable body poses reuse the terrain capsule as their baseline. Weapons, trails
and wings are excluded from vulnerable bodies. Missing required terrain capsule
state remains an invalid damageable actor; isolated tests may use the stable
baseline before resolving a pose.

## Clock and ordering

`ActionFramePolicy` maps committed, speed-scaled windup/active/recovery durations
to their respective source-pose ranges. Sampling is balanced across each range,
and the last available tick selects its final pose. A phase with fewer ticks
than source poses necessarily skips intermediate poses. Guard holds frame 3
during protection. Pure recovery abilities play the complete strip.

After movement and ability execution, Core resolves animation, body hurtboxes,
and projectile poses, then rebuilds broadphase and positions attack capsules.
Collision therefore queries current poses and current positions. Interrupted
melee poses have empty weapon geometry. After damage/death resolution a second
animation pass refreshes visible reactions without advancing locomotion phase
again. Simultaneous hits retain the pre-damage collision decision for that tick.

`DamageableTargetCache` encloses the resolved body endpoints and radius exactly.
Projectile, melee, mobility, and trap hits use this same cache. Mobility contact
uses the resolved source body, including the low roll pose.

## Projectiles and impacts

`ProjectilePoseSystem` owns flight age from the Core spawn tick, startup versus
repeat selection, and oriented damage geometry. Both live and ghost views
consume these frames. `ProjectileRenderCatalog.scaleFor` shares presentation
scale with the offline generator. Profiles fit opaque source bounds (alpha at
least 192), excluding translucent glow, and subtract the end radius from the
shaft length. NPC spear/arrow profiles also follow their changing thickness.
The existing poison dart retains its trap-authored capsule.

Regenerate after changing flight art, anchors, source-frame layout, or scale:

```powershell
python tools/combat/generate_projectile_profiles.py --dart <dart-sdk-executable>
python tools/combat/generate_projectile_profiles.py --dart <dart-sdk-executable> --check
```

Python with Pillow and the root Pub workspace resolution are required. The
generated Dart data remains portable. Physical projectile terrain colliders
remain separate from their visual damage silhouettes. Ordinary and piercing
travel use swept capsules; piercing contacts sort by arrival fraction, then
entity ID, and retain target deduplication.

Derf's explosion owns its 16-pose timeline at 0.05 seconds per pose. Only poses
2 and 3 damage, beginning six ticks after release at 60 Hz. Blank/startup and
dissipation poses are harmless. The hitbox remains world-anchored and dedupes
across the entire effect. Live and ghost impact visuals use simulation tick age
and freeze with simulation rather than advancing on render time.

## Snapshot and debug contract

`EntityRenderSnapshot.combatCapsules` contains anchor-relative, already oriented
body or damage geometry. Sprite rotation is independent; overlays must not
rotate these capsules again. `CombatCapsuleOverlay` draws those exact endpoints
and rounded ends. Actor/projectile outlines and compound attack overlays share
snapshot position interpolation with their views. AABB placeholders are no
longer used for live combat debug shapes.

Guard protection remains omnidirectional by owner instruction. It is damage
middleware, not a front-shield collision volume. Geometry does not introduce
roll invulnerability or directional guarding.
