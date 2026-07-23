import '../../enemies/death_behavior.dart';
import '../../enemies/enemy_catalog.dart';
import '../../enemies/enemy_id.dart';
import '../../snapshots/enums.dart';
import '../../tuning/utils/anim_tuning.dart' as anim_utils;
import '../../util/tick_math.dart';
import '../stores/death_state_store.dart';
import '../world.dart';
import '../world_support_view.dart';

/// Tracks enemy death phases and schedules despawn timing.
class EnemyDeathStateSystem {
  EnemyDeathStateSystem({
    required int tickHz,
    EnemyCatalog enemyCatalog = const EnemyCatalog(),
    double maxFallSeconds = 3.0,
  }) : _enemyCatalog = enemyCatalog,
       _maxFallTicks = ticksFromSecondsCeil(maxFallSeconds, tickHz) {
    _buildDeathAnimTicksById(tickHz);
  }

  final EnemyCatalog _enemyCatalog;
  final int _maxFallTicks;

  late final Map<EnemyId, int> _deathAnimTicksById;

  void _buildDeathAnimTicksById(int tickHz) {
    _deathAnimTicksById = <EnemyId, int>{};
    for (final id in EnemyId.values) {
      final archetype = _enemyCatalog.get(id);
      final renderAnim = archetype.renderAnim;
      _deathAnimTicksById[id] =
          renderAnim.frameCountsByKey.containsKey(AnimKey.death) &&
              renderAnim.stepTimeSecondsByKey.containsKey(AnimKey.death)
          ? anim_utils.ticksForKey(
              key: AnimKey.death,
              frameCounts: renderAnim.frameCountsByKey,
              stepTimeSecondsByKey: renderAnim.stepTimeSecondsByKey,
              tickHz: tickHz,
            )
          : ticksFromSecondsCeil(archetype.deathAnimSeconds, tickHz);
    }
  }

  void step(
    EcsWorld world, {
    required int currentTick,
    List<EnemyId>? outEnemiesKilled,
  }) {
    final enemies = world.enemy;
    if (enemies.denseEntities.isEmpty) return;

    final health = world.health;
    final deathState = world.deathState;
    final transform = world.transform;
    final supportView = WorldSupportView(world);

    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final e = enemies.denseEntities[ei];
      final di = deathState.tryIndexOf(e);
      if (di != null) {
        final phase = deathState.phase[di];
        if (phase != DeathPhase.fallingUntilGround) continue;

        final grounded = supportView.isGrounded(e);
        final maxFallTick = deathState.maxFallDespawnTick[di];
        final shouldStartDeathAnim =
            grounded || (maxFallTick >= 0 && currentTick >= maxFallTick);

        if (!shouldStartDeathAnim) continue;

        final deathTicks = _deathAnimTicksById[enemies.enemyId[ei]] ?? 0;
        deathState.phase[di] = DeathPhase.deathAnim;
        deathState.deathStartTick[di] = currentTick;
        deathState.despawnTick[di] = currentTick + deathTicks;

        final ti = transform.tryIndexOf(e);
        if (ti != null) {
          transform.velX[ti] = 0.0;
          transform.velY[ti] = 0.0;
        }
        continue;
      }

      final hi = health.tryIndexOf(e);
      if (hi == null) continue;
      if (health.hp[hi] > 0) continue;

      final archetype = _enemyCatalog.get(enemies.enemyId[ei]);
      final deathTicks = _deathAnimTicksById[enemies.enemyId[ei]] ?? 0;

      if (outEnemiesKilled != null) {
        outEnemiesKilled.add(enemies.enemyId[ei]);
      }

      final grounded = supportView.isGrounded(e);

      if (archetype.deathBehavior == DeathBehavior.groundImpactThenDeath &&
          !grounded) {
        deathState.add(
          e,
          DeathStateDef(
            phase: DeathPhase.fallingUntilGround,
            deathStartTick: -1,
            despawnTick: -1,
            maxFallDespawnTick: currentTick + _maxFallTicks,
          ),
        );
        continue;
      }

      deathState.add(
        e,
        DeathStateDef(
          phase: DeathPhase.deathAnim,
          deathStartTick: currentTick,
          despawnTick: currentTick + deathTicks,
        ),
      );

      final ti = transform.tryIndexOf(e);
      if (ti != null) {
        transform.velX[ti] = 0.0;
        transform.velY[ti] = 0.0;
      }
    }
  }
}
