# Current Implementation Plans

- [Completed Forest content drift repair](../archive/2026-10-02/building/forest_content_drift_repair.md):
  current-source generation and all traversal checks pass on the dedicated
  branch; see [verification](../verification/forest-content-drift-repair.md).

- [Completed NPC section guards](../archive/2026-10-02/building/npc_section_guards.md):
  implemented on `feature/npc-section-guards` as pending gameplay `2026.10.1`;
  see [validation](../verification/npc-section-guards.md) and the separate
  [resolved Forest content finding](../archive/2026-10-02/audit/forest_content_drift_2026-10-02.md).

- [Completed Forest enemy navigation repair](../archive/2026-09-24/building/forest_enemy_navigation.md):
  navigation and five chunk adjustments validated at unchanged movement limits;
  included in the deployed `2026.09.8` release.

- [NPC rescue encounters](npc_rescue_encounters.md): gameplay, rendering,
  authoring, scoring and production content delivered. M7 retains signed-in
  production verification; the owner stopped further benchmarks before release.

- [Rescue release operations](rescue_release_operations.md): frozen `6bfda4c8`
  deployed as `2026.09.10`/`score-v2` to Functions, Cloud Run and web Hosting on
  October 1. Checks and the exact-image benchmark passed; no cancellation/reset
  was needed. Later projectile/content edits remain pending a new compatibility
  release. Live gameplay smoke still needs a linked Play Games account.

- [Completed trap implementation](../archive/2026-09-24/building/traps/plan.md)
  and [validation](../archive/2026-09-24/verification/traps.md), deployed in `2026.09.8`.

- [Completed chunk connections and terrain heights](../archive/2026-09-15/building/chunk_connections/strategy.md).
- [Previous planning baseline](../archive/2026-09-15/README.md).

Start one focused plan for the next user-selected task. List its status and
next action here. Use one checklist per workstream and link supporting audits
and evidence instead of duplicating progress tracking.
