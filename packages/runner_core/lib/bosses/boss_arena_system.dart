import '../camera/autoscroll_camera.dart';
import '../collision/terrain/terrain_motion_request.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../combat/control_lock.dart';
import '../ecs/entity_id.dart';
import '../ecs/collider_aabb_utils.dart';
import '../ecs/systems/ability_interrupt.dart';
import '../ecs/world.dart';
import '../enemies/enemy_catalog.dart';
import '../snapshots/boss_arena_snapshot.dart';
import '../snapshots/enums.dart';
import '../track/track_streamer.dart';
import '../tuning/utils/anim_tuning.dart';

/// Mandatory arena ownership, independent of ambient spawns and NPC rescues.
/// Camera framing precedes the hold; entrance and release use catalog ticks.
final class BossArenaSystem {
  BossArenaSystem({required this.tickHz});
  final int tickHz;
  final Map<int, _Arena> _arenas = {};
  _Arena? _current;
  int _retiredThrough = -1;
  int _lastScoreTick = -1;
  int excludedScoreTicks = 0;

  double? get cameraStopX => _current?.cameraCenterX;
  bool get failed => _current?.phase == BossArenaPhase.failed;
  bool get arenaFramed => _current?.framed ?? false;
  bool retainsChunk(int index) => _arenas[index]?.retained ?? false;
  bool retainsActor(EntityId entity) => _current?.boss == entity;

  /// Registration is driven by exact streamed occurrences, never source IDs alone.
  void synchronize(List<ActiveTrackChunkSnapshot> chunks, double cameraRight) {
    final live = chunks.map((c) => c.index).toSet();
    for (final index in _arenas.keys.toList()) {
      if (!live.contains(index) && !_arenas[index]!.retained) {
        _arenas.remove(index);
        if (index > _retiredThrough) _retiredThrough = index;
      }
    }
    for (final chunk in chunks) {
      if (chunk.bossArena != null && chunk.index > _retiredThrough) {
        _arenas.putIfAbsent(chunk.index, () => _Arena(chunk));
      }
    }
    if (_current == null) {
      final candidates =
          _arenas.values
              .where((a) => a.retained && cameraRight >= a.chunk.startX)
              .toList()
            ..sort((a, b) => a.chunk.index.compareTo(b.chunk.index));
      if (candidates.isNotEmpty) _current = candidates.first;
    }
  }

  /// Spawn before motion preparation, after the full arena was framed last tick.
  void prepare(
    EcsWorld world, {
    required EntityId player,
    required int tick,
    required EntityId? Function(ActiveTrackChunkSnapshot chunk, int tick) spawn,
  }) {
    final arena = _current;
    if (arena == null) return;
    if (arena.phase == BossArenaPhase.introduction && arena.boss == null) {
      final def = arena.chunk.bossArena!;
      arena.boss = spawn(arena.chunk, tick);
      if (arena.boss == null) {
        arena.phase = BossArenaPhase.failed;
        return;
      }
      arena.introductionStartTick = tick;
      final art = const EnemyCatalog().get(def.enemyId).renderAnim;
      arena.introductionTicks = ticksForKey(
        key: AnimKey.spawn,
        frameCounts: art.frameCountsByKey,
        stepTimeSecondsByKey: art.stepTimeSecondsByKey,
        tickHz: tickHz,
      );
      world.spawnState.set(
        entity: arena.boss!,
        startTickValue: tick,
        animTicksValue: arena.introductionTicks,
      );
      _clearCombatArtifacts(world);
    }
    if (arena.phase == BossArenaPhase.introduction &&
        arena.boss != null &&
        tick - arena.introductionStartTick >= arena.introductionTicks) {
      arena.phase = BossArenaPhase.combat;
      _releaseTemporaryProtection(world);
      AbilityInterrupt.clearActiveAndTransient(
        world,
        entity: player,
        startDeferredCooldown: false,
      );
    }
    if (arena.phase == BossArenaPhase.defeated &&
        !_isRequiredBoss(world, arena)) {
      _release(world, player);
      arena.retained = false;
      _current = null;
    }
  }

  /// Refresh short locks after timer maintenance and before every AI/action gate.
  void control(EcsWorld world, {required EntityId player, required int tick}) {
    final arena = _current;
    if (arena == null) return;
    final min = arena.framed ? arena.minX : arena.chunk.startX - 600;
    world.actorMotionBounds.add(
      player,
      TerrainHorizontalBounds(
        minXTicks: physicsCoordinateToTicks(min),
        maxXTicks: physicsCoordinateToTicks(arena.maxX),
      ),
      freeze: arena.phase == BossArenaPhase.introduction,
    );
    if (arena.boss != null && world.isEntityAlive(arena.boss!)) {
      world.actorMotionBounds.add(
        arena.boss!,
        TerrainHorizontalBounds(
          minXTicks: physicsCoordinateToTicks(arena.minX),
          maxXTicks: physicsCoordinateToTicks(arena.maxX),
        ),
        freeze: arena.phase == BossArenaPhase.introduction,
      );
    }
    if (!arena.framed) return;
    for (final entity in [
      ...world.enemy.denseEntities,
      ...world.npc.denseEntities,
    ]) {
      if (entity == arena.boss) continue;
      world.arenaSuspension.addEntity(entity);
      _hold(world, entity, tick);
    }
    if (arena.phase == BossArenaPhase.introduction) {
      _hold(world, player, tick);
      if (arena.boss != null) _hold(world, arena.boss!, tick);
    } else if (arena.phase == BossArenaPhase.combat) {
      // Ordinary actors stay protected, while the required boss is vulnerable.
      if (arena.boss != null && world.arenaProtection.has(arena.boss!)) {
        world.arenaProtection.removeEntity(arena.boss!);
        world.invulnerability.removeEntity(arena.boss!);
      }
    }
    protectCombat(world, player);
  }

  /// Called after camera motion. The first held snapshot shows the whole arena.
  void afterCamera(
    EcsWorld world, {
    required EntityId player,
    required CameraState camera,
    required int tick,
  }) {
    final arena = _current;
    if (arena == null) return;
    arena.cameraStopped = camera.centerX == arena.cameraCenterX;
    if (arena.phase == BossArenaPhase.approaching && arena.cameraStopped) {
      final ti = world.transform.indexOf(player);
      final ci = world.colliderAabb.indexOf(player);
      if (colliderCenterX(
                world,
                entity: player,
                transformIndex: ti,
                colliderIndex: ci,
              ) -
              world.colliderAabb.halfX[ci] >=
          arena.minX) {
        arena.framed = true;
        arena.phase = BossArenaPhase.introduction;
        _clearCombatArtifacts(world);
        control(world, player: player, tick: tick);
      }
    }
    countScoreTick(tick);
  }

  /// Terminal player loss takes precedence over same-tick boss defeat.
  void resolve(EcsWorld world, {required bool playerDead}) {
    final arena = _current;
    if (arena == null || arena.boss == null) return;
    if (playerDead) {
      arena.phase = BossArenaPhase.failed;
      return;
    }
    final boss = arena.boss!;
    if (!_isRequiredBoss(world, arena)) {
      if (arena.phase != BossArenaPhase.defeated) {
        arena.phase = BossArenaPhase.failed;
      }
      return;
    }
    if (arena.phase == BossArenaPhase.combat &&
        world.health.hp[world.health.indexOf(boss)] <= 0) {
      arena.phase = BossArenaPhase.defeated;
      AbilityInterrupt.clearActiveAndTransient(
        world,
        entity: boss,
        startDeferredCooldown: false,
      );
      _clearCombatArtifacts(world);
    }
  }

  void countScoreTick(int tick) {
    if (_current?.cameraStopped == true && _lastScoreTick != tick) {
      excludedScoreTicks++;
      _lastScoreTick = tick;
    }
  }

  BossArenaSnapshot? snapshot(EcsWorld world) {
    final arena = _current;
    if (arena == null || !arena.framed) return null;
    final hi = arena.boss == null ? null : world.health.tryIndexOf(arena.boss!);
    final health = const EnemyCatalog()
        .get(arena.chunk.bossArena!.enemyId)
        .health;
    return BossArenaSnapshot(
      id: arena.chunk.bossArena!.id,
      phase: arena.phase,
      minX: arena.minX,
      maxX: arena.maxX,
      hp100: arena.phase == BossArenaPhase.defeated
          ? 0
          : hi == null
          ? health.hp
          : world.health.hp[hi],
      hpMax100: health.hpMax,
    );
  }

  void endRun(EcsWorld world, EntityId player) {
    _release(world, player);
    _current = null;
    _arenas.clear();
  }

  bool _isRequiredBoss(EcsWorld world, _Arena arena) {
    final ei = arena.boss == null ? null : world.enemy.tryIndexOf(arena.boss!);
    return ei != null &&
        world.enemy.enemyId[ei] == arena.chunk.bossArena!.enemyId;
  }

  void protectCombat(EcsWorld world, EntityId player) {
    final arena = _current;
    if (arena == null || !arena.framed) return;
    for (final e in world.projectile.denseEntities.toList()) {
      final pi = world.projectile.indexOf(e);
      final ti = world.transform.indexOf(e);
      final owner = world.projectile.owner[pi];
      final x = world.transform.posX[ti];
      if ((owner != player && owner != arena.boss) ||
          x < arena.minX ||
          x > arena.maxX) {
        world.destroyEntity(e);
      }
    }
    for (final e in world.hitbox.denseEntities.toList()) {
      final owner = world.hitbox.owner[world.hitbox.indexOf(e)];
      if (owner != player && owner != arena.boss) world.destroyEntity(e);
    }
  }

  void _hold(EcsWorld world, EntityId entity, int tick) {
    world.controlLock.addLock(entity, LockFlag.allExceptStun, 1, tick);
    AbilityInterrupt.clearActiveAndTransient(
      world,
      entity: entity,
      startDeferredCooldown: true,
    );
    world.abilityCharge.resetProgress(entity, currentTick: tick);
    final ti = world.transform.tryIndexOf(entity);
    if (ti != null) world.transform.velX[ti] = 0;
    if (!world.invulnerability.has(entity)) {
      world.invulnerability.add(entity);
      world.arenaProtection.addEntity(entity);
    }
    final ii = world.invulnerability.indexOf(entity);
    if (world.invulnerability.ticksLeft[ii] < 2) {
      world.invulnerability.ticksLeft[ii] = 2;
    }
  }

  void _releaseTemporaryProtection(EcsWorld world) {
    for (final entity in world.arenaProtection.denseEntities.toList()) {
      world.invulnerability.removeEntity(entity);
      world.arenaProtection.removeEntity(entity);
    }
  }

  void _release(EcsWorld world, EntityId player) {
    for (final entity in world.arenaSuspension.denseEntities.toList()) {
      world.arenaSuspension.removeEntity(entity);
    }
    world.actorMotionBounds.removeEntity(player);
    if (_current?.boss != null) {
      world.actorMotionBounds.removeEntity(_current!.boss!);
    }
    _releaseTemporaryProtection(world);
  }

  void _clearCombatArtifacts(EcsWorld world) {
    for (final entity in [
      ...world.projectile.denseEntities,
      ...world.hitbox.denseEntities,
    ]) {
      world.destroyEntity(entity);
    }
  }
}

final class _Arena {
  _Arena(this.chunk);
  final ActiveTrackChunkSnapshot chunk;
  BossArenaPhase phase = BossArenaPhase.approaching;
  bool retained = true;
  bool framed = false;
  bool cameraStopped = false;
  EntityId? boss;
  int introductionStartTick = -1;
  int introductionTicks = 0;
  double get cameraCenterX => (chunk.startX + chunk.endX) / 2;
  double get minX => chunk.startX + chunk.bossArena!.minX;
  double get maxX => chunk.startX + chunk.bossArena!.maxX;
}
