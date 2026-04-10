import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:runner_core/contracts/render_contract.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:run_protocol/replay_blob.dart';

import 'components/aim_ray.dart';
import 'components/ground_band_parallax_foreground.dart';
import 'components/ground_surface.dart';
import 'components/pixel_parallax_backdrop.dart';
import 'components/player/player_animations.dart';
import 'components/sprite_anim/sprite_anim_set.dart';
import 'components/enemies/enemy_render_registry.dart';
import 'components/pickups/pickup_render_registry.dart';
import 'components/projectiles/projectile_render_registry.dart';
import 'components/spell_impacts/spell_impact_render_registry.dart';
import 'components/temporary_floor_mask.dart';
import 'debug/debug_aabb_overlay.dart';
import 'debug/render_debug_flags.dart';
import 'game_controller.dart';
import 'input/aim_preview.dart';
import 'input/runner_input_router.dart';
import 'runner_flame/camera_shake_controller.dart';
import 'runner_flame/event_feedback_system.dart';
import 'runner_flame/ghost_layer_system.dart';
import 'runner_flame/live_world_sync_system.dart';
import 'runner_flame/load_state.dart';
import 'runner_flame/render_constants.dart';
import 'spatial/world_view_transform.dart';
import 'themes/parallax_theme_registry.dart';
import 'tuning/combat_feedback_tuning.dart';
import 'util/math_util.dart' as math;

export 'runner_flame/load_state.dart';

/// Snapshot-driven Flame scene coordinator for a run.
///
/// Simulation truth remains in [GameController]/Core; this class wires
/// render-only systems (live views, ghost layer, and transient FX).
class RunnerFlameGame extends FlameGame {
  RunnerFlameGame({
    required this.controller,
    required this.input,
    required this.projectileAimPreview,
    required this.meleeAimPreview,
    required this.playerCharacter,
    this.ghostSnapshotListenable,
    this.ghostEventsListenable,
    this.ghostReplayBlobListenable,
    CombatFeedbackTuning combatFeedbackTuning = const CombatFeedbackTuning(),
  }) : _enemyRenderRegistry = EnemyRenderRegistry(
         enemyCatalog: controller.enemyCatalog,
       ),
       _combatFeedbackTuning = combatFeedbackTuning,
       _projectileRenderRegistry = ProjectileRenderRegistry(),
       _spellImpactRenderRegistry = SpellImpactRenderRegistry(),
       _pickupRenderRegistry = PickupRenderRegistry(),
       super(
         camera: CameraComponent.withFixedResolution(
           width: virtualWidth.toDouble(),
           height: virtualHeight.toDouble(),
         ),
       ) {
    _liveWorldSync = LiveWorldSyncSystem(
      controller: controller,
      world: world,
      playerCharacter: playerCharacter,
      enemyRenderRegistry: _enemyRenderRegistry,
      projectileRenderRegistry: _projectileRenderRegistry,
      pickupRenderRegistry: _pickupRenderRegistry,
      combatFeedbackTuning: _combatFeedbackTuning,
    );
    _eventFeedback = RunEventFeedbackSystem(
      world: world,
      projectileRenderRegistry: _projectileRenderRegistry,
      spellImpactRenderRegistry: _spellImpactRenderRegistry,
      combatFeedbackTuning: _combatFeedbackTuning,
      cameraShakeController: _cameraShake,
    );
    _ghostLayer = GhostLayerSystem(
      controller: controller,
      world: world,
      images: images,
      enemyRenderRegistry: _enemyRenderRegistry,
      projectileRenderRegistry: _projectileRenderRegistry,
      spellImpactRenderRegistry: _spellImpactRenderRegistry,
      combatFeedbackTuning: _combatFeedbackTuning,
      ghostSnapshotListenable: ghostSnapshotListenable,
      ghostEventsListenable: ghostEventsListenable,
      ghostReplayBlobListenable: ghostReplayBlobListenable,
    );
  }

  /// Bridge/controller that owns the simulation and produces snapshots.
  final GameController controller;

  /// Input scheduler/aggregator (touch + keyboard + mouse).
  final RunnerInputRouter input;

  /// UI-driven aim preview (render-only).
  final ValueListenable<AimPreviewState> projectileAimPreview;
  final ValueListenable<AimPreviewState> meleeAimPreview;
  final ValueListenable<GameStateSnapshot?>? ghostSnapshotListenable;
  final ValueListenable<List<GameEvent>>? ghostEventsListenable;
  final ValueListenable<ReplayBlobV1?>? ghostReplayBlobListenable;

  /// The selected player character definition for this run (render-only usage).
  final PlayerCharacterDefinition playerCharacter;

  /// UI-facing load progress for the run route.
  final ValueNotifier<RunLoadState> loadState = ValueNotifier<RunLoadState>(
    RunLoadState.initial,
  );

  final EnemyRenderRegistry _enemyRenderRegistry;
  final ProjectileRenderRegistry _projectileRenderRegistry;
  final SpellImpactRenderRegistry _spellImpactRenderRegistry;
  final PickupRenderRegistry _pickupRenderRegistry;
  final CombatFeedbackTuning _combatFeedbackTuning;

  late final LiveWorldSyncSystem _liveWorldSync;
  late final RunEventFeedbackSystem _eventFeedback;
  late final GhostLayerSystem _ghostLayer;

  final Map<int, EntityRenderSnapshot> _prevEntitiesById =
      <int, EntityRenderSnapshot>{};

  final CameraShakeController _cameraShake = CameraShakeController();
  final Vector2 _cameraBaseCenterScratch = Vector2.zero();
  final Vector2 _cameraShakeOffsetScratch = Vector2.zero();
  final Vector2 _cameraCenterScratch = Vector2.zero();

  late final GroundSurface _groundSurface;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _ghostLayer.attachListeners();

    assert(() {
      playerCharacter.assertValid();
      return true;
    }());
    controller.addEventListener(_eventFeedback.handleGameEvent);

    final theme = ParallaxThemeRegistry.forThemeId(controller.snapshot.themeId);
    _setLoadState(RunLoadPhase.themeResolved, 0.15);

    camera.backdrop.add(
      PixelParallaxBackdrop(
        virtualWidth: virtualWidth,
        virtualHeight: virtualHeight,
        snapScrollToPixels: false,
        layers: theme.backgroundLayers,
        layerBottomAnchorYProvider: _parallaxLayerBottomAnchorY,
      )..priority = priorityBackgroundParallax,
    );

    camera.backdrop.add(
      TemporaryFloorMask(
        controller: controller,
        virtualWidth: virtualWidth,
        virtualHeight: virtualHeight,
      )..priority = priorityTemporaryFloorMask,
    );

    _groundSurface = GroundSurface(
      assetPath: theme.groundLayerAsset,
      controller: controller,
      virtualWidth: virtualWidth,
      virtualHeight: virtualHeight,
    )..priority = priorityGroundTiles;
    camera.backdrop.add(_groundSurface);

    camera.backdrop.add(
      GroundBandParallaxForeground(
        controller: controller,
        virtualWidth: virtualWidth,
        virtualHeight: virtualHeight,
        layers: theme.foregroundLayers,
        bandFillDepthProvider: () => _groundSurface.materialHeight,
        snapScrollToPixels: false,
      )..priority = priorityForegroundParallax,
    );
    _setLoadState(RunLoadPhase.parallaxMounted, 0.35);

    final playerAnimations = await loadPlayerAnimations(
      images,
      renderAnim: playerCharacter.renderAnim,
    );
    _setLoadState(RunLoadPhase.playerAnimationsLoaded, 0.55);

    await Future.wait<void>(<Future<void>>[
      _enemyRenderRegistry.load(images),
      _projectileRenderRegistry.load(images),
      _spellImpactRenderRegistry.load(images),
      _pickupRenderRegistry.load(images),
    ]);
    _setLoadState(RunLoadPhase.registriesLoaded, 0.8);

    _liveWorldSync.mountPlayer(playerAnimations);

    world.add(
      AimRay(
        controller: controller,
        preview: projectileAimPreview,
        length: projectileAimRayLength,
        playerRenderPos: () => _liveWorldSync.playerView.position,
        drawWhenNoAim: false,
      )..priority = priorityProjectileAimRay,
    );

    world.add(
      AimRay(
        controller: controller,
        preview: meleeAimPreview,
        length: meleeAimRayLength,
        playerRenderPos: () => _liveWorldSync.playerView.position,
        drawWhenNoAim: false,
        paint: Paint()
          ..color = const Color(0xFFDC4440)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      )..priority = priorityMeleeAimRay,
    );

    _liveWorldSync.mountStaticSolids(controller.snapshot.staticSolids);
    _liveWorldSync.mountStaticPrefabSprites(
      controller.snapshot.staticPrefabSprites,
    );
    _setLoadState(RunLoadPhase.worldReady, 1.0);
  }

  @override
  void update(double dt) {
    final snapshot = controller.snapshot;
    if (!snapshot.paused && !snapshot.gameOver) {
      input.pumpHeldInputs();
    }

    // Keep this ordering: Flame components read camera during their own update,
    // so Core stepping + camera/view sync must happen before super.update(dt).
    controller.advanceFrame(dt);

    final prevSnapshot = controller.prevSnapshot;
    final currSnapshot = controller.snapshot;
    final alpha = controller.alpha;

    _prevEntitiesById.clear();
    for (final entity in prevSnapshot.entities) {
      _prevEntitiesById[entity.id] = entity;
    }

    _cameraBaseCenterScratch.setValues(
      math.lerpDouble(
        prevSnapshot.camera.centerX,
        currSnapshot.camera.centerX,
        alpha,
      ),
      math.lerpDouble(
        prevSnapshot.camera.centerY,
        currSnapshot.camera.centerY,
        alpha,
      ),
    );
    _cameraShake.sample(dt, _cameraShakeOffsetScratch);
    _cameraCenterScratch.setValues(
      _cameraBaseCenterScratch.x + _cameraShakeOffsetScratch.x,
      _cameraBaseCenterScratch.y + _cameraShakeOffsetScratch.y,
    );
    camera.viewfinder.position = _cameraCenterScratch;

    _liveWorldSync.syncStaticSolids(currSnapshot.staticSolids);
    _liveWorldSync.snapStaticSolids(
      currSnapshot.staticSolids,
      cameraCenter: _cameraCenterScratch,
      virtualWidth: virtualWidth,
      virtualHeight: virtualHeight,
    );
    _liveWorldSync.syncStaticPrefabSprites(currSnapshot.staticPrefabSprites);
    _liveWorldSync.snapStaticPrefabSprites(
      currSnapshot.staticPrefabSprites,
      cameraCenter: _cameraCenterScratch,
      virtualWidth: virtualWidth,
      virtualHeight: virtualHeight,
    );

    final player = currSnapshot.playerEntity;
    _liveWorldSync.syncPlayer(
      player: player,
      prevById: _prevEntitiesById,
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
    );

    _liveWorldSync.syncEnemies(
      currSnapshot.entities,
      prevById: _prevEntitiesById,
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
    );
    _eventFeedback.flushEntityVisualCueEvents(
      playerEntityId: player?.id,
      playerView: _liveWorldSync.playerView,
      enemyViews: _liveWorldSync.enemyViews,
    );

    _liveWorldSync.syncProjectiles(
      currSnapshot.entities,
      prevById: _prevEntitiesById,
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
      tick: currSnapshot.tick,
    );
    _liveWorldSync.syncCollectibles(
      currSnapshot.entities,
      prevById: _prevEntitiesById,
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
    );

    _eventFeedback.flushSpellImpactEvents(
      cameraCenter: _cameraCenterScratch,
      priority: priorityProjectiles,
    );

    _ghostLayer.syncLayer(alpha: alpha, cameraCenter: _cameraCenterScratch);
    _ghostLayer.flushPendingEntityVisualCueEvents();
    _ghostLayer.flushPendingProjectileHitEvents(
      cameraCenter: _cameraCenterScratch,
    );
    _ghostLayer.flushPendingSpellImpactEvents(
      cameraCenter: _cameraCenterScratch,
    );

    final drawHitboxes =
        RenderDebugFlags.canUseRenderDebug &&
        RenderDebugFlags.drawActorHitboxes;
    if (drawHitboxes) {
      _liveWorldSync.syncTriggerHitboxes(
        currSnapshot.entities,
        prevById: _prevEntitiesById,
        alpha: alpha,
        cameraCenter: _cameraCenterScratch,
      );
    } else {
      _liveWorldSync.clearTriggerHitboxes();
    }

    syncDebugAabbOverlays(
      entities: currSnapshot.entities,
      enabled: drawHitboxes,
      parent: world,
      pool: _liveWorldSync.actorHitboxes,
      priority: priorityActorHitboxes,
      paint: _liveWorldSync.actorHitboxPaint,
      include: (entity) =>
          entity.kind == EntityKind.player || entity.kind == EntityKind.enemy,
      prevById: _prevEntitiesById,
      offsetXFor: (entity) {
        switch (entity.kind) {
          case EntityKind.player:
            final authoredOffsetX = playerCharacter.catalog.colliderOffsetX;
            final artFacing = playerCharacter.catalog.facing;
            return entity.facing == artFacing
                ? authoredOffsetX
                : -authoredOffsetX;
          case EntityKind.enemy:
            final enemyId = entity.enemyId;
            if (enemyId == null) {
              return 0.0;
            }
            final authoredOffsetX = controller.enemyCatalog
                .get(enemyId)
                .collider
                .offsetX;
            final artFacing = entity.artFacingDir ?? entity.facing;
            return entity.facing == artFacing
                ? authoredOffsetX
                : -authoredOffsetX;
          default:
            return 0.0;
        }
      },
      offsetYFor: (entity) {
        switch (entity.kind) {
          case EntityKind.player:
            return playerCharacter.catalog.colliderOffsetY;
          case EntityKind.enemy:
            final enemyId = entity.enemyId;
            if (enemyId == null) {
              return 0.0;
            }
            return controller.enemyCatalog.get(enemyId).collider.offsetY;
          default:
            return 0.0;
        }
      },
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
    );

    _eventFeedback.flushProjectileHitEvents(
      cameraCenter: _cameraCenterScratch,
      priority: priorityProjectiles,
    );

    super.update(dt);
  }

  @override
  void onRemove() {
    _ghostLayer.detachListeners();
    _ghostLayer.clearViews();
    controller.removeEventListener(_eventFeedback.handleGameEvent);
    images.clearCache();
    super.onRemove();
  }

  @override
  void onDispose() {
    loadState.dispose();
    super.onDispose();
  }

  void _setLoadState(RunLoadPhase phase, double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    loadState.value = RunLoadState(phase: phase, progress: clamped);
  }

  @visibleForTesting
  bool get debugGhostLayerDisabled => _ghostLayer.debugGhostLayerDisabled;

  @visibleForTesting
  String? get debugGhostLayerDisableReason =>
      _ghostLayer.debugGhostLayerDisableReason;

  @visibleForTesting
  bool get debugHasGhostPlayerView => _ghostLayer.debugHasGhostPlayerView;

  @visibleForTesting
  int? get debugGhostPlayerEntityId => _ghostLayer.debugGhostPlayerEntityId;

  @visibleForTesting
  int get debugGhostEnemyCount => _ghostLayer.debugGhostEnemyCount;

  @visibleForTesting
  int get debugGhostProjectileCount => _ghostLayer.debugGhostProjectileCount;

  @visibleForTesting
  void debugSetGhostRenderStateForTest({
    GameStateSnapshot? snapshot,
    GameStateSnapshot? prevSnapshot,
    ReplayBlobV1? replayBlob,
    SpriteAnimSet? playerAnimSet,
    List<GameEvent>? events,
  }) {
    _ghostLayer.debugSetGhostRenderStateForTest(
      snapshot: snapshot,
      prevSnapshot: prevSnapshot,
      replayBlob: replayBlob,
      playerAnimSet: playerAnimSet,
      events: events,
    );
  }

  @visibleForTesting
  void debugSyncGhostLayerForTest({double alpha = 0.0, Vector2? cameraCenter}) {
    final center = cameraCenter ?? Vector2.zero();
    _ghostLayer.syncLayer(alpha: alpha, cameraCenter: center);
    _ghostLayer.flushPendingEntityVisualCueEvents();
    _ghostLayer.flushPendingProjectileHitEvents(cameraCenter: center);
    _ghostLayer.flushPendingSpellImpactEvents(cameraCenter: center);
  }

  @visibleForTesting
  void debugDisableGhostLayerForTest(String reasonCode, {String? details}) {
    _ghostLayer.disableLayer(reasonCode, details: details);
  }

  /// Bottom anchor for parallax layers, aligned to the visible ground top.
  double _parallaxLayerBottomAnchorY() {
    final surfaces = controller.snapshot.groundSurfaces;
    if (surfaces.isEmpty) {
      return virtualHeight.toDouble();
    }

    var floorTopY = surfaces.first.topY;
    for (final surface in surfaces) {
      if (surface.topY > floorTopY) {
        floorTopY = surface.topY;
      }
    }

    final cameraCenter = camera.viewfinder.position;
    final transform = WorldViewTransform(
      cameraCenterX: cameraCenter.x,
      cameraCenterY: cameraCenter.y,
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
    );
    return math.roundToPixels(transform.worldToViewY(floorTopY));
  }
}
