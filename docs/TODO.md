## Core

- Add archetype builders to reduce `createPlayer`/`createEnemy` callsite bloat (spawn helpers/builders per entity type; used by deterministic spawning later).
- Reduce `EcsWorld.destroyEntity` maintenance risk (central registry/list of stores or a component mask approach) so new stores can’t be forgotten.
- Handle player death explicitly (core event/flag + UI flow) instead of despawning the player in `HealthDespawnSystem`.
- Reduce Flame per-frame allocations in `RunnerFlameGame` by reusing buffers in `_syncEnemies/_syncProjectiles/_syncHitboxes` (use `clear()` on cached `Set`/`List` instead of allocating each frame).
