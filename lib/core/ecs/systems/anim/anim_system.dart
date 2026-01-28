import '../../../anim/anim_resolver.dart';
import '../../../abilities/ability_catalog.dart';
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
  }) : _tickHz = tickHz,
       _playerMovement = playerMovement,
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
         directionalStrike: true,
       ) {
    _buildHitAnimTicksById(tickHz);
  }

  /// Catalog for per-enemy configuration (hit windows, anim profiles).
  final EnemyCatalog enemyCatalog;

  final int _tickHz;
  final MovementTuningDerived _playerMovement;
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
  void step(EcsWorld world, {required EntityId player, required int currentTick}) {
    _stepPlayer(world, player: player, currentTick: currentTick);
    _stepEnemies(world, currentTick: currentTick);
  }

  void _stepPlayer(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    if (player < 0) return;
    if (!world.animState.has(player)) return;
    if (!world.transform.has(player) || !world.movement.has(player)) return;

    final ai = world.animState.indexOf(player);
    final ti = world.transform.indexOf(player);
    final mi = world.movement.indexOf(player);

    final hi = world.health.tryIndexOf(player);
    final hp = hi == null ? 1 : world.health.hp[hi];

    final grounded = world.collision.has(player)
        ? world.collision.grounded[world.collision.indexOf(player)]
        : false;

    final facing = world.movement.facing[mi];
    const lastMeleeTick = -1;
    final lastMeleeFacing = facing;
    const lastCastTick = -1;
    const lastRangedTick = -1;

    final lastDamageTick = world.lastDamage.has(player)
        ? world.lastDamage.tick[world.lastDamage.indexOf(player)]
        : -1;
    
    final stunLocked = world.controlLock.isStunned(player, currentTick);
    
    // Phase 6: Active Action Layer
    final activeAction = _resolveActiveAction(
      world,
      entity: player,
      currentTick: currentTick,
      stunned: stunLocked,
      hp: hp,
      deathPhase: DeathPhase.none,
    );

    final signals = AnimSignals.player(
      tick: currentTick,
      hp: hp,
      grounded: grounded,
      velX: world.transform.velX[ti],
      velY: world.transform.velY[ti],
      lastDamageTick: lastDamageTick,
      hitAnimTicks: _playerAnimTuning.hitAnimTicks,
      lastStrikeTick: lastMeleeTick,
      strikeAnimTicks: _playerAnimTuning.strikeAnimTicks,
      backStrikeAnimTicks: _playerAnimTuning.backStrikeAnimTicks,
      lastStrikeFacing: lastMeleeFacing,
      lastCastTick: lastCastTick,
      castAnimTicks: _playerAnimTuning.castAnimTicks,
      lastRangedTick: lastRangedTick,
      rangedAnimTicks: _playerAnimTuning.rangedAnimTicks,
      dashTicksLeft: 0,
      dashDurationTicks: 0,
      spawnAnimTicks: _playerAnimTuning.spawnAnimTicks,
      stunLocked: stunLocked,
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

      final hp = world.health.has(e)
          ? world.health.hp[world.health.indexOf(e)]
          : 1;

      final grounded = world.collision.has(e)
          ? world.collision.grounded[world.collision.indexOf(e)]
          : false;

      final di = world.deathState.tryIndexOf(e);
      final deathPhase = di == null ? DeathPhase.none : world.deathState.phase[di];
      final deathStartTick = di == null ? -1 : world.deathState.deathStartTick[di];

      final lastDamageTick = world.lastDamage.has(e)
          ? world.lastDamage.tick[world.lastDamage.indexOf(e)]
          : -1;

      final hitAnimTicks = _hitAnimTicksById[enemyId] ?? 0;
      const lastMeleeTick = -1;
      const lastMeleeAnimTicks = 0;
      const lastMeleeFacing = Facing.right;

      final ti = world.transform.tryIndexOf(e);
      final velX = ti == null ? 0.0 : world.transform.velX[ti];
      final velY = ti == null ? 0.0 : world.transform.velY[ti];

      final stunLocked = world.controlLock.isStunned(e, currentTick);

      // Phase 6: Active Action Layer (Enemies)
      final activeAction = _resolveActiveAction(
        world,
        entity: e,
        currentTick: currentTick,
        stunned: stunLocked,
        hp: hp,
        deathPhase: deathPhase,
      );

      final signals = AnimSignals.enemy(
        tick: currentTick,
        hp: hp,
        deathPhase: deathPhase,
        deathStartTick: deathStartTick,
        grounded: grounded,
        velX: velX,
        velY: velY,
        lastDamageTick: lastDamageTick,
        hitAnimTicks: hitAnimTicks,
        lastStrikeTick: lastMeleeTick,
        strikeAnimTicks: lastMeleeAnimTicks,
        lastStrikeFacing: lastMeleeFacing,
        stunLocked: stunLocked,
        activeActionAnim: activeAction.anim,
        activeActionFrame: activeAction.frame,
      );

      final result = AnimResolver.resolve(profile, signals);
      animStore.anim[ai] = result.anim;
      animStore.animFrame[ai] = result.animFrame;
    }
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

    if (stunned || hp <= 0 || deathPhase != DeathPhase.none) {
      world.activeAbility.clear(entity);
      return (anim: null, frame: 0);
    }

    final index = world.activeAbility.indexOf(entity);
    final activeId = world.activeAbility.abilityId[index];
    if (activeId == null || activeId.isEmpty) {
      world.activeAbility.clear(entity);
      return (anim: null, frame: 0);
    }

    final def = AbilityCatalog.tryGet(activeId);
    if (def == null) {
      world.activeAbility.clear(entity);
      return (anim: null, frame: 0);
    }

    final elapsed = world.activeAbility.elapsedTicks[index];
    final totalTicks = world.activeAbility.totalTicks[index];
    final maxTicks = totalTicks > 0 ? totalTicks : 1;

    if (elapsed >= maxTicks) {
      world.activeAbility.clear(entity);
      return (anim: null, frame: 0);
    }

    return (anim: def.animKey, frame: elapsed < 0 ? 0 : elapsed);
  }
}
