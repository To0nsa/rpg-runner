import '../../../anim/anim_resolver.dart';
import '../../../abilities/ability_catalog.dart';
import '../../../abilities/ability_def.dart';
import '../../../snapshots/enums.dart';
import '../../../enemies/death_behavior.dart';
import '../../../enemies/enemy_catalog.dart';
import '../../../enemies/enemy_id.dart';
import '../../../players/player_tuning.dart';
import '../../../util/tick_math.dart';
import '../../entity_id.dart';
import '../../world.dart';

/// System that computes per-entity animation state each tick.
///
/// Uses [AnimResolver] with per-entity [AnimProfile]s to pick the animation key
/// and frame offset deterministically.
class AnimSystem {
  AnimSystem({
    required int tickHz,
    required this.enemyCatalog,
    required MovementTuningDerived playerMovement,
    required AnimTuningDerived playerAnimTuning,
    this.abilities = AbilityCatalog.shared,
  }) : _playerAnimTuning = playerAnimTuning,
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
         directionalStrike: true,
       ) {
    _buildHitAnimTicksById(tickHz);
  }

  /// Catalog for per-enemy configuration (hit windows, anim profiles).
  final EnemyCatalog enemyCatalog;
  final AbilityResolver abilities;

  final AnimTuningDerived _playerAnimTuning;
  final AnimProfile _playerProfile;

  /// Pre-computed hit animation durations in ticks per enemy type.
  late final Map<EnemyId, int> _hitAnimTicksById;

  void _buildHitAnimTicksById(int tickHz) {
    _hitAnimTicksById = <EnemyId, int>{};
    for (final id in EnemyId.values) {
      final seconds = enemyCatalog.get(id).hitAnimSeconds;
      _hitAnimTicksById[id] = ticksFromSecondsCeil(seconds, tickHz);
    }
  }

  /// Updates animation state for player and enemies.
  ///
  /// Call this once per tick before [SnapshotBuilder.build].
  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
    DeathPhase playerDeathPhase = DeathPhase.none,
    int playerDeathStartTick = -1,
    int playerSpawnStartTick = 0,
  }) {
    _stepPlayer(
      world,
      player: player,
      currentTick: currentTick,
      deathPhase: playerDeathPhase,
      deathStartTick: playerDeathStartTick,
      spawnStartTick: playerSpawnStartTick,
    );
    _stepEnemies(world, currentTick: currentTick);
  }

  void _stepPlayer(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
    required DeathPhase deathPhase,
    required int deathStartTick,
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

    final result = AnimResolver.resolve(_playerProfile, signals);
    world.animState.anim[ai] = result.anim;
    world.animState.animFrame[ai] = result.animFrame;
  }

  void _stepEnemies(EcsWorld world, {required int currentTick}) {
    final enemies = world.enemy;
    final animStore = world.animState;

    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final e = enemies.denseEntities[ei];
      if (!animStore.has(e)) continue;
      final ai = animStore.indexOf(e);
      final enemyId = enemies.enemyId[ei];
      final profile = enemyCatalog.get(enemyId).animProfile;
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

      final hitAnimTicks = _hitAnimTicksById[enemyId] ?? 0;

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
        hitAnimTicks: hitAnimTicks,
        stunLocked: common.stunLocked,
        stunStartTick: common.stunStartTick,
        activeActionAnim: activeAction.anim,
        activeActionFrame: activeAction.frame,
      );

      final result = AnimResolver.resolve(profile, signals);
      animStore.anim[ai] = result.anim;
      animStore.animFrame[ai] = result.animFrame;
    }
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

    final grounded = world.collision.has(entity)
        ? world.collision.grounded[world.collision.indexOf(entity)]
        : false;

    final ti = world.transform.tryIndexOf(entity);
    final velX = ti == null ? 0.0 : world.transform.velX[ti];
    final velY = ti == null ? 0.0 : world.transform.velY[ti];

    final lastDamageTick = world.lastDamage.has(entity)
        ? world.lastDamage.tick[world.lastDamage.indexOf(entity)]
        : -1;

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

    // AnimSystem is render-only: gameplay lifecycle is owned by
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

    return (anim: actionAnim, frame: elapsed < 0 ? 0 : elapsed);
  }

  AnimKey _resolveActionAnimKey(
    EcsWorld world, {
    required EntityId entity,
    required int activeIndex,
    required AbilityKey activeId,
    required AbilityDef ability,
  }) {
    // Back-strike is a directional variant of melee strike.
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
}
