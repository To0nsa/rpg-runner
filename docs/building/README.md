# Current Implementation Plans

- [Reward verification latency](reward_verification_latency.md): deployed as
  `2026.10.11.1` with the strict image benchmark passed and two owner-accepted
  terrain failures. Device, route-coverage and controlled live latency/settlement
  measurements remain open.

- [Completed Forest boss arena](../archive/2026-10-06/building/forest_boss_arena.md):
  merged into `master` and deployed in `2026.10.8` / `score-v4`; see
  [production verification](../verification/forest_boss_arena.md#production-release-2026108).

- [Completed combat hitbox alignment](../archive/2026-10-05/building/combat_hitbox_alignment.md):
  reviewed combat poses, shared timing, and exact debug geometry pass local
  validation; see [verification](../verification/combat-hitbox-alignment.md).

- [Completed Forest content drift repair](../archive/2026-10-02/building/forest_content_drift_repair.md):
  current-source generation and all traversal checks pass on the dedicated
  branch; see [verification](../verification/forest-content-drift-repair.md).

- [Completed NPC section guards](../archive/2026-10-02/building/npc_section_guards.md):
  implemented on `feature/npc-section-guards` and deployed as gameplay `2026.10.1`;
  see [validation](../verification/npc-section-guards.md) and the separate
  [resolved Forest content finding](../archive/2026-10-02/audit/forest_content_drift_2026-10-02.md).

- [Completed Forest enemy navigation repair](../archive/2026-09-24/building/forest_enemy_navigation.md):
  navigation and five chunk adjustments validated at unchanged movement limits;
  included in the deployed `2026.09.8` release.

- [NPC rescue encounters](npc_rescue_encounters.md): gameplay, rendering,
  authoring, scoring and production content delivered. M7 retains signed-in
  production verification; the owner stopped further benchmarks before release.

- [Rescue release operations](rescue_release_operations.md): frozen `709c9d42`
  deployed as `2026.10.16`/`score-v4` to Functions, Cloud Run, and web Hosting
  on October 17 UTC. Required checks and the exact-image benchmark passed;
  15 reviewed unsubmitted tickets were cancelled while all 318 accepted runs
  and rewards were preserved. Signed-in Play Games production smoke remains open.

- [Completed trap implementation](../archive/2026-09-24/building/traps/plan.md)
  and [validation](../archive/2026-09-24/verification/traps.md), deployed in `2026.09.8`.

- [Completed chunk connections and terrain heights](../archive/2026-09-15/building/chunk_connections/strategy.md).
- [Previous planning baseline](../archive/2026-09-15/README.md).

Start one focused plan for the next user-selected task. List its status and
next action here. Use one checklist per workstream and link supporting audits
and evidence instead of duplicating progress tracking.
