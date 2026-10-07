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
          ability!.hitDelivery as BossTeleportDelivery,
          world.transform.posX[world.transform.indexOf(player)],
        );
      }
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

  TerrainSpawnPlacementResult? _position(
    EcsWorld world,
    EntityId owner,
    EnemyId id,
    double x,
  ) {
    final bi = world.actorMotionBounds.tryIndexOf(owner);
    final bounds = bi == null ? null : world.actorMotionBounds.bounds[bi];
    if (bounds == null) return null;
    final request = createEncounterSpawnRequest(
      member: EncounterEnemyPlacement(id: 'summon', enemyId: id, x: x),
      startX: 0,
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
    if (livingSummons(world, boss) >= delivery.maxAlive) return;
    final playerX = world.transform.posX[world.transform.indexOf(player)];
    for (final offset in const [72.0, -72.0, 120.0, -120.0]) {
      final placement = _position(
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
      return;
    }
  }

  void _teleport(
    EcsWorld world,
    EntityId boss,
    int i,
    BossTeleportDelivery delivery,
    double currentTargetX,
  ) {
    final ti = world.transform.indexOf(boss);
    final oldX = world.transform.posX[ti];
    final target = world.bossCombat.targetX[i];
    final preferred = oldX >= target ? -delivery.distance : delivery.distance;
    for (final offset in [preferred, -preferred]) {
      final placement = _position(
        world,
        boss,
        world.enemy.enemyId[world.enemy.indexOf(boss)],
        target + offset,
      );
      if (placement == null) continue;
      final body = placement.bodyCenter!;
      final x = body.xTicks / terrainPhysicsTicksPerWorldUnit;
      if ((x - currentTargetX).abs() < 70) continue;
      final origin = motion.beginBodyTeleport(world, boss);
      final placed = motion.tryCommitBodyTeleport(
        world,
        boss,
        bodyX: x,
        bodyY: body.yTicks / terrainPhysicsTicksPerWorldUnit,
        facing: x <= currentTargetX ? Facing.right : Facing.left,
      );
      if (!placed) {
        motion.cancelBodyTeleport(world, boss, origin);
        continue;
      }
      return;
    }
    // Reappear at the original valid position when both candidates are blocked.
  }

  int _ticks(int ticks60) => (ticks60 * tickHz / 60).ceil();
}
