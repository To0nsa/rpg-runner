# Willow bomb throws

Requested: keep Willow's bomb/explosion sprite scale, throw from the animated
hand in an arc, auto-aim at the farthest reachable hostile, and explode on
contact or one second after release. The user subsequently specified 6 Supplies
per throw; this replaces the former free-bomb rule.

## Acceptance and ownership

- [x] Shared 1.35 sprite scale; committed as `cc1e69cc`. Focused analysis and
  all three existing Training Field bomb rendering checks passed.
- [x] Core owns mirrored frame-6 hand release, farthest reachable targeting,
  deterministic lob motion, contact/fuse detonation, and one damage pulse.
- [x] Ground/air, left/right, moving caster/target, no-target fallback, blocked
  arcs, allies, interruption, owner removal and 30/60/120 Hz are checked.
- [x] Game renders the same release and blast in all three weapon art families.
- [x] Client/issuer/worker compatibility and player-facing descriptions agree.
- [x] Core, rendering, replay, compatibility/build and required compiled worker
  benchmark checks pass; document local evidence and archive this checklist.

The existing throw strip releases at zero-based frame 6. Targeting is refreshed
at release from final actor positions. A 0.8-second aimed flight leaves margin
before the one-second fuse; no target uses a forward lob. Hostile or terrain
contact triggers the blast; allies do not. Every throw spends 6 Supplies;
damage/radii/cooldowns retain their authored values. Command format and system
ordering stay unchanged. This changes
replay outcomes and requires matching release artifacts; deployment is outside
this implementation task.

Initial unrelated work was preserved. The earlier Double Dash and HUD work was
committed independently during inspection; `.flutter_tool_state` remains untracked.

Completed locally. See [verification and limitations](../../../verification/willow-bomb-throw-2026-11-08.md).
