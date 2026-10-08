# Combat pose geometry

The base implementation shipped in compatibility `2026.10.6`. Core owns combat
geometry and its fixed-tick pose selection; Flame reads snapshots. Runtime
collision never loads images. Replay/command format 1, `rules-v2`, `score-v3`,
and `ghost-v1` remain unchanged. This revision requires the coordinated release
workflow.

## Geometry ownership

`CombatCapsule` explicitly stores two anchor-relative spine endpoints and a
radius in world units. Its bounds include rounded ends. Melee delivery authors
a `CombatStrikeProfile`: a capsule list for every source pose, with empty
windup/recovery poses. Compound blade arcs are unioned in stable entity-ID
order before applying the delivery's hit policy. Overlapping arc segments
cannot duplicate damage, even under `everyTick`.

Compatibility `2026.10.11` represents multi-strike attacks with an explicit
`CombatCombo` on the profile. Its ordered `strikeStartFrames` identify the
individual strikes of one activation. `HitboxFollowOwnerSystem` advances `HitOnceStore`'s per-hitbox
window monotonically before collision; only a later authored swing/pulse resets
the target ledger. Revisiting a frame cannot reopen an old strike, and ordinary
profiles keep one window for their whole lifetime. Goddess claws start at frames
4/7/12/15, Shoggoth sweeps at 5/7 and spin passes at 3/6, and Voidcaller beam
pulses at 5/7/9. These frames retain the timing introduced in `2026.10.10`.

### Combo damage and post-hit protection

`CombatCombo` is shared by player, NPC and enemy attack profiles, with no boss
identity check. It requires at least two strictly increasing in-range frame
indices and a per-strike hit policy; `everyTick` is rejected. A profile without
a combo keeps one hit window. Separate committed attacks, including an AI's
armed alternate attack, do not implicitly become a combo just because they
share an attacker or ability. Author the strikes as one combo profile to opt in.

At hitbox creation, `HitboxStore` allocates a world-local, monotonically increasing
combo activation ID independent of recycled entity IDs. `HitboxDamageSystem`
captures that ID, the source actor and the one-based strike window in `ComboHit`
on the damage request. The target's `InvulnerabilityStore` records provenance
only after positive HP loss. While protected, it accepts a strictly later strike
from that same source and activation. Other actors (including the same enemy
type), separate activations, repeated strikes, ordinary attacks, procs and DoTs
remain blocked. The opener cannot bypass protection caused by another hit.
Each accepted follow-up refreshes the normal protection duration, so other
attackers remain blocked during and after the combo.

Zero-damage results retain the existing ordinary protection behavior but grant
no combo exception. Canceled requests grant neither. On-hit statuses from
accepted follow-ups retain the usual `acceptedHitTick` rule. Collision still
consumes a strike's target ledger before damage resolution; blocked attempts
do not retry later in the same strike.

Invulnerability expiry clears the timer and combo provenance, not membership:
the player remains eligible for protection from later hits. Arena entrances
explicitly clear combo provenance when installing protection and remove only
their owned temporary memberships on release. Store swap removal and entity
destruction clear target state; new hitboxes never reuse activation IDs.

These damage outcomes require matching client, Functions and replay-worker
compatibility `2026.10.11`. Tick ordering, commands, scoring and wire formats are
unchanged. This source change does not deploy a release.

`CombatPoseCatalog` holds the player directional variants, Warrior and Huntress
melee, Grojib's two strikes, Hashash strike/ambush, Unoco strike, and Derf tentacle/impact.
Coordinates include presentation scale and use the catalog sprite anchor.
Player back-strike art faces left; its snapshot and geometry mirror together.
Aimed player melee rotates the complete action pose around that anchor, using
the committed direction. Horizontal front/back attacks remain upright.

Enemy and allied NPC melee poses stay upright and mirror with current facing.
They do not use player aim rotation: locomotion can change their facing after
attack commitment, and rotating the old direction against the new facing would
invert both the sprite and its combat capsules. This source correction affects
combat outcomes when an autonomous actor turns during a strike, so it requires
a coordinated client/worker compatibility release after deployed `2026.10.6`.

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

Huntress spears and trap darts now share ballistic spawning, gravity and terrain
collision through Core's existing motion authority. Projectile direction tracks
current velocity, so snapshots rotate art and damage geometry along the arc.
Spear aim is solved at commitment against the level's gravity; darts launch
horizontally with lighter gravity. Both end on impact with a six-second fallback
for gaps. This source behavior requires the next coordinated compatibility
release after deployed `2026.10.6`.

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

Normal Derf's explosion owns its 16-pose timeline at 0.05 seconds per pose. Only poses
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

`RenderDebugFlags.drawActorHitboxes` is disabled by default. Set the flag to
`true` for local debug/profile inspection; the release-mode gate suppresses
these overlays. Changing its initializer requires a hot restart.

Guard protection remains omnidirectional by owner instruction. It is damage
middleware, not a front-shield collision volume. Geometry does not introduce
roll invulnerability or directional guarding.

Derf transforms on first body visibility, cancels pending casts, then uses a
seven-pose tentacle strike with active indices `[3, 5)`. Its caster and twisted
art share the same world pivot; see [Derf transformation](derf_transformation.md).
