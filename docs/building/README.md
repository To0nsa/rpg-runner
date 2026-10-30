# Current Implementation Plans

- [Completed Hall of Honour achievements](../archive/2026-10-30/building/achievements.md):
  five verified milestones, direct gold claims, next-target rows and expandable
  completion dates. [Dev deployment](../verification/achievements-dev-2026-10-30.md)
  is complete; the [release checklist](achievements_dev_release.md) retains
  Android installation and live menu acceptance. See the
  [GDD](../gdd/12_achievements.md) for the selected defaults and future ideas.

- [Completed shared Flutter tools and Admin gifts](../archive/2026-10-29/building/admin_tools.md):
  shared editor UI/game presentation and native Admin; local implementation and
  verification complete. Item/skill delivery awaits compatible environment rollout.

- [Completed inbox retention and player deletion](../archive/2026-10-28/building/inbox_retention.md):
  protected unclaimed gifts, 30-day cleanup, compact delivery receipts and inbox
  Delete. Backend/emulator and Flutter checks pass; not deployed.

- [Completed message tooling](../archive/2026-10-28/building/message_tooling.md):
  local developer console for dev/staging/prod, single-player messages and optional
  gold. Backend/emulator and offline browser checks pass; no live delivery performed.

- [Board lifecycle and account deletion](board_lifecycle_cleanup.md): bounded
  erasure batches, current-window provisioning, obsolete-board retirement and
  authorized pre-release dev cleanup.

- [Android beta release with dev, staging and production](android_beta_release.md):
  executing; reuse the existing project/owner account for dev and create named staging
  and production projects now. Team acceptance uses a separate staging app/backend;
  promote its frozen candidate to prod. One gameplay version per environment and
  required updates. Environment routing/isolation is being validated; bootstrap,
  provisioning, Android signing and Play acceptance remain pending.

- [Completed system inbox and reusable attention marker](../archive/2026-10-21/building/system_inbox.md):
  manually claimed 25-gold gifts for newly reached levels, game messages and a
  shared notification dot. Locally validated; not deployed.

- [Reward verification latency](reward_verification_latency.md): October 30
  phone samples captured; per-run client/server timing instrumentation and its
  authorized dev rollout are in progress. Representative device and route
  coverage remain open.

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

- [Rescue release operations](rescue_release_operations.md): the leaderboard
  level patch from frozen `1a8e899c` was deployed October 18 UTC to Functions,
  Cloud Run, and web Hosting under `2026.10.17`/`score-v4`. Required checks
  and the exact-image benchmark passed; one reviewed unsubmitted ticket was
  cancelled while all 333 accepted runs and rewards were preserved. Signed-in
  Play Games production smoke remains open.

- [Completed trap implementation](../archive/2026-09-24/building/traps/plan.md)
  and [validation](../archive/2026-09-24/verification/traps.md), deployed in `2026.09.8`.

- [Completed chunk connections and terrain heights](../archive/2026-09-15/building/chunk_connections/strategy.md).
- [Previous planning baseline](../archive/2026-09-15/README.md).

Start one focused plan for the next user-selected task. List its status and
next action here. Use one checklist per workstream and link supporting audits
and evidence instead of duplicating progress tracking.
