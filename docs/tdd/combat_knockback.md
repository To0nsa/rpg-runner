# Combat knockback

`AbilityDef.knockback` optionally authors horizontal travel distance and duration
in seconds. The default is absent, so existing attacks retain their behavior.
Melee, projectile and target-point commits carry the definition through their
frozen payload and intent. Mobility contact damage reads the same ability field.
No enemy identity or arena-specific condition selects the effect.

Attack execution captures the attacker's world X and horizontal fallback in
`KnockbackSource`. A pillar uses its caster's origin rather than its own center.
Hit resolution freezes the sign away from that origin in `KnockbackHit`; equal
X uses the captured fallback. Owner movement, retirement or ID reuse cannot change
that direction after launch. Damage requests and their SoA queue retain it.

Damage middleware runs before `DamageSystem`. Only positive HP loss on a living
dynamic body queues a shove; canceled, invulnerable, protected, fully resisted,
zero-damage and lethal outcomes do not. Partial mitigation still pushes. Existing
hit policies and invulnerability prevent repeated pushes from one activation.
Multiple accepted hits use deterministic damage-queue order: the last replaces
the previous shove, rather than stacking unbounded velocity.

`KnockbackStore` is lifecycle registered. Damage schedules its first motion at
the next simulation tick, after the current tick's terrain solve. Duration is
`ceil(durationSeconds * tickHz)`. For N motion ticks, remaining count R and
signed distance D, horizontal velocity is `2 * D * tickHz * R / (N * (N + 1))`.
This discrete linear taper sums to D in uncapped, unobstructed motion. Body caps,
walls, terrain and encounter bounds can shorten travel; positions are never
teleported to satisfy the distance.

The effect temporarily locks move, dash and navigation, cancels active mobility
and its gravity suppression, and invalidates retained navigation traversal.
Jumping and offensive actions retain their ordinary gates. After locomotion,
jump and mobility compose intent, `KnockbackSystem` overrides horizontal velocity
before gravity and `WorldMotionAuthority`. Supported shoves use the existing
`groundedHorizontal` terrain mode so floor contact does not consume horizontal
travel. Airborne shoves remain world-space. There is no upward knockback impulse;
gravity starts the fall when the actor leaves a platform. Suspension, frozen
encounter motion, disabled bodies, death and destruction discard pending state.

This changes deterministic gameplay and is part of the unreleased boss branch's
prepared `2026.10.8` compatibility release. Client and replay worker must consume
the same Core; commands, replay encoding and score format are unchanged by this
follow-up. See [boss arena contracts](boss_arenas.md) and
[Bringer tuning](../gdd/bringer_of_death.md).
