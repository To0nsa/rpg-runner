import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../bosses/boss_utility_delivery.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../combat/ai_cast_aim_policy.dart';
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
import 'enemy_cast_system.dart';
import 'enemy_melee_system.dart';
import 'world_motion_authority.dart';

/// Chunk-independent Ancient God decisions with shared damage executors.
/// Summons enter before motion preparation; teleports use terrain-owned commits.
final class AncientGodCombatSystem {
  AncientGodCombatSystem({
    required this.tickHz,
    required this.motion,
    required this.spawns,
    required this.castCommitter,
    required this.groundTopY,
  });
  final int tickHz;
  final WorldMotionAuthority motion;
  final SpawnService spawns;
  final AiCastCommitter castCommitter;
  final double groundTopY;
  late final _melee = AiMeleeCommitter(tickHz: tickHz);

  /// Admission and expiration occur before body enumeration for the tick.
  void prepare(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    for (final summon in world.bossSummon.denseEntities.toList()) {
      final si = world.bossSummon.indexOf(summon);
      final owner = world.bossSummon.owner[si];
      if (!world.ancientBoss.has(owner) ||
          !isLivingCombatActor(world, owner) ||
          currentTick >= world.bossSummon.expiresTick[si]) {
        world.destroyEntity(summon);
      }
    }
    final states = world.ancientBoss;
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
    final states = world.ancientBoss;
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

  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    // Tentacles are planted actors. Combat reach is shared with their strike art.
    for (final entity in world.bossSummon.denseEntities) {
      final ei = world.enemy.tryIndexOf(entity);
      if (ei == null || world.enemy.enemyId[ei] != EnemyId.voidTentacle) {
        continue;
      }
      final ni = world.navIntent.tryIndexOf(entity);
      if (ni != null) world.navIntent.hasPlan[ni] = false;
      final ii = world.engagementIntent.tryIndexOf(entity);
      if (ii != null) world.engagementIntent.speedScale[ii] = 0;
    }
    final states = world.ancientBoss;
    for (var i = 0; i < states.denseEntities.length; i++) {
      final boss = states.denseEntities[i];
      if (!isLivingCombatActor(world, boss) ||
          world.controlLock.isLocked(boss, LockFlag.allActions, currentTick)) {
        continue;
      }
      final ei = world.enemy.indexOf(boss);
      final id = world.enemy.enemyId[ei];
      final ti = world.transform.indexOf(boss);
      final target = combatTarget(world, boss, player);
      if (target == null) continue;
      final targetTi = world.transform.indexOf(target);
      final targetX = world.transform.posX[targetTi];
      final targetY = world.transform.posY[targetTi];
      final ni = world.navIntent.indexOf(boss);
      final ii = world.engagementIntent.indexOf(boss);
      final direct = world.navIntent.canWalkDirectlyToTarget[ni];
      if (direct) world.navIntent.hasPlan[ni] = false;
      final standOff = id == EnemyId.voidcaller ? 180.0 : 65.0;
      world.engagementIntent.desiredTargetX[ii] = direct
          ? targetX +
                (world.transform.posX[ti] >= targetX ? standOff : -standOff)
          : world.navIntent.navTargetX[ni];
      world.engagementIntent.speedScale[ii] = id == EnemyId.voidcaller
          ? .45
          : .8;
      world.engagementIntent.arrivalSlowRadiusX[ii] = 30;
      world.engagementIntent.meleeRangeX[ii] = standOff;
      if (world.activeAbility.hasActiveAbility(boss)) {
        world.controlLock.addLock(
          boss,
          LockFlag.move | LockFlag.jump,
          1,
          currentTick,
        );
        continue;
      }
      if (world.cooldown.isOnCooldown(boss, 0)) continue;
      final sequence = states.actionIndex[i];
      final dx = (targetX - world.transform.posX[ti]).abs();
      final atHeight = (targetY - world.transform.posY[ti]).abs() <= 50;
      String key;
      if (id != EnemyId.voidcaller &&
          currentTick >= states.nextTeleportTick[i] &&
          sequence >= 3) {
        key = id == EnemyId.shoggoth ? 'shoggoth.teleport' : 'goddess.teleport';
      } else {
        key = switch (id) {
          EnemyId.voidbornGoddess =>
            dx <= 85 && atHeight && sequence % 3 == 0
                ? 'goddess.claw_combo'
                : sequence.isEven
                ? 'goddess.orb'
                : 'goddess.eruption',
          EnemyId.shoggoth =>
            sequence % 4 == 3 && _livingSummons(world, boss) < 3
                ? 'shoggoth.summon'
                : dx <= 150 && atHeight && sequence % 3 == 1
                ? 'shoggoth.spinning_charge'
                : dx <= 85 && atHeight
                ? 'shoggoth.tentacle_sweep'
                : 'shoggoth.orb',
          EnemyId.voidcaller => switch (sequence % 4) {
            0 => 'voidcaller.vertical_beam',
            1 => 'voidcaller.diagonal_beam',
            2 => 'voidcaller.claw',
            _ =>
              _livingSummons(world, boss) < 2
                  ? 'voidcaller.summon'
                  : 'voidcaller.claw',
          },
          _ => throw StateError('Unexpected Ancient God identity ${id.name}'),
        };
      }
      final ability = AbilityCatalog.shared.resolve(key)!;
      final bool committed;
      if (ability.hitDelivery is MeleeHitDelivery) {
        committed =
            _melee.commit(
              world,
              actor: boss,
              abilityId: key,
              targetX: targetX,
              currentTick: currentTick,
            ) !=
            null;
      } else if (ability.hitDelivery is BossSummonDelivery ||
          ability.hitDelivery is BossTeleportDelivery) {
        committed = _commitUtility(
          world,
          boss,
          i,
          ability,
          targetX,
          currentTick,
        );
      } else {
        committed = castCommitter.commit(
          world,
          actor: boss,
          castAbility: ability,
          sourceX: world.transform.posX[ti],
          sourceY: world.transform.posY[ti],
          targetX: targetX,
          targetY: targetY,
          targetVelX: 0,
          targetVelY: 0,
          aimPolicy: AiCastAimPolicy.targetCenter,
          casterOriginOffset: 30,
          currentTick: currentTick,
        );
      }
      if (committed) {
        states.actionIndex[i]++;
        world.controlLock.addLock(
          boss,
          LockFlag.move | LockFlag.jump,
          1,
          currentTick,
        );
      }
    }
  }

  /// Compose the committed spin after locomotion; terrain still integrates once.
  void composeMotion(EcsWorld world, {required int currentTick}) {
    for (final boss in world.ancientBoss.denseEntities) {
      final ai = world.activeAbility.indexOf(boss);
      if (world.activeAbility.abilityId[ai] != 'shoggoth.spinning_charge' ||
          world.activeAbility.phase[ai] != AbilityPhase.active ||
          !isLivingCombatActor(world, boss) ||
          world.arenaSuspension.has(boss) ||
          world.controlLock.isStunned(boss, currentTick)) {
        continue;
      }
      final ti = world.transform.indexOf(boss);
      // 180 world units/sec: bounded charge; gravity, walls and arena bounds apply.
      world.transform.velX[ti] = world.activeAbility.facing[ai] == Facing.left
          ? -180
          : 180;
    }
  }

  bool _commitUtility(
    EcsWorld world,
    EntityId boss,
    int i,
    AbilityDef ability,
    double targetX,
    int tick,
  ) {
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
    final states = world.ancientBoss;
    states.utilityAbility[i] = ability.id;
    states.utilityStartTick[i] = tick;
    states.executeTick[i] = tick + windup;
    states.targetX[i] = targetX;
    if (ability.hitDelivery is BossTeleportDelivery) {
      // Eight seconds between relocations keeps the boss available to attack.
      states.nextTeleportTick[i] = tick + 8 * tickHz;
    }
    return true;
  }

  bool _utilityCurrent(EcsWorld world, EntityId boss, int i, int tick) {
    final ai = world.activeAbility.tryIndexOf(boss);
    return isLivingCombatActor(world, boss) &&
        !world.arenaSuspension.has(boss) &&
        !world.controlLock.isStunned(boss, tick) &&
        ai != null &&
        world.activeAbility.abilityId[ai] ==
            world.ancientBoss.utilityAbility[i] &&
        world.activeAbility.startTick[ai] ==
            world.ancientBoss.utilityStartTick[i];
  }

  int _livingSummons(EcsWorld world, EntityId owner) {
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
    if (_livingSummons(world, boss) >= delivery.maxAlive) return;
    final playerX = world.transform.posX[world.transform.indexOf(player)];
    for (final offset in const [72.0, -72.0, 120.0, -120.0]) {
      final placement = _position(
        world,
        boss,
        delivery.enemyId,
        world.ancientBoss.targetX[i] + offset,
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
    final target = world.ancientBoss.targetX[i];
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
