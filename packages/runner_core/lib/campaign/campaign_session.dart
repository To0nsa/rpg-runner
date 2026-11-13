import '../collision/terrain/terrain_motion_request.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../ecs/entity_id.dart';
import '../ecs/world.dart';
import '../ecs/stores/world_interaction_store.dart';
import '../encounters/encounter_instance.dart';
import '../track/track_streamer.dart';
import '../snapshots/campaign_snapshot.dart';
import 'campaign_mission_definition.dart';
import 'campaign_enemy_system.dart';

/// Attempt-local objectives. Observed before death cleanup so recycled entity
/// IDs can never satisfy an earlier mission chunk's target.
final class CampaignSession {
  CampaignSession(this.definition)
    : bounds = TerrainHorizontalBounds(
        minXTicks: 0,
        maxXTicks: physicsCoordinateToTicks(definition.worldWidth),
      );
  final CampaignMissionDefinition definition;
  final TerrainHorizontalBounds bounds;
  final Map<CampaignEnemyTarget, EntityId> _enemies = {};
  final Set<CampaignEnemyTarget> _defeated = {};
  final Map<CampaignEnemyTarget, EntityId> _markerEnemies = {};

  /// Dead bindings are removed before entity cleanup/recycling.
  EntityId? enemyEntity(CampaignEnemyTarget target) => _markerEnemies[target];
  final Set<CampaignRescueTarget> _rescued = {};
  final Set<int> _regions = {};
  bool failed = false;
  bool _firstCoinCollected = false;
  bool _blessingReceived = false;
  int completedBosses = 0;

  void registerEnemy(
    EcsWorld world,
    SpawnEnemyRequest request,
    EntityId? entity,
  ) {
    final id = request.missionChunkId;
    final salt = request.markerSalt;
    if (id == null || salt == null) return;
    final target = (missionChunkId: id, markerSalt: salt);
    if (entity != null) {
      _markerEnemies[target] = entity;
      final ti = world.transform.indexOf(entity);
      final ei = world.enemy.indexOf(entity);
      world.campaignEnemy.add(
        entity,
        x: world.transform.posX[ti],
        y: world.transform.posY[ti],
        facing: world.enemy.facing[ei],
        returns: !definition.persistentPursuitEnemies.contains(target),
      );
    }
    if (!definition.requiredEnemies.contains(target)) return;
    if (entity == null) {
      throw StateError('Required enemy $target has no valid placement.');
    }
    if (_enemies.containsKey(target)) {
      throw StateError('Duplicate target $target.');
    }
    _enemies[target] = entity;
  }

  void recordRescue(EncounterOutcome outcome) {
    final target = (
      missionChunkId: definition.route.missionChunks[outcome.key.chunkIndex].id,
      encounterId: outcome.key.encounterId,
    );
    if (!definition.requiredRescues.contains(target)) return;
    if (outcome.phase == EncounterPhase.rescued) {
      _rescued.add(target);
    } else {
      failed = true;
    }
  }

  /// Every live actor keeps terrain and ticking state off screen. Apply global
  /// bounds before arena control narrows them, and before any teleport or motion.
  void applyBounds(EcsWorld world, EntityId player) {
    for (final actor in [
      player,
      ...world.enemy.denseEntities,
      ...world.npc.denseEntities,
    ]) {
      final npc = world.npc.tryIndexOf(actor);
      final local = npc == null ? null : world.npc.movementBounds[npc];
      final enemy = world.campaignEnemy.tryIndexOf(actor);
      final territory =
          enemy != null && world.campaignEnemy.returnWhenPlayerRetreats[enemy]
          ? TerrainHorizontalBounds(
              minXTicks: physicsCoordinateToTicks(
                world.campaignEnemy.homeX[enemy] -
                    CampaignEnemySystem.territoryRadius,
              ),
              maxXTicks: physicsCoordinateToTicks(
                world.campaignEnemy.homeX[enemy] +
                    CampaignEnemySystem.territoryRadius,
              ),
            )
          : local;
      world.actorMotionBounds.add(
        actor,
        territory == null
            ? bounds
            : TerrainHorizontalBounds(
                minXTicks: territory.minXTicks.clamp(
                  bounds.minXTicks,
                  bounds.maxXTicks - 1,
                ),
                maxXTicks: territory.maxXTicks.clamp(
                  bounds.minXTicks + 1,
                  bounds.maxXTicks,
                ),
              ),
      );
    }
  }

  void observeBeforeCleanup(EcsWorld world) {
    _markerEnemies.removeWhere((_, entity) {
      final hp = world.health.tryIndexOf(entity);
      return hp == null ||
          world.health.hp[hp] <= 0 ||
          world.deathState.has(entity);
    });
    for (final entry in _enemies.entries) {
      if (_defeated.contains(entry.key)) continue;
      final hp = world.health.tryIndexOf(entry.value);
      if (hp == null || !world.enemy.has(entry.value)) {
        failed = true;
      } else if (world.health.hp[hp] <= 0 ||
          world.deathState.has(entry.value)) {
        _defeated.add(entry.key);
      }
    }
  }

  bool resolveLivingPlayer(
    double x,
    double y, {
    bool hasCollectedCoin = false,
    WorldInteractionStore? interactions,
  }) {
    // Pickup resolution precedes this phase; completion is monotonic per attempt.
    _firstCoinCollected = _firstCoinCollected || hasCollectedCoin;
    final shrine = definition.requiredBlessingShrine;
    if (!_blessingReceived && shrine != null && interactions != null) {
      // The interaction system already validated living-player top contact.
      // Observe its committed activation; proximity and other shrines never count.
      _blessingReceived = interactions.states.any(
        (state) =>
            state.binding.missionChunkId == shrine.missionChunkId &&
            state.binding.key == shrine.bindingKey &&
            state.activationTick != null,
      );
    }
    for (var i = 0; i < definition.requiredRegions.length; i++) {
      if (definition.contains(definition.requiredRegions[i], x, y)) {
        _regions.add(i);
      }
    }
    return !failed &&
        completedObjectives == totalObjectives &&
        definition.contains(definition.exit, x, y);
  }

  /// Preserve normal impact resolution on the boundary tick, then retire shots
  /// that have left the resident world. Camera position never expires a shot.
  void retireOutOfBoundsProjectiles(EcsWorld world) {
    for (final entity in List<EntityId>.of(world.projectile.denseEntities)) {
      final i = world.transform.tryIndexOf(entity);
      if (i != null &&
          (world.transform.posX[i] < 0 ||
              world.transform.posX[i] > definition.worldWidth ||
              world.transform.posY[i] > definition.killPlaneY)) {
        world.destroyEntity(entity);
      }
    }
  }

  int get completedObjectives =>
      _defeated.length +
      _rescued.length +
      _regions.length +
      completedBosses +
      (definition.requiredBlessingShrine != null && _blessingReceived ? 1 : 0) +
      (definition.requiresFirstCoin && _firstCoinCollected ? 1 : 0);
  int get totalObjectives =>
      (definition.requiresFirstCoin ? 1 : 0) +
      (definition.requiredBlessingShrine != null ? 1 : 0) +
      definition.requiredEnemies.length +
      definition.requiredRescues.length +
      definition.requiredRegions.length +
      definition.route.missionChunks
          .where((o) => o.pattern.bossArena != null)
          .length;

  CampaignSnapshot snapshot() => CampaignSnapshot(
    missionId: definition.id,
    firstCoinRequired: definition.requiresFirstCoin,
    firstCoinCollected: _firstCoinCollected,
    blessingRequired: definition.requiredBlessingShrine != null,
    blessingReceived: _blessingReceived,
    completed: completedObjectives,
    required: totalObjectives,
    failed: failed,
    exitX: definition.worldX(definition.exit.origin),
    exitY: definition.exit.origin.y,
  );
}
