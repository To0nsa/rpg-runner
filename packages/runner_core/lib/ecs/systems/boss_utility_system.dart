import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../bosses/boss_utility_delivery.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../combat/control_lock.dart';
import '../../enemies/enemy_catalog.dart';
import '../../enemies/enemy_id.dart';
import '../../encounters/encounter_definition.dart';
import '../../encounters/encounter_placement.dart';
import '../../navigation/terrain_spawn_placement.dart';
import '../../snapshots/enums.dart';
import '../../spawn_service.dart';
import '../../util/vec2.dart';
import '../actor_facing.dart';
import '../combat_target.dart';
import '../entity_id.dart';
import '../world.dart';
import 'ai_ability_commit.dart';
import 'world_motion_authority.dart';

/// Executes committed boss utilities without choosing a boss's attacks.
/// Summons enter before motion preparation; teleports use terrain-owned commits.
final class BossUtilitySystem {
  BossUtilitySystem({
    required this.tickHz,
    required this.motion,
    required this.spawns,
    required this.groundTopY,
  });
  final int tickHz;
  final WorldMotionAuthority motion;
  final SpawnService spawns;
  final double groundTopY;

  /// Admission and expiration occur before body enumeration for the tick.
  void prepare(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    for (final summon in world.bossSummon.denseEntities.toList()) {
      final si = world.bossSummon.indexOf(summon);
      final owner = world.bossSummon.owner[si];
      if (!world.bossCombat.has(owner) ||
          !isLivingCombatActor(world, owner) ||
          currentTick >= world.bossSummon.expiresTick[si]) {
        world.destroyEntity(summon);
      }
    }
    final states = world.bossCombat;
    for (var i = 0; i < states.denseEntities.length; i++) {
      final boss = states.denseEntities[i];
      if (states.executeTick[i] != currentTick) continue;
      final ability = AbilityCatalog.shared.resolve(
        states.utilityAbility[i] ?? '',
      );
      if (ability?.hitDelivery is! BossSummonDelivery) continue;
      states.executeTick[i] = -1;
      if (!_utilityCurrent(world, boss, i, currentTick)) continue;
      _summon(
        world,
        boss,
        player,
        i,
        ability!.hitDelivery as BossSummonDelivery,
        currentTick,
      );
    }
  }

  /// Refresh teleport placement before water and navigation observe positions.
  void executeTeleports(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    final states = world.bossCombat;
    for (var i = 0; i < states.denseEntities.length; i++) {
      final boss = states.denseEntities[i];
      if (states.executeTick[i] != currentTick) continue;
      final ability = AbilityCatalog.shared.resolve(
        states.utilityAbility[i] ?? '',
      );
      if (ability?.hitDelivery is! BossTeleportDelivery) continue;
      states.executeTick[i] = -1;
      if (_utilityCurrent(world, boss, i, currentTick)) {
        _teleport(
          world,
          boss,
          i,
          world.transform.posX[world.transform.indexOf(player)],
        );
      }
      states.teleportDestination[i] = null;
    }
  }

  /// Captures a utility intent for an actor with boss state and arena bounds.
  /// Placement occurs at the scaled windup tick, only while this action survives.
  bool commit(
    EcsWorld world, {
    required EntityId boss,
    required AbilityDef ability,
    required double targetX,
    required int tick,
  }) {
    if (!world.actorMotionBounds.has(boss) ||
        !canCommitAiAbility(
          world,
          boss,
          currentTick: tick,
          lock: LockFlag.cast,
          cooldownGroupId: 0,
          cost: AbilityResourceCost.zero,
        )) {
      return false;
    }
    final ti = world.transform.indexOf(boss);
    final delivery = ability.hitDelivery;
    final destination = delivery is BossTeleportDelivery
        ? _resolveTeleport(world, boss, targetX, delivery)
        : null;
    if (delivery is BossTeleportDelivery && destination == null) return false;
    final facing = targetX >= world.transform.posX[ti]
        ? Facing.right
        : Facing.left;
    setActorFacing(world, boss, facing);
    final windup = _ticks(ability.windupTicks);
    final active = _ticks(ability.activeTicks);
    final recovery = _ticks(ability.recoveryTicks);
    world.activeAbility.set(
      boss,
      id: ability.id,
      slot: AbilitySlot.projectile,
      commitTick: tick,
      windupTicks: windup,
      activeTicks: active,
      recoveryTicks: recovery,
      facingDir: facing,
    );
    world.cooldown.startCooldown(boss, 0, _ticks(ability.cooldownTicks));
    final states = world.bossCombat;
    final i = states.indexOf(boss);
    states.utilityAbility[i] = ability.id;
    states.utilityStartTick[i] = tick;
    states.executeTick[i] = tick + windup;
    states.targetX[i] = targetX;
    states.teleportDestination[i] = destination;
    return true;
  }

  bool _utilityCurrent(EcsWorld world, EntityId boss, int i, int tick) {
    final ai = world.activeAbility.tryIndexOf(boss);
    return isLivingCombatActor(world, boss) &&
        !world.arenaSuspension.has(boss) &&
        !world.controlLock.isStunned(boss, tick) &&
        ai != null &&
        world.activeAbility.abilityId[ai] ==
            world.bossCombat.utilityAbility[i] &&
        world.activeAbility.startTick[ai] ==
            world.bossCombat.utilityStartTick[i];
  }

  /// Counts living owned actors; corpses do not consume the ability's cap.
  int livingSummons(EcsWorld world, EntityId owner) {
    var count = 0;
    for (var i = 0; i < world.bossSummon.denseEntities.length; i++) {
      if (world.bossSummon.owner[i] == owner &&
          isLivingCombatActor(world, world.bossSummon.denseEntities[i])) {
        count++;
      }
    }
    return count;
  }

  /// Resolves an actor at world X on valid support inside the owner's arena.
  /// This is a read-only placement query; callers commit through [motion].
  TerrainSpawnPlacementResult? resolveArenaPlacement(
    EcsWorld world,
    EntityId owner,
    EnemyId id,
    double x,
  ) {
    final bi = world.actorMotionBounds.tryIndexOf(owner);
    final bounds = bi == null ? null : world.actorMotionBounds.bounds[bi];
    if (bounds == null) return null;
    final requestedX = x * terrainPhysicsTicksPerWorldUnit;
    if (requestedX < bounds.minXTicks || requestedX > bounds.maxXTicks) {
      return null;
    }
    final request = createEncounterSpawnRequest(
      member: EncounterEnemyPlacement(id: 'summon', enemyId: id, x: 0),
      startX: x,
      groundTopY: groundTopY,
      flyingHoverOffsetY: 0,
    );
    final result = motion.resolveSpawnPlacement(request);
    if (!result.accepted) return null;
    final capsule =
        (request.profile as TerrainActorSpawnPlacementProfile).capsule;
    final margin = capsule.radiusTicks + capsule.resolvedOffsetXTicks.abs();
    final bodyX = result.bodyCenter!.xTicks;
    return bodyX - margin >= bounds.minXTicks &&
            bodyX + margin <= bounds.maxXTicks
        ? result
        : null;
  }

  void _summon(
    EcsWorld world,
    EntityId boss,
    EntityId player,
    int i,
    BossSummonDelivery delivery,
    int tick,
  ) {
    var alive = livingSummons(world, boss);
    var admitted = 0;
    if (alive >= delivery.maxAlive) return;
    final playerX = world.transform.posX[world.transform.indexOf(player)];
    for (final offset in const [72.0, -72.0, 120.0, -120.0]) {
      final placement = resolveArenaPlacement(
        world,
        boss,
        delivery.enemyId,
        world.bossCombat.targetX[i] + offset,
      );
      if (placement == null) continue;
      final body = placement.bodyCenter!;
      final x = body.xTicks / terrainPhysicsTicksPerWorldUnit;
      final margin =
          const EnemyCatalog().get(delivery.enemyId).collider.halfX +
          world.colliderAabb.halfX[world.colliderAabb.indexOf(player)] +
          20;
      if ((x - playerX).abs() < margin) continue;
      var overlaps = false;
      for (final other in world.bossSummon.denseEntities) {
        if ((world.transform.posX[world.transform.indexOf(other)] - x).abs() <
            40) {
          overlaps = true;
          break;
        }
      }
      if (overlaps) continue;
      final summon = spawns.spawnGroundEnemy(
        enemyId: delivery.enemyId,
        spawnX: x,
        spawnBodyY: body.yTicks / terrainPhysicsTicksPerWorldUnit,
        groundTopY: groundTopY,
        spawnTick: tick,
      );
      final si = world.bossSummon.addEntity(summon);
      world.bossSummon.owner[si] = boss;
      world.bossSummon.expiresTick[si] =
          tick + (delivery.lifetimeSeconds * tickHz).ceil();
      world.actorMotionBounds.add(
        summon,
        world.actorMotionBounds.bounds[world.actorMotionBounds.indexOf(boss)]!,
      );
      alive++;
      admitted++;
      if (alive >= delivery.maxAlive || admitted >= delivery.count) return;
    }
  }

  Vec2? _resolveTeleport(
    EcsWorld world,
    EntityId boss,
    double target,
    BossTeleportDelivery delivery,
  ) {
    final ti = world.transform.indexOf(boss);
    final oldX = world.transform.posX[ti];
    final preferred = oldX >= target ? -delivery.distance : delivery.distance;
    for (final offset in [preferred, -preferred]) {
      final placement = resolveArenaPlacement(
        world,
        boss,
        world.enemy.enemyId[world.enemy.indexOf(boss)],
        target + offset,
      );
      if (placement == null) continue;
      final body = placement.bodyCenter!;
      final x = body.xTicks / terrainPhysicsTicksPerWorldUnit;
      if ((x - target).abs() < 70 || (x - oldX).abs() < 64) continue;
      return Vec2(x, body.yTicks / terrainPhysicsTicksPerWorldUnit);
    }
    return null;
  }

  void _teleport(EcsWorld world, EntityId boss, int i, double currentTargetX) {
    final destination = world.bossCombat.teleportDestination[i];
    if (destination == null || (destination.x - currentTargetX).abs() < 70) {
      return;
    }
    // The warning mark never moves. Terrain or player movement can invalidate
    // it, in which case the original body remains and ordinary recovery applies.
    final placement = resolveArenaPlacement(
      world,
      boss,
      world.enemy.enemyId[world.enemy.indexOf(boss)],
      destination.x,
    );
    if (placement == null ||
        placement.bodyCenter!.xTicks !=
            (destination.x * terrainPhysicsTicksPerWorldUnit).round() ||
        placement.bodyCenter!.yTicks !=
            (destination.y * terrainPhysicsTicksPerWorldUnit).round()) {
      return;
    }
    final origin = motion.beginBodyTeleport(world, boss);
    if (!motion.tryCommitBodyTeleport(
      world,
      boss,
      bodyX: destination.x,
      bodyY: destination.y,
      facing: destination.x <= currentTargetX ? Facing.right : Facing.left,
    )) {
      motion.cancelBodyTeleport(world, boss, origin);
    }
  }

  int _ticks(int ticks60) => (ticks60 * tickHz / 60).ceil();
}
