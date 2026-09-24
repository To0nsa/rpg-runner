# Documentation

Audit and planning restarted on September 15, 2026. Start here for current work.

- [Current audits](audit/README.md).
- [Current implementation plans](building/README.md): NPC rescue encounters.
- [Completed Forest traversal repair](archive/2026-09-24/audit/forest_enemy_traversal_2026-09-24.md): nine seeded enemy cases pass; compatibility `2026.09.6` awaits deployment.
- [Latest production release](archive/2026-09-20/verification/game-compat-2026.09.3-production.md): swimming compatibility `2026.09.3` deployment and verification.
- [Previous audit and planning baseline](archive/2026-09-15/README.md): historical reference.
- [Chunk connections and terrain heights](tdd/chunk_connections.md): implemented authoring and selection contract.
- [Reusable level traversal checks](../.agent/workflows/test-level-traversal.md): seeded enemy navigation tests, failure diagnostics, and how to adapt coverage to levels and movement limits.
- [Trap technical contracts](tdd/traps.md) and [trap gameplay](gdd/traps.md): implemented gameplay, rendering and Chunk Creator authoring; poison-launcher emergence/retraction compatibility `2026.09.7` awaits deployment and includes the Forest repairs.
- [Technical design documents](tdd/): implemented architecture and contracts.
- [Game design documents](gdd/): implemented mechanics and content rules.
- [Documentation rules](rules/code-documentation-policy.md).

Choose one task from the current implementation and user priorities before
opening a new audit or plan. Archived tasks are not automatically queued.
