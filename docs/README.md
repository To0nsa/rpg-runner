# Documentation

Audit and planning restarted on September 15, 2026. Start here for current work.

- [Current audits](audit/README.md).
- [Current implementation plans](building/README.md): NPC rescue production smoke.
- [NPC section guards](verification/npc-section-guards.md): implemented and locally
  validated on a dedicated branch; deployed in `2026.10.1`.
- [Forest content repair](verification/forest-content-drift-repair.md): generated
  content is fresh and all four inherited traversal failures are resolved;
  the current-source 27-case matrix and exact rock routes pass.
- [Completed Forest traversal repair](archive/2026-09-24/audit/forest_enemy_traversal_2026-09-24.md): nine seeded enemy cases pass; deployed in `2026.09.8`.
- [Deployment workflow](tdd/deployment_workflow.md): reusable preparation, asynchronous image builds, verified issuance cutover and missing-image recovery. Later source changes require their own compatibility release.
- [Latest production release](verification/game-compat-2026.10.1-production.md): frozen `0cb94b94` deployed October 2 as `2026.10.1`/`score-v2`; exact-commit CI, strict image benchmark and live infrastructure checks passed. Signed-in smoke remains open.
- [Release checklist](building/rescue_release_operations.md#deployed-release-2026101): `2026.10.1` includes projectile auto aim, NPC section guards and updated Forest content.
- [Previous audit and planning baseline](archive/2026-09-15/README.md): historical reference.
- [Chunk connections and terrain heights](tdd/chunk_connections.md): implemented authoring and selection contract.
- [Reusable level traversal checks](../.agent/workflows/test-level-traversal.md): seeded enemy navigation tests, failure diagnostics, and how to adapt coverage to levels and movement limits.
- [Trap technical contracts](tdd/traps.md) and [trap gameplay](gdd/traps.md): gameplay, rendering and Chunk Creator authoring deployed with Forest repairs in `2026.09.8`.
- [Technical design documents](tdd/): implemented architecture and contracts.
- [Allied NPC contracts](tdd/npc_encounter_contracts.md) and [rescue mechanics](gdd/npc_rescue.md): encounter Core, rendering, Entities editing, Chunk Creator authoring, shared rescue scoring and generated Field content are deployed. Survivor section
  combat was deployed in `2026.10.1`. Huntress distance-based throw/stab/slash
  combat is implemented in source compatibility `2026.10.2`, pending coordinated release.
- [Game design documents](gdd/): implemented mechanics and content rules.
- [Documentation rules](rules/code-documentation-policy.md).

Choose one task from the current implementation and user priorities before
opening a new audit or plan. Archived tasks are not automatically queued.
