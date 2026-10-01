# Documentation

Audit and planning restarted on September 15, 2026. Start here for current work.

- [Current audits](audit/README.md).
- [Current implementation plans](building/README.md): NPC rescue encounters.
- [Completed Forest traversal repair](archive/2026-09-24/audit/forest_enemy_traversal_2026-09-24.md): nine seeded enemy cases pass; deployed in `2026.09.8`.
- [Deployment workflow](tdd/deployment_workflow.md): reusable preparation, asynchronous image builds, explicit issuance cutover and deployment evidence. Source targets `2026.09.10`; current source deployment is not verified.
- [Latest production release](archive/2026-09-25/verification/game-compat-2026.09.9-production.md): Forest spawn revision deployed as `2026.09.9`/`score-v2`; tests and benchmarks omitted at the owner's request.
- [Previous audit and planning baseline](archive/2026-09-15/README.md): historical reference.
- [Chunk connections and terrain heights](tdd/chunk_connections.md): implemented authoring and selection contract.
- [Reusable level traversal checks](../.agent/workflows/test-level-traversal.md): seeded enemy navigation tests, failure diagnostics, and how to adapt coverage to levels and movement limits.
- [Trap technical contracts](tdd/traps.md) and [trap gameplay](gdd/traps.md): gameplay, rendering and Chunk Creator authoring deployed with Forest repairs in `2026.09.8`.
- [Technical design documents](tdd/): implemented architecture and contracts.
- [Allied NPC contracts](tdd/npc_encounter_contracts.md) and [rescue mechanics](gdd/npc_rescue.md): encounter Core, rendering, Entities editing, Chunk Creator authoring, shared rescue scoring and generated Field content are deployed.
- [Game design documents](gdd/): implemented mechanics and content rules.
- [Documentation rules](rules/code-documentation-policy.md).

Choose one task from the current implementation and user priorities before
opening a new audit or plan. Archived tasks are not automatically queued.
