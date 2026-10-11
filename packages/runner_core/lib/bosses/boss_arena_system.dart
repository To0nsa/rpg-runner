import '../camera/autoscroll_camera.dart';
import '../collision/terrain/terrain_motion_request.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../combat/control_lock.dart';
import '../ecs/entity_id.dart';
import '../ecs/collider_aabb_utils.dart';
import '../ecs/systems/ability_interrupt.dart';
import '../ecs/stores/hitbox_store.dart';
import '../ecs/world.dart';
import '../enemies/enemy_catalog.dart';
import '../enemies/death_behavior.dart';
import '../snapshots/boss_arena_snapshot.dart';
import '../snapshots/enums.dart';
import '../track/track_streamer.dart';
import '../track/chunk_pattern_tier.dart';
import '../tuning/utils/anim_tuning.dart';
import 'boss_resource_supply_system.dart';

/// Mandatory arena ownership, independent of ambient spawns and NPC rescues.
/// Entry stops horizontal travel; camera framing precedes the boss introduction.
/// Entrance and release use catalog ticks while the held player can fall.
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

  /// Supply is exposed only for the current combat occurrence, independently
  /// of the boss's attack phases. Resolve fatal outcomes before consuming it.
  BossResourceSupplyEncounter? get resourceSupplyEncounter {
    final arena = _current;
    if (arena == null ||
        arena.phase != BossArenaPhase.combat ||
        arena.boss == null) {
      return null;
    }
    final definition = const EnemyCatalog()
        .get(arena.chunk.bossArena!.enemyId)
        .resourceSupply;
    if (definition == null) return null;
    return BossResourceSupplyEncounter(
      occurrence: arena.chunk.index,
      boss: arena.boss!,
      minX: arena.minX,
      maxX: arena.maxX,
      definition: definition,
    );
  }

  bool retainsChunk(int index) => _arenas[index]?.retained ?? false;
  bool retainsActor(EcsWorld world, EntityId entity) =>
      _current != null && _belongs(world, entity, _current!);

  bool _belongs(EcsWorld world, EntityId entity, _Arena arena) {
    if (entity == arena.boss) return true;
    final si = world.bossSummon.tryIndexOf(entity);
    return si != null &&
        arena.boss != null &&
        world.bossSummon.owner[si] == arena.boss;
  }

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
  /// [onVictoryReady] receives the occurrence and its captured authored tier
  /// after the verified death-strip deadline; the caller owns player eligibility.
  void prepare(
    EcsWorld world, {
    required EntityId player,
    required int tick,
    required EntityId? Function(ActiveTrackChunkSnapshot chunk, int tick) spawn,
    void Function(int occurrence, ChunkPatternTier tier)? onVictoryReady,
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
      if (arena.deathAnimationEndTick >= 0 &&
          tick >= arena.deathAnimationEndTick) {
        onVictoryReady?.call(arena.chunk.index, arena.chunk.tier);
      }
      _release(world, player);
      arena.retained = false;
      _current = null;
    }
    if (arena.phase == BossArenaPhase.defeated &&
        _isRequiredBoss(world, arena)) {
      final di = world.deathState.tryIndexOf(arena.boss!);
      if (di != null && world.deathState.phase[di] == DeathPhase.deathAnim) {
        arena.deathAnimationEndTick = world.deathState.despawnTick[di];
      }
    }
  }

  /// Refresh short locks after timer maintenance and before every AI/action gate.
  /// Entry bounds stop the player's capsule one-quarter into the chunk; reaching
  /// that stop holds actions and horizontal motion while allowing falling.
  void control(EcsWorld world, {required EntityId player, required int tick}) {
    final arena = _current;
    if (arena == null) return;
    final min = arena.framed ? arena.minX : arena.chunk.startX - 600;
    final entering =
        arena.phase == BossArenaPhase.approaching ||
        arena.phase == BossArenaPhase.introduction;
    var playerMin = physicsCoordinateToTicks(min);
    var playerMax = physicsCoordinateToTicks(arena.maxX);
    if (entering) {
      _updatePlayerStop(world, player, arena);
      final radius = world
          .worldContactCapsule
          .radiusTicks[world.worldContactCapsule.indexOf(player)];
      playerMax = arena.playerStopXTicks! + radius;
      if (arena.playerStopped) {
        playerMin = arena.playerStopXTicks! - radius;
        _holdPlayer(world, player, tick);
      }
    }
    world.actorMotionBounds.add(
      player,
      TerrainHorizontalBounds(minXTicks: playerMin, maxXTicks: playerMax),
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
      if (_belongs(world, entity, arena)) {
        world.actorMotionBounds.add(
          entity,
          TerrainHorizontalBounds(
            minXTicks: physicsCoordinateToTicks(arena.minX),
            maxXTicks: physicsCoordinateToTicks(arena.maxX),
          ),
          freeze: arena.phase == BossArenaPhase.introduction,
        );
        continue;
      }
      world.arenaSuspension.addEntity(entity);
      _hold(world, entity, tick);
    }
    if (arena.phase == BossArenaPhase.introduction) {
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

  /// Latches the entry stop after motion; introduction waits for full framing.
  void afterCamera(
    EcsWorld world, {
    required EntityId player,
    required CameraState camera,
    required int tick,
  }) {
    final arena = _current;
    if (arena == null) return;
    arena.cameraStopped = camera.centerX == arena.cameraCenterX;
    if (arena.phase == BossArenaPhase.approaching) {
      _updatePlayerStop(world, player, arena);
      if (arena.cameraStopped && arena.playerStopped) {
        arena.framed = true;
        arena.phase = BossArenaPhase.introduction;
        _clearCombatArtifacts(world);
      }
      if (arena.playerStopped) {
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
      final preserveSpells = const EnemyCatalog()
          .get(arena.chunk.bossArena!.enemyId)
          .preserveReleasedSpellsOnDefeat;
      _clearCombatArtifacts(
        world,
        preserveReleasedBy: preserveSpells ? boss : null,
      );
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
      enemyId: arena.chunk.bossArena!.enemyId,
      phase: arena.phase,
      entrance: arena.phase == BossArenaPhase.introduction && arena.boss != null
          ? BossEntranceSnapshot(
              startTick: arena.introductionStartTick,
              durationTicks: arena.introductionTicks,
            )
          : null,
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
      if ((owner != player && !_belongs(world, owner, arena)) ||
          x < arena.minX ||
          x > arena.maxX) {
        world.destroyEntity(e);
      }
    }
    for (final e in world.hitbox.denseEntities.toList()) {
      final owner = world.hitbox.owner[world.hitbox.indexOf(e)];
      if (owner != player && !_belongs(world, owner, arena)) {
        world.destroyEntity(e);
      }
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
    world.invulnerability.protect(ii, 2);
  }

  void _updatePlayerStop(EcsWorld world, EntityId player, _Arena arena) {
    final ci = world.worldContactCapsule.indexOf(player);
    final radius = world.worldContactCapsule.radiusTicks[ci];
    final center =
        physicsCoordinateToTicks(
          world.transform.posX[world.transform.indexOf(player)],
        ) +
        world.worldContactCapsule.offsetXTicks[ci] *
            colliderFacingSign(world, player);
    // Keep the complete capsule inside authored bounds. A run/playtest starting
    // beyond the mark holds where it starts instead of teleporting backward.
    arena.playerStopXTicks ??= physicsCoordinateToTicks(arena.playerStopX)
        .clamp(
          physicsCoordinateToTicks(arena.minX) + radius,
          physicsCoordinateToTicks(arena.maxX) - radius,
        )
        .clamp(center, physicsCoordinateToTicks(arena.maxX) - radius);
    if (center >= arena.playerStopXTicks!) arena.playerStopped = true;
  }

  void _holdPlayer(EcsWorld world, EntityId player, int tick) {
    _hold(world, player, tick);
    final mi = world.movement.tryIndexOf(player);
    if (mi != null) world.movement.dashTicksLeft[mi] = 0;
    world.gravityControl.removeEntity(player);
    world.knockback.removeEntity(player);
    final ti = world.transform.indexOf(player);
    if (world.transform.velY[ti] < 0) world.transform.velY[ti] = 0;
  }

  void _releaseTemporaryProtection(EcsWorld world) {
    for (final entity in world.arenaProtection.denseEntities.toList()) {
      world.invulnerability.removeEntity(entity);
      world.arenaProtection.removeEntity(entity);
    }
  }

  void _release(EcsWorld world, EntityId player) {
    for (final summon in world.bossSummon.denseEntities.toList()) {
      if (_current != null && _belongs(world, summon, _current!)) {
        world.destroyEntity(summon);
      }
    }
    for (final entity in world.arenaSuspension.denseEntities.toList()) {
      world.arenaSuspension.removeEntity(entity);
    }
    world.actorMotionBounds.removeEntity(player);
    if (_current?.boss != null) {
      world.actorMotionBounds.removeEntity(_current!.boss!);
    }
    _releaseTemporaryProtection(world);
  }

  void _clearCombatArtifacts(EcsWorld world, {EntityId? preserveReleasedBy}) {
    for (final entity in [
      ...world.projectile.denseEntities,
      ...world.hitbox.denseEntities,
    ]) {
      if (preserveReleasedBy != null) {
        final pi = world.projectile.tryIndexOf(entity);
        if (pi != null && world.projectile.owner[pi] == preserveReleasedBy) {
          continue;
        }
        final hi = world.hitbox.tryIndexOf(entity);
        if (hi != null &&
            world.hitbox.owner[hi] == preserveReleasedBy &&
            world.hitbox.attachment[hi] == HitboxAttachment.worldAnchor) {
          continue;
        }
      }
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
  int? playerStopXTicks;
  bool playerStopped = false;
  EntityId? boss;
  int introductionStartTick = -1;
  int introductionTicks = 0;
  int deathAnimationEndTick = -1;
  double get cameraCenterX => (chunk.startX + chunk.endX) / 2;
  // One-quarter of chunk width leaves space for the boss entrance on the right.
  double get playerStopX => chunk.startX + (chunk.endX - chunk.startX) * 0.25;
  double get minX => chunk.startX + chunk.bossArena!.minX;
  double get maxX => chunk.startX + chunk.bossArena!.maxX;
}
