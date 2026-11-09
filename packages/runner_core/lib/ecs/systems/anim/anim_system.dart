import '../../stores/enemies/derf_phase_store.dart';
import '../../../combat/combat_geometry.dart';
import '../../../collision/terrain/terrain_numeric.dart';
import '../../../combat/combat_pose_catalog.dart';
import '../../../players/characters/eloise.dart';
import '../../../contracts/render_anim_set_definition.dart';

import 'dart:math' as math;

import '../../../anim/anim_resolver.dart';
import '../../../abilities/ability_catalog.dart';
import '../../../bosses/boss_utility_delivery.dart';
import '../../../abilities/ability_def.dart';
import '../../../events/game_event.dart';
import '../../../snapshots/enums.dart';
import '../../../enemies/death_behavior.dart';
import '../../../enemies/enemy_catalog.dart';
import '../../../enemies/enemy_id.dart';
import '../../../enemies/enemy_terrain_profile.dart';
import '../../../npcs/npc_catalog.dart';
import '../../../players/player_tuning.dart';
import '../../../players/player_projectile_muzzle.dart';
import '../../../tuning/utils/anim_tuning.dart' as anim_utils;
import '../../../util/tick_math.dart';
import '../../entity_id.dart';
import '../../world.dart';
import '../../world_support_view.dart';

/// System that computes per-entity animation state each tick.
///
/// Uses [AnimResolver] with per-entity [AnimProfile]s to pick the animation key
/// and frame offset deterministically.
class AnimSystem {
  AnimSystem({
    required int tickHz,
    this.playerRenderAnim = eloiseRenderAnim,
    required this.enemyCatalog,
    required MovementTuningDerived playerMovement,
    required AnimTuningDerived playerAnimTuning,
    this.abilities = AbilityCatalog.shared,
  }) : _tickHz = tickHz,
       _playerAnimTuning = playerAnimTuning,
       _playerProfile = AnimProfile(
         minMoveSpeed: playerMovement.base.minMoveSpeed,
         runSpeedThresholdX: playerMovement.base.runSpeedThresholdX,
         supportsWalk: true,
         supportsJumpFall: true,
         supportsDash: true,
         supportsCast: true,
         supportsRanged: true,
         supportsSpawn: true,
         supportsStun: true,
         directionalStrike: playerRenderAnim.sourcesByKey.containsKey(
           AnimKey.backStrike,
         ),
       ) {
    _buildHitAnimTicksById(tickHz);
    _buildSpawnAnimTicksById(tickHz);
  }

  /// Catalog for per-enemy configuration (hit windows, anim profiles).
  final EnemyCatalog enemyCatalog;
  final AbilityResolver abilities;

  final RenderAnimSetDefinition playerRenderAnim;
  bool _advanceLocomotion = true;
  final int _tickHz;
  final AnimTuningDerived _playerAnimTuning;
  final AnimProfile _playerProfile;

  /// Pre-computed hit animation durations in ticks per enemy type.
  late final Map<EnemyId, int> _hitAnimTicksById;
  late final Map<EnemyId, int> _spawnAnimTicksById;

  void _buildHitAnimTicksById(int tickHz) {
    _hitAnimTicksById = <EnemyId, int>{};
    for (final id in EnemyId.values) {
      final archetype = enemyCatalog.get(id);
      _hitAnimTicksById[id] = _lifecycleTicksFor(
        archetype,
        key: AnimKey.hit,
        fallbackSeconds: archetype.hitAnimSeconds,
        tickHz: tickHz,
      );
    }
  }

  void _buildSpawnAnimTicksById(int tickHz) {
    _spawnAnimTicksById = <EnemyId, int>{};
    for (final id in EnemyId.values) {
      final archetype = enemyCatalog.get(id);
      final ticks = archetype.animProfile.supportsSpawn
          ? _lifecycleTicksFor(
              archetype,
              key: AnimKey.spawn,
              fallbackSeconds: archetype.spawnAnimSeconds,
              tickHz: tickHz,
            )
          : 0;
      _spawnAnimTicksById[id] = ticks;
    }
  }

  int _lifecycleTicksFor(
    EnemyArchetype archetype, {
    required AnimKey key,
    required double fallbackSeconds,
    required int tickHz,
  }) {
    final renderAnim = archetype.renderAnim;
    if (!renderAnim.frameCountsByKey.containsKey(key) ||
        !renderAnim.stepTimeSecondsByKey.containsKey(key)) {
      return ticksFromSecondsCeil(fallbackSeconds, tickHz);
    }
    return anim_utils.ticksForKey(
      key: key,
      frameCounts: renderAnim.frameCountsByKey,
      stepTimeSecondsByKey: renderAnim.stepTimeSecondsByKey,
      tickHz: tickHz,
    );
  }

  /// Updates animation state for player and enemies.
  ///
  /// Call this once per tick before [SnapshotBuilder.build].
  /// [playerDeathGrounded] preserves support at death before motion cleanup;
  /// omit it to select the death strip from current support.
  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
    DeathPhase playerDeathPhase = DeathPhase.none,
    int playerDeathStartTick = -1,
    bool? playerDeathGrounded,
    int playerSpawnStartTick = 0,
    bool advanceLocomotion = true,
  }) {
    _advanceLocomotion = advanceLocomotion;
    _stepPlayer(
      world,
      player: player,
      currentTick: currentTick,
      deathPhase: playerDeathPhase,
      deathStartTick: playerDeathStartTick,
      deathGrounded: playerDeathGrounded,
      spawnStartTick: playerSpawnStartTick,
    );
    _stepEnemies(world, currentTick: currentTick);
    for (var i = 0; i < world.npc.denseEntities.length; i++) {
      final archetype = const NpcCatalog().get(world.npc.npcId[i]);
      _stepAutonomousActor(
        world,
        entity: world.npc.denseEntities[i],
        currentTick: currentTick,
        profile: archetype.animProfile,
        hitAnimTicks: anim_utils.ticksForKey(
          key: AnimKey.hit,
          frameCounts: archetype.renderAnim.frameCountsByKey,
          stepTimeSecondsByKey: archetype.renderAnim.stepTimeSecondsByKey,
          tickHz: _tickHz,
        ),
        configuredSpawnAnimTicks: 0,
        usesSurfaceDistance: true,
      );
    }
  }

  void _stepPlayer(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
    required DeathPhase deathPhase,
    required int deathStartTick,
    required bool? deathGrounded,
    required int spawnStartTick,
  }) {
    if (player < 0) return;
    if (!world.animState.has(player)) return;
    if (!world.transform.has(player) || !world.movement.has(player)) return;

    final ai = world.animState.indexOf(player);
    final common = _readCommonSignals(
      world,
      entity: player,
      currentTick: currentTick,
    );

    // Phase 6: Active Action Layer
    final activeAction = _resolveActiveAction(
      world,
      entity: player,
      currentTick: currentTick,
      stunned: common.stunLocked,
      hp: common.hp,
      deathPhase: deathPhase,
    );

    final signals = AnimSignals.player(
      tick: currentTick,
      hp: common.hp,
      deathPhase: deathPhase,
      deathStartTick: deathStartTick,
      grounded: common.grounded,
      velX: common.velX,
      velY: common.velY,
      lastDamageTick: common.lastDamageTick,
      hitAnimTicks: _playerAnimTuning.hitAnimTicks,
      spawnStartTick: spawnStartTick,
      spawnAnimTicks: _playerAnimTuning.spawnAnimTicks,
      stunLocked: common.stunLocked,
      stunStartTick: common.stunStartTick,
      activeActionAnim: activeAction.anim,
      activeActionFrame: activeAction.frame,
    );

    var result = AnimResolver.resolve(_playerProfile, signals);
    final variant = switch (result.anim) {
      AnimKey.hit when !common.grounded => AnimKey.airHit,
      AnimKey.death when !(deathGrounded ?? common.grounded) =>
        AnimKey.airDeath,
      _ => result.anim,
    };
    if (playerRenderAnim.sourcesByKey.containsKey(variant)) {
      result = AnimResult(anim: variant, animFrame: result.animFrame);
    }
    final ji = world.jumpState.tryIndexOf(player);
    if (ji != null &&
        !common.grounded &&
        (result.anim == AnimKey.jump || result.anim == AnimKey.fall) &&
        playerRenderAnim.sourcesByKey.containsKey(AnimKey.doubleJump)) {
      final start = world.jumpState.lastAirJumpTick[ji];
      final duration = anim_utils.ticksForKey(
        key: AnimKey.doubleJump,
        frameCounts: playerRenderAnim.frameCountsByKey,
        stepTimeSecondsByKey: playerRenderAnim.stepTimeSecondsByKey,
        tickHz: _tickHz,
      );
      if (start >= 0 && currentTick - start < duration) {
        result = AnimResult(
          anim: AnimKey.doubleJump,
          animFrame: currentTick - start,
        );
      }
    }
    world.animState.anim[ai] = result.anim;
    world.animState.animFrame[ai] = _terrainLocomotionAnimFrame(
      world,
      entity: player,
      animStateIndex: ai,
      resolved: result,
    );
    _updatePlayerDashVisual(world, player, ai, currentTick, result);
  }

  void _updatePlayerDashVisual(
    EcsWorld world,
    EntityId player,
    int ai,
    int tick,
    AnimResult resolved,
  ) {
    final state = world.animState;
    final hold = playerRenderAnim.dashHoldFrame;
    final count = playerRenderAnim.frameCountsByKey[AnimKey.dash] ?? 0;
    if (hold == null || hold < 0 || hold >= count - 1) {
      state.clearDashVisual(ai);
      return;
    }
    final activeIndex = world.activeAbility.tryIndexOf(player);
    final activeId = activeIndex == null
        ? null
        : world.activeAbility.abilityId[activeIndex];
    final ability = activeId == null ? null : abilities.resolve(activeId);
    final activeDash = ability?.animKey == AnimKey.dash;
    if (activeDash) {
      final start = world.activeAbility.startTick[activeIndex!];
      if (start != state.dashVisualStartTick[ai]) {
        state.dashVisualStartTick[ai] = start;
        state.dashVisualRecoveryStartTick[ai] = -1;
        state.dashVisualFrame[ai] = 0;
      }
    }
    if (state.dashVisualFrame[ai] < 0) return;
    final locomotion =
        resolved.anim == AnimKey.run ||
        resolved.anim == AnimKey.walk ||
        resolved.anim == AnimKey.idle;
    // Interruptions win immediately. Airborne exits return to jump/fall rather
    // than playing planted-foot recovery poses in the air.
    if (world.swimState.isSwimming(player) ||
        (activeDash ? resolved.anim != AnimKey.dash : !locomotion) ||
        (!activeDash &&
            (activeId != null ||
                !WorldSupportView(world).isGrounded(player)))) {
      state.clearDashVisual(ai);
      return;
    }
    final step = math.max(
      1,
      ((playerRenderAnim.stepTimeSecondsByKey[AnimKey.dash] ?? .1) * _tickHz)
          .round(),
    );
    if (activeDash) {
      state.dashVisualFrame[ai] =
          math.min(hold, (tick - state.dashVisualStartTick[ai]) ~/ step) * step;
      return;
    }
    final mi = world.movement.indexOf(player);
    final ti = world.transform.indexOf(player);
    final direction = world.movement.dashDirX[mi].sign;
    final facing = world.movement.facing[mi] == Facing.right ? 1 : -1;
    if (direction != facing || world.transform.velX[ti] * direction < 0) {
      state.clearDashVisual(ai);
      return;
    }
    var recovery = state.dashVisualRecoveryStartTick[ai];
    if (recovery < 0) {
      final motion = world.resolvedMotion.tryIndexOf(player);
      var reference = motion == null
          ? 0.0
          : world
                    .resolvedMotion
                    .locomotionReferenceSpeedTicksPerSecond[motion] /
                terrainPhysicsTicksPerWorldUnit;
      final contact = world.terrainContact.tryIndexOf(player);
      final traversal = world.terrainTraversalProfile.tryIndexOf(player);
      if (contact != null &&
          traversal != null &&
          world.terrainContact.supportEdgeId[contact] != null) {
        // The locomotion reference is flat-ground speed. Match the traversal
        // profile's target so downhill running can finish the visual coast.
        final uphill =
            direction *
                world.terrainContact.supportTangentXTicks[contact] *
                world.terrainContact.supportTangentYTicks[contact] <
            0;
        reference *=
            world.terrainTraversalProfile.profile[traversal].slopeMultiplierBp(
              absoluteAngleUnits:
                  world.terrainContact.supportSlopeAngleUnits[contact],
              uphill: uphill,
            ) /
            10000;
      }
      // With released input the target speed is zero: keep the glide pose
      // until stopping. Held input recovers once ordinary running speed returns.
      // Reference speed and velocity are quantized separately.
      if (world.transform.velX[ti].abs() >
          math.max(reference, _playerProfile.minMoveSpeed) +
              1 / terrainPhysicsTicksPerWorldUnit) {
        state.dashVisualFrame[ai] = hold * step;
        return;
      }
      recovery = tick;
      state.dashVisualRecoveryStartTick[ai] = recovery;
    }
    final frame = hold + 1 + (tick - recovery) ~/ step;
    if (frame >= count) {
      state.clearDashVisual(ai);
    } else {
      state.dashVisualFrame[ai] = frame * step;
    }
  }

  void _stepEnemies(EcsWorld world, {required int currentTick}) {
    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final e = enemies.denseEntities[ei];
      final enemyId = enemies.enemyId[ei];
      _stepAutonomousActor(
        world,
        entity: e,
        currentTick: currentTick,
        profile: enemyCatalog.get(enemyId).animProfile,
        hitAnimTicks: _hitAnimTicksById[enemyId] ?? 0,
        configuredSpawnAnimTicks: _spawnAnimTicksById[enemyId] ?? 0,
        usesSurfaceDistance:
            enemyCatalog.terrainContactProfile(enemyId).locomotionKind ==
            EnemyTerrainLocomotionKind.constantSurfaceDistance,
      );
    }
  }

  void _stepAutonomousActor(
    EcsWorld world, {
    required EntityId entity,
    required int currentTick,
    required AnimProfile profile,
    required int hitAnimTicks,
    required int configuredSpawnAnimTicks,
    required bool usesSurfaceDistance,
  }) {
    final e = entity;
    final animStore = world.animState;
    if (!animStore.has(e)) return;
    final ai = animStore.indexOf(e);
    final common = _readCommonSignals(
      world,
      entity: e,
      currentTick: currentTick,
    );

    final di = world.deathState.tryIndexOf(e);
    final deathPhase = di == null
        ? DeathPhase.none
        : world.deathState.phase[di];
    final deathStartTick = di == null
        ? -1
        : world.deathState.deathStartTick[di];

    final spawnIndex = world.spawnState.tryIndexOf(e);
    final spawnStartTick = spawnIndex == null
        ? -1
        : world.spawnState.startTick[spawnIndex];
    final spawnAnimTicks = spawnIndex == null
        ? configuredSpawnAnimTicks
        : world.spawnState.animTicks[spawnIndex];

    final derf = world.derfPhase.tryIndexOf(e);
    if (derf != null &&
        world.derfPhase.phase[derf] == DerfPhase.transforming &&
        common.hp > 0 &&
        deathPhase == DeathPhase.none) {
      // Reactions cannot restart or cut short the awakening strip; death wins.
      animStore.anim[ai] = AnimKey.transform;
      animStore.animFrame[ai] =
          currentTick - world.derfPhase.transformationStartTick[derf];
      return;
    }

    final ancient = world.bossCombat.tryIndexOf(e);
    final active = world.activeAbility.tryIndexOf(e);
    if (ancient != null &&
        active != null &&
        common.hp > 0 &&
        deathPhase == DeathPhase.none &&
        world.activeAbility.abilityId[active] ==
            world.bossCombat.utilityAbility[ancient] &&
        abilities
                .resolve(world.bossCombat.utilityAbility[ancient] ?? '')
                ?.hitDelivery
            is BossTeleportDelivery &&
        world.activeAbility.startTick[active] ==
            world.bossCombat.utilityStartTick[ancient]) {
      final elapsed = currentTick - world.activeAbility.startTick[active];
      final windup = world.activeAbility.windupTicks[active];
      animStore.anim[ai] = elapsed < windup
          ? AnimKey.teleportOut
          : AnimKey.spawn;
      animStore.animFrame[ai] = elapsed < windup ? elapsed : elapsed - windup;
      return;
    }

    // Phase 6: Active Action Layer (Enemies)
    final activeAction = _resolveActiveAction(
      world,
      entity: e,
      currentTick: currentTick,
      stunned: common.stunLocked,
      hp: common.hp,
      deathPhase: deathPhase,
    );

    final signals = AnimSignals.enemy(
      tick: currentTick,
      hp: common.hp,
      deathPhase: deathPhase,
      deathStartTick: deathStartTick,
      grounded: common.grounded,
      velX: common.velX,
      velY: common.velY,
      lastDamageTick: common.lastDamageTick,
      hitAnimTicks:
          world.enemy.has(e) &&
              world.enemy.enemyId[world.enemy.indexOf(e)].isBoss &&
              world.activeAbility.hasActiveAbility(e)
          ? 0
          : hitAnimTicks,
      spawnStartTick: spawnStartTick,
      spawnAnimTicks: spawnAnimTicks,
      stunLocked: common.stunLocked,
      stunStartTick: common.stunStartTick,
      activeActionAnim: activeAction.anim,
      activeActionFrame: activeAction.frame,
    );

    final result = AnimResolver.resolve(profile, signals);
    animStore.anim[ai] =
        derf != null && world.derfPhase.phase[derf] == DerfPhase.caster
        ? switch (result.anim) {
            AnimKey.idle ||
            AnimKey.walk ||
            AnimKey.run ||
            AnimKey.jump ||
            AnimKey.fall => AnimKey.casterIdle,
            AnimKey.hit || AnimKey.stun => AnimKey.casterHit,
            AnimKey.death => AnimKey.casterDeath,
            _ => result.anim,
          }
        : result.anim;
    animStore.animFrame[ai] = usesSurfaceDistance
        ? _terrainLocomotionAnimFrame(
            world,
            entity: e,
            animStateIndex: ai,
            resolved: result,
          )
        : result.animFrame;
  }

  /// Reads shared state used by both player and enemy animation signals.
  ({
    int hp,
    bool grounded,
    double velX,
    double velY,
    int lastDamageTick,
    bool stunLocked,
    int stunStartTick,
  })
  _readCommonSignals(
    EcsWorld world, {
    required EntityId entity,
    required int currentTick,
  }) {
    final hi = world.health.tryIndexOf(entity);
    final hp = hi == null ? 1 : world.health.hp[hi];

    final grounded = WorldSupportView(world).isGrounded(entity);

    final ti = world.transform.tryIndexOf(entity);
    final velX = ti == null ? 0.0 : world.transform.velX[ti];
    final velY = ti == null ? 0.0 : world.transform.velY[ti];

    var lastDamageTick = -1;
    if (world.lastDamage.has(entity)) {
      final lastDamageIndex = world.lastDamage.indexOf(entity);
      if (world.lastDamage.kind[lastDamageIndex] !=
          DeathSourceKind.statusEffect) {
        lastDamageTick = world.lastDamage.tick[lastDamageIndex];
      }
    }

    final stunLocked = world.controlLock.isStunned(entity, currentTick);
    final stunStartTick = world.controlLock.stunStartTickFor(
      entity,
      currentTick,
    );

    return (
      hp: hp,
      grounded: grounded,
      velX: velX,
      velY: velY,
      lastDamageTick: lastDamageTick,
      stunLocked: stunLocked,
      stunStartTick: stunStartTick,
    );
  }

  int _terrainLocomotionAnimFrame(
    EcsWorld world, {
    required EntityId entity,
    required int animStateIndex,
    required AnimResult resolved,
  }) {
    final motionIndex = world.resolvedMotion.tryIndexOf(entity);
    if (motionIndex == null ||
        (resolved.anim != AnimKey.walk && resolved.anim != AnimKey.run)) {
      return resolved.animFrame;
    }
    final travel = world.resolvedMotion.supportedTravelTicks[motionIndex].abs();
    final reference = world
        .resolvedMotion
        .locomotionReferenceSpeedTicksPerSecond[motionIndex];
    if (!_advanceLocomotion || travel <= 0 || reference <= 0) {
      return world.animState.groundedLocomotionPhaseBp[animStateIndex] ~/
          _locomotionPhaseScale;
    }
    final rawRateBp =
        (travel * _tickHz * _locomotionPhaseScale + reference ~/ 2) ~/
        reference;
    final rateBp = rawRateBp.clamp(
      _minimumLocomotionRateBp,
      _maximumLocomotionRateBp,
    );
    world.animState.groundedLocomotionPhaseBp[animStateIndex] += rateBp;
    return world.animState.groundedLocomotionPhaseBp[animStateIndex] ~/
        _locomotionPhaseScale;
  }

  ({AnimKey? anim, int frame}) _resolveActiveAction(
    EcsWorld world, {
    required EntityId entity,
    required int currentTick,
    required bool stunned,
    required int hp,
    required DeathPhase deathPhase,
  }) {
    if (!world.activeAbility.has(entity)) {
      return (anim: null, frame: 0);
    }

    // Pose selection never mutates ability lifecycle, which is owned by
    // ActiveAbilityPhaseSystem and related gameplay systems.
    if (stunned || hp <= 0 || deathPhase != DeathPhase.none) {
      return (anim: null, frame: 0);
    }

    final index = world.activeAbility.indexOf(entity);
    final activeId = world.activeAbility.abilityId[index];
    if (activeId == null || activeId.isEmpty) {
      return (anim: null, frame: 0);
    }

    final def = abilities.resolve(activeId);
    if (def == null) {
      return (anim: null, frame: 0);
    }

    final elapsed = world.activeAbility.elapsedTicks[index];
    final totalTicks = world.activeAbility.totalTicks[index];
    final maxTicks = totalTicks > 0 ? totalTicks : 1;

    if (elapsed >= maxTicks) {
      return (anim: null, frame: 0);
    }

    final actionAnim = _resolveActionAnimKey(
      world,
      entity: entity,
      activeIndex: index,
      activeId: activeId,
      ability: def,
    );

    final delivery = def.hitDelivery;
    var policy =
        CombatPoseCatalog.timingFor(activeId, actionAnim) ??
        (delivery is MeleeHitDelivery ? delivery.profile.timing : null);
    final ei = world.enemy.tryIndexOf(entity);
    final ni = world.npc.tryIndexOf(entity);
    final render = ei != null
        ? enemyCatalog.get(world.enemy.enemyId[ei]).renderAnim
        : ni != null
        ? const NpcCatalog().get(world.npc.npcId[ni]).renderAnim
        : playerRenderAnim;
    final count = render.frameCountsByKey[actionAnim] ?? 1;
    policy ??= ActionFramePolicy(
      frameCount: count,
      activeStart: 0,
      activeEnd: count,
    );
    final step = math.max(
      1,
      ((render.stepTimeSecondsByKey[actionAnim] ?? .1) * _tickHz).round(),
    );
    final pose = policy.frameAt(
      elapsed: elapsed,
      windup: world.activeAbility.windupTicks[index],
      active: world.activeAbility.activeTicks[index],
      recovery: world.activeAbility.recoveryTicks[index],
    );
    // Each firing phase has eight authored running poses on the same sheet.
    final frame = actionAnim == AnimKey.rangedRun
        ? (pose * 8 +
                  playerRangedRunFrame(
                    renderAnim: render,
                    currentTick: currentTick,
                    tickHz: _tickHz,
                  )) *
              step
        : pose * step;
    return (anim: actionAnim, frame: frame);
  }

  AnimKey _resolveActionAnimKey(
    EcsWorld world, {
    required EntityId entity,
    required int activeIndex,
    required AbilityKey activeId,
    required AbilityDef ability,
  }) {
    // Back-strike is a directional variant of melee strike.
    final isPlayer = !world.enemy.has(entity) && !world.npc.has(entity);
    if (isPlayer && ability.animKey == AnimKey.ranged) {
      final ti = world.transform.tryIndexOf(entity);
      return playerRangedAnimKey(
        renderAnim: playerRenderAnim,
        grounded: WorldSupportView(world).isGrounded(entity),
        velocityX: ti == null ? 0 : world.transform.velX[ti],
        minMoveSpeed: _playerProfile.minMoveSpeed,
      );
    }
    if (isPlayer &&
        !playerRenderAnim.sourcesByKey.containsKey(AnimKey.backStrike)) {
      return ability.animKey;
    }
    if (ability.animKey != AnimKey.strike) return ability.animKey;
    if (ability.hitDelivery is! MeleeHitDelivery) return ability.animKey;
    if (!world.movement.has(entity)) return ability.animKey;

    final commitFacing = world.activeAbility.facing[activeIndex];
    final currentFacing = world.movement.facing[world.movement.indexOf(entity)];
    if (commitFacing == currentFacing) return ability.animKey;

    // Pure vertical aim keeps dirX ~ 0 and should stay on regular strike.
    final meleeIndex = world.meleeIntent.tryIndexOf(entity);
    if (meleeIndex != null) {
      final intentAbilityId = world.meleeIntent.abilityId[meleeIndex];
      if (intentAbilityId == activeId &&
          world.meleeIntent.dirX[meleeIndex].abs() <= 1e-6) {
        return ability.animKey;
      }
    }

    return AnimKey.backStrike;
  }

  static const int _locomotionPhaseScale = 10000;
  static const int _minimumLocomotionRateBp = 7500;
  static const int _maximumLocomotionRateBp = 15000;
}
