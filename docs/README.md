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
- [Run distance and scoring](gdd/06_score.md#23-distance-means-furthest-progress): deployed in `2026.10.3`/`score-v3`, with furthest progress and 24 metres per full chunk.
- [Latest client release](verification/ghost-cache-client-2026-10-03.md): ghost cache filename fix `8d7d9bdc` published to Hosting and installed on the connected Android phone; 876 client tests passed. Phone unlock is needed for the post-fix ghost launch check.
- [Latest coordinated production release](verification/game-compat-2026.10.3-production.md): frozen `b5835b8e` deployed October 3 (Helsinki time) as `2026.10.3`/`score-v3`; local preparation, strict image benchmark, and live infrastructure checks passed. Signed-in smoke remains open.
- [Release checklist](building/rescue_release_operations.md#deployed-release-2026103): `2026.10.3` includes Huntress combat, revised distance scoring, and regeneration shrines.
- [Previous audit and planning baseline](archive/2026-09-15/README.md): historical reference.
- [Chunk connections and terrain heights](tdd/chunk_connections.md): implemented authoring and selection contract.
- [Reusable level traversal checks](../.agent/workflows/test-level-traversal.md): seeded enemy navigation tests, failure diagnostics, and how to adapt coverage to levels and movement limits.
- [Trap technical contracts](tdd/traps.md) and [trap gameplay](gdd/traps.md): gameplay, rendering and Chunk Creator authoring deployed with Forest repairs in `2026.09.8`.
- [World interaction contracts](tdd/world_interactions.md) and [regeneration shrine](gdd/world_interactions.md): manually configured top-contact blessing and fire animation; editor controls are deferred.
- [Technical design documents](tdd/): implemented architecture and contracts.
- [Allied NPC contracts](tdd/npc_encounter_contracts.md) and [rescue mechanics](gdd/npc_rescue.md): encounter Core, rendering, Entities editing, Chunk Creator authoring, shared rescue scoring and generated Field content are deployed. Survivor section
  combat was deployed in `2026.10.1`. Huntress distance-based throw/stab/slash
  combat was deployed in compatibility `2026.10.3`.
- [Game design documents](gdd/): implemented mechanics and content rules.
- [Documentation rules](rules/code-documentation-policy.md).

Choose one task from the current implementation and user priorities before
opening a new audit or plan. Archived tasks are not automatically queued.
