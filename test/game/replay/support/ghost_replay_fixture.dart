import 'package:run_protocol/replay_blob.dart';
import 'package:run_protocol/board_key.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/actor_frame_snapshot.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';

ReplayBlobV1 ghostReplayFixture({
  BoardKey? boardKey,
  String levelId = 'field',
  String playerCharacterId = 'eloise',
  int totalTicks = 900,
  int seed = 1337,
}) {
  const loadout = EquippedLoadoutDef();
  return ReplayBlobV1.withComputedDigest(
    runSessionId: 'ghost_worker_fixture',
    boardId: boardKey == null ? null : 'ghost_board',
    boardKey: boardKey,
    tickHz: 60,
    seed: seed,
    levelId: levelId,
    playerCharacterId: playerCharacterId,
    loadoutSnapshot: {
      'mask': loadout.mask,
      'mainWeaponId': loadout.mainWeaponId.name,
      'offhandWeaponId': loadout.offhandWeaponId.name,
      'spellBookId': loadout.spellBookId.name,
      'projectileSlotSpellId': loadout.projectileSlotSpellId.name,
      'accessoryId': loadout.accessoryId.name,
      'abilityPrimaryId': loadout.abilityPrimaryId,
      'abilitySecondaryId': loadout.abilitySecondaryId,
      'abilityProjectileId': loadout.abilityProjectileId,
      'abilitySpellId': loadout.abilitySpellId,
      'abilityMobilityId': loadout.abilityMobilityId,
      'abilityJumpId': loadout.abilityJumpId,
    },
    totalTicks: totalTicks,
    commandStream: [
      for (var tick = 1; tick <= totalTicks; tick++)
        ReplayCommandFrameV1(
          tick: tick,
          moveAxis: 1,
          pressedMask:
              (tick % 45 == 0 ? 1 : 0) |
              (tick % 80 == 0 ? 2 : 0) |
              (tick % 60 == 0 ? 4 : 0) |
              (tick % 35 == 0 ? 8 : 0) |
              (tick % 90 == 0 ? 32 : 0),
        ),
    ],
  );
}

Object actorFrameFields(ActorFrameSnapshot s) => [
  s.tick,
  s.distance,
  s.gameOver,
  s.entities.map(entityFields).toList(),
];

Object entityFields(EntityRenderSnapshot e) => [
  e.id,
  e.kind,
  e.pos.x,
  e.pos.y,
  e.vel?.x,
  e.vel?.y,
  e.size?.x,
  e.size?.y,
  e.enemyId,
  e.npcId,
  e.npcHealth?.hp100,
  e.npcHealth?.maxHp100,
  e.npcHealth?.protected,
  e.npcHealth?.guarding,
  e.projectileId,
  e.pickupVariant,
  e.z,
  e.rotationRad,
  e.isSwimming,
  e.waterImmersion1000,
  e.facing,
  e.artFacingDir,
  e.grounded,
  e.anim,
  e.animFrame,
  e.statusVisualMask,
  e.controlLockMask,
];

Object eventFields(GameEvent e) => [
  e.runtimeType.toString(),
  switch (e) {
    RunEndedEvent() => [
      e.runId,
      e.tick,
      e.distance,
      e.reason,
      e.goldEarned,
      e.stats.collectibles,
      e.stats.collectibleScore,
      e.stats.enemyKillCounts,
      e.stats.rescuedNpcs,
      e.stats.rescuePoints,
      e.deathInfo?.kind,
      e.deathInfo?.enemyId,
      e.deathInfo?.projectileId,
      e.deathInfo?.sourceProjectileId,
      e.deathInfo?.sourceTrap?.trapId,
      e.deathInfo?.sourceTrap?.chunkKey,
      e.deathInfo?.sourceTrap?.chunkIndex,
      e.deathInfo?.sourceTrap?.placementOrdinal,
    ],
    ProjectileHitEvent() => [
      e.tick,
      e.projectileId,
      e.pos.x,
      e.pos.y,
      e.facing,
      e.rotationRad,
      e.sourceProjectileId,
    ],
    SpellImpactEvent() => [
      e.tick,
      e.impactId,
      e.pos.x,
      e.pos.y,
      e.sourceEnemyId,
      e.abilityId,
    ],
    EntityVisualCueEvent() => [
      e.tick,
      e.entityId,
      e.kind,
      e.intensityBp,
      e.damageType,
      e.resourceType,
    ],
    EnemyKilledEvent() => [
      e.tick,
      e.enemyId,
      e.pos.x,
      e.pos.y,
      e.facing,
      e.artFacingDir,
    ],
    PlayerImpactFeedbackEvent() => [e.tick, e.amount100, e.sourceKind],
    AbilityHoldEndedEvent() => [
      e.tick,
      e.entity,
      e.slot,
      e.abilityId,
      e.reason,
    ],
    AbilityChargeEndedEvent() => [
      e.tick,
      e.entity,
      e.slot,
      e.abilityId,
      e.reason,
    ],
    EncounterResolvedEvent() => [
      e.outcome.key,
      e.outcome.phase,
      e.outcome.reason,
      e.outcome.tick,
      e.outcome.survivors,
      e.outcome.points,
      e.outcome.diagnostic,
    ],
  },
];
