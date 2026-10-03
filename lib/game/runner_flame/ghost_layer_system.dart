import 'dart:async';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:run_protocol/replay_blob.dart';

import '../components/camera_space_snapped_sprite_animation.dart';
import '../components/player/player_animations.dart';
import '../components/player/player_view.dart';
import '../components/enemies/enemy_render_registry.dart';
import '../components/npcs/npc_render_registry.dart';
import '../components/projectiles/projectile_render_registry.dart';
import '../components/spell_impacts/spell_impact_render_registry.dart';
import '../components/sprite_anim/deterministic_anim_view.dart';
import '../components/sprite_anim/sprite_anim_set.dart';
import '../game_controller.dart';
import '../replay/ghost_render_frame.dart';
import '../tuning/combat_feedback_tuning.dart';
import '../util/math_util.dart' as math;
import 'render_constants.dart';

/// Render-only ghost replay layer synchronization and transient FX buffering.
class GhostLayerSystem {
  GhostLayerSystem({
    required this.controller,
    required this.world,
    required this.images,
    required EnemyRenderRegistry enemyRenderRegistry,
    required NpcRenderRegistry npcRenderRegistry,
    required ProjectileRenderRegistry projectileRenderRegistry,
    required SpellImpactRenderRegistry spellImpactRenderRegistry,
    required this.combatFeedbackTuning,
    required this.ghostRenderListenable,
  }) : _enemyRenderRegistry = enemyRenderRegistry,
       _npcRenderRegistry = npcRenderRegistry,
       _projectileRenderRegistry = projectileRenderRegistry,
       _spellImpactRenderRegistry = spellImpactRenderRegistry;

  final GameController controller;
  final Component world;
  final Images images;
  final CombatFeedbackTuning combatFeedbackTuning;
  final ValueListenable<GhostRenderFrame?>? ghostRenderListenable;

  final EnemyRenderRegistry _enemyRenderRegistry;
  final NpcRenderRegistry _npcRenderRegistry;
  final ProjectileRenderRegistry _projectileRenderRegistry;
  final SpellImpactRenderRegistry _spellImpactRenderRegistry;

  final Map<int, DeterministicAnimView> _ghostActors =
      <int, DeterministicAnimView>{};
  final Map<int, DeterministicAnimView> _ghostProjectiles =
      <int, DeterministicAnimView>{};
  final Map<int, int> _ghostProjectileSpawnTicks = <int, int>{};
  final Map<int, EntityRenderSnapshot> _prevGhostEntitiesById =
      <int, EntityRenderSnapshot>{};
  final List<ProjectileHitEvent> _pendingGhostProjectileHitEvents =
      <ProjectileHitEvent>[];
  final List<SpellImpactEvent> _pendingGhostSpellImpactEvents =
      <SpellImpactEvent>[];
  final List<EntityVisualCueEvent> _pendingGhostEntityVisualCueEvents =
      <EntityVisualCueEvent>[];
  final Set<int> _seenIdsScratch = <int>{};
  final List<int> _toRemoveScratch = <int>[];
  final Vector2 _snapScratch = Vector2.zero();

  DeterministicAnimView? _ghostPlayer;
  int? _ghostPlayerEntityId;
  GameStateSnapshot? _ghostPrevSnapshot;
  GameStateSnapshot? _ghostSnapshot;
  ReplayBlobV1? _ghostReplayBlob;
  SpriteAnimSet? _ghostPlayerAnimSet;
  String? _ghostPlayerAnimCharacterId;
  int _animationLoadGeneration = 0;
  GhostRenderFrame? _lastFrame;
  bool _ghostLayerDisabled = false;
  String? _ghostLayerDisableReason;

  void attachListeners() {
    ghostRenderListenable?.addListener(_onGhostRenderFeedChanged);
    _onGhostRenderFeedChanged();
  }

  void detachListeners() {
    ghostRenderListenable?.removeListener(_onGhostRenderFeedChanged);
    _animationLoadGeneration += 1;
  }

  void _onGhostRenderFeedChanged() {
    final frame = ghostRenderListenable?.value;
    if (identical(frame, _lastFrame)) return;
    _lastFrame = frame;
    if (frame == null) {
      _animationLoadGeneration += 1;
      _ghostReplayBlob = null;
      _ghostSnapshot = null;
      _ghostPrevSnapshot = null;
      _ghostPlayerAnimSet = null;
      _ghostPlayerAnimCharacterId = null;
      _ghostLayerDisabled = false;
      _ghostLayerDisableReason = null;
      _clearGhostViews();
      return;
    }

    final replayBlob = frame.replayBlob;
    if (!identical(replayBlob, _ghostReplayBlob)) {
      _clearGhostViews();
      _ghostReplayBlob = replayBlob;
      _ghostLayerDisabled = false;
      _ghostLayerDisableReason = null;
      final generation = ++_animationLoadGeneration;
      if (replayBlob.playerCharacterId != _ghostPlayerAnimCharacterId) {
        _ghostPlayerAnimSet = null;
        unawaited(_loadGhostPlayerAnimations(replayBlob, generation));
      }
    }
    _ghostPrevSnapshot = frame.previous;
    _ghostSnapshot = frame.current;
    for (final event in frame.events) {
      if (event is ProjectileHitEvent) {
        _pendingGhostProjectileHitEvents.add(event);
      } else if (event is SpellImpactEvent) {
        _pendingGhostSpellImpactEvents.add(event);
      } else if (event is EntityVisualCueEvent) {
        _pendingGhostEntityVisualCueEvents.add(event);
      }
    }
  }

  Future<void> _loadGhostPlayerAnimations(
    ReplayBlobV1 replayBlob,
    int generation,
  ) async {
    try {
      final characterId = _enumByName(
        PlayerCharacterId.values,
        replayBlob.playerCharacterId,
        fieldName: 'ghostReplayBlob.playerCharacterId',
      );
      final character = PlayerCharacterRegistry.resolve(characterId);
      final animationSet = await loadPlayerAnimations(
        images,
        renderAnim: character.renderAnim,
      );
      if (generation != _animationLoadGeneration) return;
      _ghostPlayerAnimSet = animationSet;
      _ghostPlayerAnimCharacterId = replayBlob.playerCharacterId;
    } catch (error) {
      if (generation != _animationLoadGeneration) return;
      disableLayer('ghost-player-animation-load-failed', details: '$error');
    }
  }

  void disableLayer(String reasonCode, {String? details}) {
    _ghostLayerDisabled = true;
    _ghostLayerDisableReason = reasonCode;
    _clearGhostViews();
    final replayRunSessionId = _ghostReplayBlob?.runSessionId;
    final replayBoardId = _ghostReplayBlob?.boardId;
    debugPrint(
      'Ghost layer disabled: reason=$reasonCode '
      'runId=${controller.snapshot.runId} '
      'tick=${controller.snapshot.tick} '
      'replayRunSessionId=${replayRunSessionId ?? 'n/a'} '
      'replayBoardId=${replayBoardId ?? 'n/a'} '
      '${details == null ? '' : 'details=$details'}',
    );
  }

  void clearViews() {
    _clearGhostViews();
  }

  void _clearGhostViews() {
    _ghostPlayerEntityId = null;
    _ghostPlayer?.removeFromParent();
    _ghostPlayer = null;
    for (final view in _ghostActors.values) {
      view.removeFromParent();
    }
    _ghostActors.clear();
    for (final view in _ghostProjectiles.values) {
      view.removeFromParent();
    }
    _ghostProjectiles.clear();
    _ghostProjectileSpawnTicks.clear();
    _prevGhostEntitiesById.clear();
    _pendingGhostProjectileHitEvents.clear();
    _pendingGhostSpellImpactEvents.clear();
    _pendingGhostEntityVisualCueEvents.clear();
  }

  void syncLayer({required double alpha, required Vector2 cameraCenter}) {
    if (_ghostLayerDisabled) {
      _clearGhostViews();
      return;
    }
    final snapshot = _ghostSnapshot;
    final replayBlob = _ghostReplayBlob;
    final playerAnimSet = _ghostPlayerAnimSet;
    if (snapshot == null || replayBlob == null || playerAnimSet == null) {
      _clearGhostViews();
      return;
    }

    _prevGhostEntitiesById.clear();
    final prevGhostSnapshot = _ghostPrevSnapshot;
    if (prevGhostSnapshot != null) {
      for (final entity in prevGhostSnapshot.entities) {
        _prevGhostEntitiesById[entity.id] = entity;
      }
    }

    _syncGhostPlayer(
      entities: snapshot.entities,
      prevById: _prevGhostEntitiesById,
      alpha: alpha,
      cameraCenter: cameraCenter,
      playerAnimSet: playerAnimSet,
    );
    _syncGhostActors(
      entities: snapshot.entities,
      prevById: _prevGhostEntitiesById,
      alpha: alpha,
      cameraCenter: cameraCenter,
    );
    _syncGhostProjectiles(
      entities: snapshot.entities,
      prevById: _prevGhostEntitiesById,
      alpha: alpha,
      cameraCenter: cameraCenter,
      tick: snapshot.tick,
    );
  }

  void _syncGhostPlayer({
    required List<EntityRenderSnapshot> entities,
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
    required SpriteAnimSet playerAnimSet,
  }) {
    EntityRenderSnapshot? playerEntity;
    for (final entity in entities) {
      if (entity.kind == EntityKind.player) {
        playerEntity = entity;
        break;
      }
    }

    if (playerEntity == null) {
      _ghostPlayerEntityId = null;
      _ghostPlayer?.removeFromParent();
      _ghostPlayer = null;
      return;
    }

    var playerView = _ghostPlayer;
    if (playerView == null) {
      playerView =
          PlayerView(
              animationSet: playerAnimSet,
              renderScale: Vector2.all(runnerPlayerRenderTuning.scale),
              feedbackTuning: combatFeedbackTuning,
            )
            ..priority = priorityGhostEntities
            ..setVisualStyle(RenderVisualStyle.ghost);
      _ghostPlayer = playerView;
      world.add(playerView);
    }

    final prev = prevById[playerEntity.id] ?? playerEntity;
    final worldX = math.lerpDouble(prev.pos.x, playerEntity.pos.x, alpha);
    final worldY = math.lerpDouble(prev.pos.y, playerEntity.pos.y, alpha);
    _snapScratch.setValues(
      math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
      math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
    );
    playerView.applySnapshot(
      playerEntity,
      tickHz: controller.tickHz,
      pos: _snapScratch,
    );
    playerView.setStatusVisualMask(playerEntity.statusVisualMask);
    _ghostPlayerEntityId = playerEntity.id;
  }

  void _syncGhostActors({
    required List<EntityRenderSnapshot> entities,
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    final seen = _seenIdsScratch..clear();
    for (final entity in entities) {
      if (entity.kind != EntityKind.enemy && entity.kind != EntityKind.npc) {
        continue;
      }
      final entry = entity.kind == EntityKind.npc
          ? (entity.npcId == null
                ? null
                : _npcRenderRegistry.entryFor(entity.npcId!))
          : (entity.enemyId == null
                ? null
                : _enemyRenderRegistry.entryFor(entity.enemyId!));
      if (entry == null) {
        _ghostActors.remove(entity.id)?.removeFromParent();
        continue;
      }

      seen.add(entity.id);
      var view = _ghostActors[entity.id];
      if (view == null) {
        view = entry.createView()
          ..priority = priorityGhostEntities
          ..setFeedbackTuning(combatFeedbackTuning)
          ..setVisualStyle(RenderVisualStyle.ghost);
        _ghostActors[entity.id] = view;
        world.add(view);
      }

      final prev = prevById[entity.id] ?? entity;
      final worldX = math.lerpDouble(prev.pos.x, entity.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, entity.pos.y, alpha);
      _snapScratch.setValues(
        math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
      );
      view.applySnapshot(entity, tickHz: controller.tickHz, pos: _snapScratch);
      view.setStatusVisualMask(entity.statusVisualMask);
    }

    if (_ghostActors.isEmpty) {
      return;
    }
    final toRemove = _toRemoveScratch..clear();
    for (final id in _ghostActors.keys) {
      if (!seen.contains(id)) {
        toRemove.add(id);
      }
    }
    for (final id in toRemove) {
      _ghostActors.remove(id)?.removeFromParent();
    }
  }

  void _syncGhostProjectiles({
    required List<EntityRenderSnapshot> entities,
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
    required int tick,
  }) {
    final seen = _seenIdsScratch..clear();
    for (final entity in entities) {
      if (entity.kind != EntityKind.projectile) {
        continue;
      }
      seen.add(entity.id);

      final entry = entity.projectileId == null
          ? null
          : _projectileRenderRegistry.entryFor(entity.projectileId!);
      if (entry == null) {
        _ghostProjectiles.remove(entity.id)?.removeFromParent();
        _ghostProjectileSpawnTicks.remove(entity.id);
        continue;
      }

      var view = _ghostProjectiles[entity.id];
      if (view == null) {
        view = entry.viewFactory(entry.animSet, entry.renderScale)
          ..priority = priorityGhostEntities
          ..setVisualStyle(RenderVisualStyle.ghost);
        _ghostProjectiles[entity.id] = view;
        _ghostProjectileSpawnTicks[entity.id] = tick;
        world.add(view);
      }

      final prev = prevById[entity.id] ?? entity;
      final worldX = math.lerpDouble(prev.pos.x, entity.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, entity.pos.y, alpha);
      _snapScratch.setValues(
        math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
      );

      final spawnTick = _ghostProjectileSpawnTicks[entity.id] ?? tick;
      final startTicks = entry.spawnAnimTicks(controller.tickHz);
      final ageTicks = tick - spawnTick;
      final animOverride =
          startTicks > 0 && ageTicks >= 0 && ageTicks < startTicks
          ? AnimKey.spawn
          : AnimKey.idle;
      final overrideAnimFrame = animOverride == AnimKey.spawn ? ageTicks : null;

      view.applySnapshot(
        entity,
        tickHz: controller.tickHz,
        pos: _snapScratch,
        overrideAnim: animOverride,
        overrideAnimFrame: overrideAnimFrame,
      );
      view.setStatusVisualMask(entity.statusVisualMask);

      final spinSpeed = entry.spinSpeedRadPerSecond;
      if (spinSpeed == 0.0) {
        view.angle = entity.rotationRad;
      } else {
        final spinSeconds = (ageTicks.toDouble() + alpha) / controller.tickHz;
        view.angle = entity.rotationRad + spinSpeed * spinSeconds;
      }
    }

    if (_ghostProjectiles.isEmpty) {
      return;
    }
    final toRemove = _toRemoveScratch..clear();
    for (final id in _ghostProjectiles.keys) {
      if (!seen.contains(id)) {
        toRemove.add(id);
      }
    }
    for (final id in toRemove) {
      _ghostProjectiles.remove(id)?.removeFromParent();
      _ghostProjectileSpawnTicks.remove(id);
    }
  }

  void flushPendingEntityVisualCueEvents() {
    if (_pendingGhostEntityVisualCueEvents.isEmpty) {
      return;
    }

    for (final event in _pendingGhostEntityVisualCueEvents) {
      final intensity01 = _visualCueIntensity01(event.intensityBp);
      if (intensity01 <= 0.0) {
        continue;
      }

      final DeterministicAnimView? view;
      if (_ghostPlayerEntityId != null &&
          event.entityId == _ghostPlayerEntityId) {
        view = _ghostPlayer;
      } else {
        view =
            _ghostActors[event.entityId] ?? _ghostProjectiles[event.entityId];
      }
      if (view == null) {
        continue;
      }

      switch (event.kind) {
        case EntityVisualCueKind.directHit:
          view.triggerDirectHitFlash(intensity01: intensity01);
        case EntityVisualCueKind.dotPulse:
          view.triggerDotPulse(
            color: combatFeedbackTuning.dotColorFor(event.damageType),
            intensity01: intensity01,
          );
        case EntityVisualCueKind.resourcePulse:
          view.triggerResourcePulse(
            color: combatFeedbackTuning.resourceColorFor(event.resourceType),
            intensity01: intensity01,
          );
      }
    }

    _pendingGhostEntityVisualCueEvents.clear();
  }

  void flushPendingProjectileHitEvents({required Vector2 cameraCenter}) {
    if (_pendingGhostProjectileHitEvents.isEmpty) {
      return;
    }

    for (final event in _pendingGhostProjectileHitEvents) {
      final entry = _projectileRenderRegistry.entryFor(event.projectileId);
      if (entry == null) {
        continue;
      }

      final hitAnim = entry.animSet.animations[AnimKey.hit];
      if (hitAnim == null) {
        continue;
      }

      final component = CameraSpaceSnappedSpriteAnimation(
        animation: hitAnim,
        size: entry.animSet.frameSize.clone(),
        worldPosX: event.pos.x,
        worldPosY: event.pos.y,
        anchor: entry.animSet.anchorFor(AnimKey.hit),
        paint: Paint()..filterQuality = FilterQuality.none,
        removeOnFinish: true,
      )..priority = priorityGhostEntities;

      component.scale.setValues(entry.renderScale.x, entry.renderScale.y);
      component.angle = event.rotationRad;
      component.snapToCamera(cameraCenter);
      world.add(component);
    }

    _pendingGhostProjectileHitEvents.clear();
  }

  void flushPendingSpellImpactEvents({required Vector2 cameraCenter}) {
    if (_pendingGhostSpellImpactEvents.isEmpty) {
      return;
    }

    for (final event in _pendingGhostSpellImpactEvents) {
      final entry = _spellImpactRenderRegistry.entryFor(event.impactId);
      if (entry == null) {
        continue;
      }

      final hitAnim = entry.animSet.animations[AnimKey.hit];
      if (hitAnim == null) {
        continue;
      }

      final component = CameraSpaceSnappedSpriteAnimation(
        animation: hitAnim,
        size: entry.animSet.frameSize.clone(),
        worldPosX: event.pos.x,
        worldPosY: event.pos.y,
        anchor: entry.animSet.anchorFor(AnimKey.hit),
        paint: Paint()..filterQuality = FilterQuality.none,
        removeOnFinish: true,
      )..priority = priorityGhostEntities;

      component.scale.setValues(entry.renderScale.x, entry.renderScale.y);
      component.snapToCamera(cameraCenter);
      world.add(component);
    }

    _pendingGhostSpellImpactEvents.clear();
  }

  bool get debugGhostLayerDisabled => _ghostLayerDisabled;

  String? get debugGhostLayerDisableReason => _ghostLayerDisableReason;

  bool get debugHasGhostPlayerView => _ghostPlayer != null;

  int? get debugGhostPlayerEntityId => _ghostPlayerEntityId;

  int get debugGhostEnemyCount =>
      _ghostSnapshot?.entities
          .where(
            (e) => e.kind == EntityKind.enemy && _ghostActors.containsKey(e.id),
          )
          .length ??
      0;
  int get debugGhostNpcCount =>
      _ghostSnapshot?.entities
          .where(
            (e) => e.kind == EntityKind.npc && _ghostActors.containsKey(e.id),
          )
          .length ??
      0;

  int get debugGhostProjectileCount => _ghostProjectiles.length;

  void debugSetGhostRenderStateForTest({
    GameStateSnapshot? snapshot,
    GameStateSnapshot? prevSnapshot,
    ReplayBlobV1? replayBlob,
    SpriteAnimSet? playerAnimSet,
    List<GameEvent>? events,
  }) {
    _ghostSnapshot = snapshot;
    _ghostPrevSnapshot = prevSnapshot;
    _ghostReplayBlob = replayBlob;
    _ghostPlayerAnimSet = playerAnimSet;
    _pendingGhostProjectileHitEvents.clear();
    _pendingGhostSpellImpactEvents.clear();
    _pendingGhostEntityVisualCueEvents.clear();
    if (events != null && events.isNotEmpty) {
      for (final event in events) {
        if (event is ProjectileHitEvent) {
          _pendingGhostProjectileHitEvents.add(event);
          continue;
        }
        if (event is SpellImpactEvent) {
          _pendingGhostSpellImpactEvents.add(event);
          continue;
        }
        if (event is EntityVisualCueEvent) {
          _pendingGhostEntityVisualCueEvents.add(event);
        }
      }
    }
  }

  double _visualCueIntensity01(int intensityBp) {
    if (intensityBp <= 0) {
      return 0.0;
    }
    return (intensityBp / visualCueIntensityScaleBp).clamp(0.0, 1.0);
  }
}

T _enumByName<T extends Enum>(
  List<T> values,
  String raw, {
  required String fieldName,
}) {
  for (final value in values) {
    if (value.name == raw) {
      return value;
    }
  }
  throw ArgumentError.value(raw, fieldName, 'Unsupported enum value.');
}
