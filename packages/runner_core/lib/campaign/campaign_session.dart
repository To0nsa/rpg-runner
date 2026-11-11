import '../collision/terrain/terrain_motion_request.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../ecs/entity_id.dart';
import '../ecs/world.dart';
import '../encounters/encounter_instance.dart';
import '../track/track_streamer.dart';
import '../snapshots/campaign_snapshot.dart';
import 'campaign_mission_definition.dart';

/// Attempt-local objectives. Observed before death cleanup so recycled entity
/// IDs can never satisfy an earlier occurrence's target.
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
  final Set<CampaignRescueTarget> _rescued = {};
  final Set<int> _regions = {};
  bool failed = false;
  int completedBosses = 0;

  void registerEnemy(SpawnEnemyRequest request, EntityId? entity) {
    final id = request.occurrenceId;
    final salt = request.markerSalt;
    if (id == null || salt == null) return;
    final target = (occurrenceId: id, markerSalt: salt);
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
      occurrenceId: definition.route.occurrences[outcome.key.chunkIndex].id,
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
      world.actorMotionBounds.add(
        actor,
        local == null
            ? bounds
            : TerrainHorizontalBounds(
                minXTicks: local.minXTicks.clamp(
                  bounds.minXTicks,
                  bounds.maxXTicks - 1,
                ),
                maxXTicks: local.maxXTicks.clamp(
                  bounds.minXTicks + 1,
                  bounds.maxXTicks,
                ),
              ),
      );
    }
  }

  void observeBeforeCleanup(EcsWorld world) {
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

  bool resolveLivingPlayer(double x, double y) {
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
      _defeated.length + _rescued.length + _regions.length + completedBosses;
  int get totalObjectives =>
      definition.requiredEnemies.length +
      definition.requiredRescues.length +
      definition.requiredRegions.length +
      definition.route.occurrences
          .where((o) => o.pattern.bossArena != null)
          .length;

  CampaignSnapshot snapshot() => CampaignSnapshot(
    missionId: definition.id,
    completed: completedObjectives,
    required: totalObjectives,
    failed: failed,
    exitX: definition.worldX(definition.exit.origin),
    exitY: definition.exit.origin.y,
  );
}
