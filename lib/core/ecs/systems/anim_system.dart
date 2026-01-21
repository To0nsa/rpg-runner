import '../../anim/anim_resolver.dart';
import '../../enemies/death_behavior.dart';
import '../../enemies/enemy_catalog.dart';
import '../../enemies/enemy_id.dart';
import '../../players/player_tuning.dart';
import '../../util/tick_math.dart';
import '../entity_id.dart';
import '../world.dart';

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
  }) : _playerMovement = playerMovement,
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
         directionalAttack: true,
       ) {
    _buildHitAnimTicksById(tickHz);
  }

  /// Catalog for per-enemy configuration (hit windows, anim profiles).
  final EnemyCatalog enemyCatalog;

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
    final hp = hi == null ? 1.0 : world.health.hp[hi];

    final grounded = world.collision.has(player)
        ? world.collision.grounded[world.collision.indexOf(player)]
        : false;

    final actionIndex = world.actionAnim.tryIndexOf(player);
    final facing = world.movement.facing[mi];
    final lastMeleeTick = actionIndex == null
        ? -1
        : world.actionAnim.lastMeleeTick[actionIndex];
    final lastMeleeFacing = actionIndex == null
        ? facing
        : world.actionAnim.lastMeleeFacing[actionIndex];
    final lastCastTick = actionIndex == null
        ? -1
        : world.actionAnim.lastCastTick[actionIndex];
    final lastRangedTick = actionIndex == null
        ? -1
        : world.actionAnim.lastRangedTick[actionIndex];

    final lastDamageTick = world.lastDamage.has(player)
        ? world.lastDamage.tick[world.lastDamage.indexOf(player)]
        : -1;

    final signals = AnimSignals.player(
      tick: currentTick,
      hp: hp,
      grounded: grounded,
      velX: world.transform.velX[ti],
      velY: world.transform.velY[ti],
      lastDamageTick: lastDamageTick,
      hitAnimTicks: _playerAnimTuning.hitAnimTicks,
      lastAttackTick: lastMeleeTick,
      attackAnimTicks: _playerAnimTuning.attackAnimTicks,
      attackBackAnimTicks: _playerAnimTuning.attackBackAnimTicks,
      lastAttackFacing: lastMeleeFacing,
      lastCastTick: lastCastTick,
      castAnimTicks: _playerAnimTuning.castAnimTicks,
      lastRangedTick: lastRangedTick,
      rangedAnimTicks: _playerAnimTuning.rangedAnimTicks,
      dashTicksLeft: world.movement.dashTicksLeft[mi],
      dashDurationTicks: _playerMovement.dashDurationTicks,
      spawnAnimTicks: _playerAnimTuning.spawnAnimTicks,
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
          : 1.0;

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
      final lastMeleeTick = enemies.lastMeleeTick[ei];
      final lastMeleeAnimTicks = enemies.lastMeleeAnimTicks[ei];
      final lastMeleeFacing = enemies.lastMeleeFacing[ei];

      final ti = world.transform.tryIndexOf(e);
      final velX = ti == null ? 0.0 : world.transform.velX[ti];
      final velY = ti == null ? 0.0 : world.transform.velY[ti];

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
        lastAttackTick: lastMeleeTick,
        attackAnimTicks: lastMeleeAnimTicks,
        lastAttackFacing: lastMeleeFacing,
      );

      final result = AnimResolver.resolve(profile, signals);
      animStore.anim[ai] = result.anim;
      animStore.animFrame[ai] = result.animFrame;
    }
  }
}
