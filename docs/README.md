# Documentation

Audit and planning restarted on September 15, 2026. Start here for current work.

- [Current audits](audit/README.md).
- [System messages and level gifts](gdd/messages.md): manual 25-gold claims for
  newly reached levels, protected inbox deletion, 30-day retention and an attention marker;
  [technical contract and operator sending](tdd/system_inbox.md), including the
  [Flutter Admin guide](../tools/admin/README.md).
- [Shared tools and Admin architecture](tdd/admin_tools.md): editor UI packages,
  game presentation reuse, durable operator drafts and gated item/skill gifts.
- [Off-screen actor indicators](tdd/offscreen_indicators.md): left/top bearings,
  distance labels, enemy grouping and viewport-aware HUD placement.
- [Town and Codex](gdd/codex.md): Théodonis city map, Store, Library,
  enemy/level discoveries and Éloïse's opening; [persistence contract](tdd/codex.md).
- [Hall of Honour achievements](gdd/12_achievements.md): five milestones from
  qualifying verified runs, expandable completion dates and direct gold claims
  in the selected Town building; [technical contract](tdd/achievements.md).
  [Deployed to dev](verification/achievements-dev-2026-10-30.md); Android build 4
  is verified and ready to install. Live device acceptance remains pending.
- [Player progression](gdd/player_progression.md): account level and lifetime
  combat stats; [implementation contract](tdd/player_progression.md).
- [Prepared navigation and reward completion](tdd/prepared_navigation.md): trusted
  graph packs, curated Practice routes, on-demand verification and app-owned
  wallet catch-up; [remaining rollout gates](building/reward_verification_latency.md).
- [Current implementation plans](building/README.md): Android beta/backend
  isolation, reward verification latency and NPC rescue production smoke.
- [Android beta release plan](building/android_beta_release.md): existing project
  reused for dev, new staging/production projects, separate staging app for team
  acceptance, required updates and Play testing; execution underway with
  environment routing and isolation checks. One shared deployment workflow and
  no player-data migration.
- [Latest dev app release](verification/achievements-dev-2026-10-30.md): source
  `8a094efb` deployed to dev with Hall of Honour achievements, reusing the worker
  image, navigation graphs and six unchanged validation components. Android
  build 4 is verified; installation and live gameplay smoke await the phone.
- [Android showcase QA](verification/android-showcase-readiness-2026-10-06.md):
  lifecycle/input fixes, event-retention cleanup, full local checks and 18
  mixed-input replay cases pass. Finalized authoring is deployed in `2026.10.7`;
  showcase device smoke remains.
- [Combat hitbox alignment](verification/combat-hitbox-alignment.md): player,
  NPC and enemy combat poses share deterministic collision/render timing;
  validated locally and deployed in compatibility `2026.10.6`.
- [NPC section guards](verification/npc-section-guards.md): implemented and locally
  validated on a dedicated branch; deployed in `2026.10.1`.
- [Forest content repair](verification/forest-content-drift-repair.md): generated
  content is fresh and all four inherited traversal failures are resolved;
  the current-source 27-case matrix and exact rock routes pass.
- [Completed Forest traversal repair](archive/2026-09-24/audit/forest_enemy_traversal_2026-09-24.md): nine seeded enemy cases pass; deployed in `2026.09.8`.
- [Deployment workflow](tdd/deployment_workflow.md): reusable preparation, asynchronous image builds, verified issuance cutover and missing-image recovery. Later source changes require their own compatibility release.
- [Run distance and scoring](gdd/06_score.md#23-distance-means-furthest-progress): deployed in `2026.10.3`/`score-v3`, with furthest progress and 24 metres per full chunk.
- [Earlier ghost cache client release](verification/ghost-cache-client-2026-10-03.md): ghost cache filename fix `8d7d9bdc` published to Hosting and installed on the connected Android phone; 876 client tests passed. Ghost launch, cache reuse, and rendering were verified on the phone.
- [Latest coordinated production release](verification/leaderboard-level-2026-10-18-production.md): the leaderboard level patch from frozen `1a8e899c` was deployed October 18 UTC under `2026.10.17`/`score-v4`. Required preparation and strict image benchmark passed. One reviewed unsubmitted ticket was cancelled while all 333 accepted runs and rewards were preserved. Functions, worker, Hosting, boards, queues and issuance are verified live; signed-in leaderboard smoke remains open.
- [Release checklist](building/rescue_release_operations.md#deployed-leaderboard-level-patch-20261017): completed Functions/worker/web cutover and outstanding linked Play Games smoke checks.
- [Previous audit and planning baseline](archive/2026-09-15/README.md): historical reference.
- [Chunk connections and terrain heights](tdd/chunk_connections.md): implemented authoring and selection contract.
- [Reusable level traversal checks](../.agent/workflows/test-level-traversal.md): seeded enemy navigation tests, failure diagnostics, and how to adapt coverage to levels and movement limits.
- [Trap technical contracts](tdd/traps.md) and [trap gameplay](gdd/traps.md): gameplay, rendering and Chunk Creator authoring deployed with Forest repairs in `2026.09.8`.
- [World interaction contracts](tdd/world_interactions.md) and [regeneration shrine](gdd/world_interactions.md): manually configured top-contact blessing and fire animation; editor controls are deferred.
- [Terrain streaming performance](tdd/terrain_streaming_performance.md): October
  freeze diagnosis, incremental preparation, portable spatial queries, and local
  browser regression/performance evidence. The fixes have not been deployed.
- [Run startup](tdd/run_startup.md): shared preflight, world/recorder readiness, loading recovery, and run-owned assets. See the [startup audit and local measurements](verification/run_startup_2026-10-11.md) for ticket reuse, bounded asset loading and native terrain preparation.
- [Dash and Double Dash](tdd/mobility_recasts.md): shorter Dash and a separate
  two-burst mobility choice; source prepared for `2026.10.21`, not deployed.
- [Developer Practice](tdd/developer_practice.md): debug launch flag and Options
  toggle, persistent fully unlocked local profile, and Practice without backend
  sessions or rewards.
- [Android build identities](tdd/android_build_variants.md): dev/staging/prod
  flavors, isolated Firebase projects, signing and pending Play acceptance.
- [Forest boss arenas](tdd/boss_arenas.md) and [Bringer gameplay](gdd/bringer_of_death.md):
  deterministic full-screen entrance, confined combat, editor authoring and replay
  scoring deployed in `2026.10.8` / `score-v4`; see
  [production and local verification](verification/forest_boss_arena.md).
- [Ancient God gameplay](gdd/ancient_god_bosses.md) and [implementation](tdd/ancient_god_bosses.md):
  three additional selectable arena bosses, owned summons and composed spell art
  at Bringer's 1.5x scale; deployed in three consecutive Forest arenas after Bringer.
  [Separation and visual audit](verification/ancient-god-bosses-2026-10-07.md)
  records independent boss ownership, video review and collision corrections.
- [Derf transformation](tdd/derf_transformation.md) and [Derf gameplay](gdd/derf.md): normal-form explosions, first-visibility transformation, then ground pursuit and tentacle melee; deployed in `2026.10.7`.
- [Technical design documents](tdd/): implemented architecture and contracts.
- [Status effect tuning](tdd/status_effect_tuning.md): per-ability and per-item
  overrides for all status types, shared gameplay/UI resolution and compound effects.
- [Mixed damage](tdd/mixed_damage.md): one hit with multiple typed shares,
  independent resistance and shared crit, effects and post-hit protection.
- [Allied NPC contracts](tdd/npc_encounter_contracts.md) and [rescue mechanics](gdd/npc_rescue.md): encounter Core, rendering, Entities editing, Chunk Creator authoring, shared rescue scoring and generated Field content are deployed. Survivor section
  combat was deployed in `2026.10.1`. Huntress distance-based throw/stab/slash
  combat was deployed in compatibility `2026.10.3`.
- [Game design documents](gdd/): implemented mechanics and content rules.
- [Documentation rules](rules/code-documentation-policy.md).

Choose one task from the current implementation and user priorities before
opening a new audit or plan. Archived tasks are not automatically queued.
