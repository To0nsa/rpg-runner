// Flame rendering layer for the runner (Milestone 0 placeholder).
//
// Reads the latest `GameStateSnapshot` from `GameController` each frame and
// renders a minimal representation (a player dot + debug text). This file is
// intentionally tiny and non-authoritative: gameplay truth lives in Core.
import 'dart:math' as dart_math;
import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:runner_core/contracts/render_contract.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:runner_core/snapshots/static_solid_snapshot.dart';
import 'package:run_protocol/replay_blob.dart';
import 'debug/debug_aabb_overlay.dart';
import 'debug/render_debug_flags.dart';
import 'components/player/player_animations.dart';
import 'components/player/player_view_component.dart';
import 'components/enemies/enemy_render_registry.dart';
import 'components/pickups/pickup_render_registry.dart';
import 'components/projectiles/projectile_render_registry.dart';
import 'components/spell_impacts/spell_impact_render_registry.dart';
import 'components/sprite_anim/deterministic_anim_view_component.dart';
import 'components/sprite_anim/sprite_anim_set.dart';
import 'components/ground_surface_component.dart';
import 'components/ground_band_parallax_foreground_component.dart';
import 'tuning/player_render_tuning.dart';
import 'tuning/combat_feedback_tuning.dart';
import 'input/runner_input_router.dart';
import 'input/aim_preview.dart';
import 'components/pixel_parallax_backdrop_component.dart';
import 'components/aim_ray_component.dart';
import 'game_controller.dart';
import 'spatial/world_view_transform.dart';
import 'themes/parallax_theme_registry.dart';
import 'util/math_util.dart' as math;

// ─────────────────────────────────────────────────────────────────────────────
// Render priorities
// ─────────────────────────────────────────────────────────────────────────────

const _priorityBackgroundParallax = -30;
const _priorityTemporaryFloorMask = -25;
const _priorityGroundTiles = -20;
const _priorityForegroundParallax = -10;
const _priorityStaticSolids = -5;
const _priorityGhostEntities = -4;
const _priorityPlayer = -3;
const _priorityEnemies = -2;
const _priorityProjectiles = -1;
const _priorityCollectibles = -1;
const _priorityHitboxes = 1;
const _priorityActorHitboxes = 2;
const _priorityProjectileAimRay = 5;
const _priorityMeleeAimRay = 6;
const PlayerRenderTuning _playerRenderTuning = PlayerRenderTuning();
const _damageForMaxShake100 = 1500;
const _visualCueIntensityScaleBp = 10000;

enum RunLoadPhase {
  start,
  themeResolved,
  parallaxMounted,
  playerAnimationsLoaded,
  registriesLoaded,
  worldReady,
}

@immutable
class RunLoadState {
  const RunLoadState({required this.phase, required this.progress});

  final RunLoadPhase phase;
  final double progress;

  static const RunLoadState initial = RunLoadState(
    phase: RunLoadPhase.start,
    progress: 0.0,
  );
}

/// Minimal Flame `Game` that renders from snapshots.
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
       );

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

  late final PlayerViewComponent _player;
  late final GroundSurfaceComponent _groundSurface;
  final EnemyRenderRegistry _enemyRenderRegistry;
  final ProjectileRenderRegistry _projectileRenderRegistry;
  final SpellImpactRenderRegistry _spellImpactRenderRegistry;
  final PickupRenderRegistry _pickupRenderRegistry;
  final CombatFeedbackTuning _combatFeedbackTuning;
  final List<RectangleComponent> _staticSolids = <RectangleComponent>[];
  List<StaticSolidSnapshot>? _lastStaticSolidsSnapshot;

  /// Entity view pools, keyed by entity ID.
  final Map<int, DeterministicAnimViewComponent> _projectileAnimViews =
      <int, DeterministicAnimViewComponent>{};
  final Map<int, DeterministicAnimViewComponent> _pickupAnimViews =
      <int, DeterministicAnimViewComponent>{};
  final Map<int, DeterministicAnimViewComponent> _enemies =
      <int, DeterministicAnimViewComponent>{};
  final Map<int, RectangleComponent> _hitboxes = <int, RectangleComponent>{};
  final Map<int, RectangleComponent> _actorHitboxes =
      <int, RectangleComponent>{};

  final Paint _hitboxPaint = Paint()..color = const Color(0x66EF4444);
  final Paint _actorHitboxPaint = Paint()
    ..color = const Color(0xFF22C55E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Map<int, EntityRenderSnapshot> _prevEntitiesById =
      <int, EntityRenderSnapshot>{};
  final Map<int, int> _projectileSpawnTicks = <int, int>{};
  final Set<int> _seenIdsScratch = <int>{};
  final List<int> _toRemoveScratch = <int>[];
  final _CameraShakeController _cameraShake = _CameraShakeController();
  final Vector2 _cameraBaseCenterScratch = Vector2.zero();
  final Vector2 _cameraShakeOffsetScratch = Vector2.zero();
  final Vector2 _cameraCenterScratch = Vector2.zero();
  final Vector2 _snapScratch = Vector2.zero();
  final List<ProjectileHitEvent> _pendingProjectileHitEvents =
      <ProjectileHitEvent>[];
  final List<SpellImpactEvent> _pendingSpellImpactEvents =
      <SpellImpactEvent>[];
  final List<EntityVisualCueEvent> _pendingEntityVisualCueEvents =
      <EntityVisualCueEvent>[];
  final Map<int, DeterministicAnimViewComponent> _ghostEnemies =
      <int, DeterministicAnimViewComponent>{};
  final Map<int, DeterministicAnimViewComponent> _ghostProjectiles =
      <int, DeterministicAnimViewComponent>{};
  final Map<int, int> _ghostProjectileSpawnTicks = <int, int>{};
  final Map<int, EntityRenderSnapshot> _prevGhostEntitiesById =
      <int, EntityRenderSnapshot>{};
  final List<ProjectileHitEvent> _pendingGhostProjectileHitEvents =
      <ProjectileHitEvent>[];
  final List<SpellImpactEvent> _pendingGhostSpellImpactEvents =
      <SpellImpactEvent>[];
  final List<EntityVisualCueEvent> _pendingGhostEntityVisualCueEvents =
      <EntityVisualCueEvent>[];
  DeterministicAnimViewComponent? _ghostPlayer;
  int? _ghostPlayerEntityId;
  GameStateSnapshot? _ghostPrevSnapshot;
  GameStateSnapshot? _ghostSnapshot;
  ReplayBlobV1? _ghostReplayBlob;
  SpriteAnimSet? _ghostPlayerAnimSet;
  String? _ghostPlayerAnimCharacterId;
  bool _ghostPlayerAnimLoading = false;
  bool _ghostLayerDisabled = false;
  String? _ghostLayerDisableReason;

  void _onGhostRenderFeedChanged() {
    final replayBlob = ghostReplayBlobListenable?.value;
    if (replayBlob == null) {
      _ghostReplayBlob = null;
      _ghostSnapshot = null;
      _ghostPrevSnapshot = null;
      _ghostPlayerAnimSet = null;
      _ghostPlayerAnimCharacterId = null;
      _ghostLayerDisabled = false;
      _ghostLayerDisableReason = null;
      _clearGhostViews();
    } else {
      _ghostReplayBlob = replayBlob;
      if (replayBlob.playerCharacterId != _ghostPlayerAnimCharacterId &&
          !_ghostPlayerAnimLoading) {
        unawaited(_loadGhostPlayerAnimations(replayBlob));
      }
    }

    final nextSnapshot = ghostSnapshotListenable?.value;
    if (nextSnapshot != null) {
      _ghostPrevSnapshot = _ghostSnapshot;
      _ghostSnapshot = nextSnapshot;
    }

    final events = ghostEventsListenable?.value;
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

  Future<void> _loadGhostPlayerAnimations(ReplayBlobV1 replayBlob) async {
    _ghostPlayerAnimLoading = true;
    try {
      final characterId = _enumByName(
        PlayerCharacterId.values,
        replayBlob.playerCharacterId,
        fieldName: 'ghostReplayBlob.playerCharacterId',
      );
      final character = PlayerCharacterRegistry.resolve(characterId);
      _ghostPlayerAnimSet = await loadPlayerAnimations(
        images,
        renderAnim: character.renderAnim,
      );
      _ghostPlayerAnimCharacterId = replayBlob.playerCharacterId;
      _ghostLayerDisabled = false;
      _ghostLayerDisableReason = null;
    } catch (error) {
      _disableGhostLayer(
        'ghost-player-animation-load-failed',
        details: '$error',
      );
    } finally {
      _ghostPlayerAnimLoading = false;
    }
  }

  void _disableGhostLayer(String reasonCode, {String? details}) {
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

  void _clearGhostViews() {
    _ghostPlayerEntityId = null;
    _ghostPlayer?.removeFromParent();
    _ghostPlayer = null;
    for (final view in _ghostEnemies.values) {
      view.removeFromParent();
    }
    _ghostEnemies.clear();
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

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    ghostSnapshotListenable?.addListener(_onGhostRenderFeedChanged);
    ghostEventsListenable?.addListener(_onGhostRenderFeedChanged);
    ghostReplayBlobListenable?.addListener(_onGhostRenderFeedChanged);
    assert(() {
      playerCharacter.assertValid();
      return true;
    }());
    controller.addEventListener(_handleGameEvent);
    final theme = ParallaxThemeRegistry.forThemeId(controller.snapshot.themeId);
    _setLoadState(RunLoadPhase.themeResolved, 0.15);

    // Background parallax layers (sky, distant mountains, etc.)
    camera.backdrop.add(
      PixelParallaxBackdropComponent(
        virtualWidth: virtualWidth,
        virtualHeight: virtualHeight,
        snapScrollToPixels: false,
        layers: theme.backgroundLayers,
        layerBottomAnchorYProvider: _parallaxLayerBottomAnchorY,
      )..priority = _priorityBackgroundParallax,
    );

    camera.backdrop.add(
      _TemporaryFloorMaskComponent(
        controller: controller,
        virtualWidth: virtualWidth,
        virtualHeight: virtualHeight,
      )..priority = _priorityTemporaryFloorMask,
    );

    _groundSurface = GroundSurfaceComponent(
      assetPath: theme.groundLayerAsset,
      controller: controller,
      virtualWidth: virtualWidth,
      virtualHeight: virtualHeight,
    )..priority = _priorityGroundTiles;
    camera.backdrop.add(_groundSurface);

    // Foreground parallax layers (grass, bushes, etc.)
    camera.backdrop.add(
      GroundBandParallaxForegroundComponent(
        controller: controller,
        virtualWidth: virtualWidth,
        virtualHeight: virtualHeight,
        layers: theme.foregroundLayers,
        bandFillDepthProvider: () => _groundSurface.materialHeight,
        snapScrollToPixels: false,
      )..priority = _priorityForegroundParallax,
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
    _player = PlayerViewComponent(
      animationSet: playerAnimations,
      renderScale: Vector2.all(_playerRenderTuning.scale),
      feedbackTuning: _combatFeedbackTuning,
    )..priority = _priorityPlayer;
    world.add(_player);

    world.add(
      AimRayComponent(
        controller: controller,
        preview: projectileAimPreview,
        length: projectileAimRayLength,
        playerRenderPos: () => _player.position,
        drawWhenNoAim: false,
      )..priority = _priorityProjectileAimRay,
    );

    world.add(
      AimRayComponent(
        controller: controller,
        preview: meleeAimPreview,
        length: meleeAimRayLength,
        playerRenderPos: () => _player.position,
        drawWhenNoAim: false,
        paint: Paint()
          ..color = const Color(0xFFDC4440)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      )..priority = _priorityMeleeAimRay,
    );

    _mountStaticSolids(controller.snapshot.staticSolids);
    _lastStaticSolidsSnapshot = controller.snapshot.staticSolids;
    _setLoadState(RunLoadPhase.worldReady, 1.0);
  }

  @override
  void update(double dt) {
    final snapshot = controller.snapshot;
    if (!snapshot.paused && !snapshot.gameOver) {
      input.pumpHeldInputs();
    }

    // Step the deterministic core using the frame delta, then render the newest
    // snapshot. This order is critical: Flame components (parallax, etc.) read
    // the camera during their own update(), so Core + camera + view sync must
    // run BEFORE super.update(dt).
    controller.advanceFrame(dt);

    final prevSnapshot = controller.prevSnapshot;
    final currSnapshot = controller.snapshot;
    final alpha = controller.alpha;

    _prevEntitiesById.clear();
    for (final e in prevSnapshot.entities) {
      _prevEntitiesById[e.id] = e;
    }

    final camX = math.lerpDouble(
      prevSnapshot.camera.centerX,
      currSnapshot.camera.centerX,
      alpha,
    );
    final camY = math.lerpDouble(
      prevSnapshot.camera.centerY,
      currSnapshot.camera.centerY,
      alpha,
    );
    _cameraBaseCenterScratch.setValues(camX, camY);
    _cameraShake.sample(dt, _cameraShakeOffsetScratch);
    _cameraCenterScratch.setValues(
      _cameraBaseCenterScratch.x + _cameraShakeOffsetScratch.x,
      _cameraBaseCenterScratch.y + _cameraShakeOffsetScratch.y,
    );
    camera.viewfinder.position = _cameraCenterScratch;

    _syncStaticSolids(currSnapshot.staticSolids);
    _snapStaticSolids(
      currSnapshot.staticSolids,
      cameraCenter: _cameraCenterScratch,
    );

    final player = currSnapshot.playerEntity;
    if (player != null) {
      final prev = _prevEntitiesById[player.id] ?? player;
      final worldX = math.lerpDouble(prev.pos.x, player.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, player.pos.y, alpha);
      _snapScratch.setValues(
        math.snapWorldToPixelsInCameraSpace1d(worldX, _cameraCenterScratch.x),
        math.snapWorldToPixelsInCameraSpace1d(worldY, _cameraCenterScratch.y),
      );
      _player.applySnapshot(
        player,
        tickHz: controller.tickHz,
        pos: _snapScratch,
      );
      _player.setStatusVisualMask(player.statusVisualMask);
    }

    _syncEnemies(
      currSnapshot.entities,
      prevById: _prevEntitiesById,
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
    );
    _flushPendingEntityVisualCueEvents(playerEntityId: player?.id);
    _syncProjectiles(
      currSnapshot.entities,
      prevById: _prevEntitiesById,
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
      tick: currSnapshot.tick,
    );
    _syncCollectibles(
      currSnapshot.entities,
      prevById: _prevEntitiesById,
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
    );
    _flushPendingSpellImpactEvents(cameraCenter: _cameraCenterScratch);
    _syncGhostLayer(alpha: alpha, cameraCenter: _cameraCenterScratch);
    _flushPendingGhostEntityVisualCueEvents();
    _flushPendingGhostProjectileHitEvents(cameraCenter: _cameraCenterScratch);
    _flushPendingGhostSpellImpactEvents(cameraCenter: _cameraCenterScratch);
    final drawHitboxes =
        RenderDebugFlags.canUseRenderDebug &&
        RenderDebugFlags.drawActorHitboxes;
    if (drawHitboxes) {
      _syncHitboxes(
        currSnapshot.entities,
        prevById: _prevEntitiesById,
        alpha: alpha,
        cameraCenter: _cameraCenterScratch,
      );
    } else if (_hitboxes.isNotEmpty) {
      for (final view in _hitboxes.values) {
        view.removeFromParent();
      }
      _hitboxes.clear();
    }
    syncDebugAabbOverlays(
      entities: currSnapshot.entities,
      enabled:
          RenderDebugFlags.canUseRenderDebug &&
          RenderDebugFlags.drawActorHitboxes,
      parent: world,
      pool: _actorHitboxes,
      priority: _priorityActorHitboxes,
      paint: _actorHitboxPaint,
      include: (e) => e.kind == EntityKind.player || e.kind == EntityKind.enemy,
      prevById: _prevEntitiesById,
      offsetXFor: (e) {
        switch (e.kind) {
          case EntityKind.player:
            return playerCharacter.catalog.colliderOffsetX;
          case EntityKind.enemy:
            final enemyId = e.enemyId;
            if (enemyId == null) return 0.0;
            return controller.enemyCatalog.get(enemyId).collider.offsetX;
          default:
            return 0.0;
        }
      },
      offsetYFor: (e) {
        switch (e.kind) {
          case EntityKind.player:
            return playerCharacter.catalog.colliderOffsetY;
          case EntityKind.enemy:
            final enemyId = e.enemyId;
            if (enemyId == null) return 0.0;
            return controller.enemyCatalog.get(enemyId).collider.offsetY;
          default:
            return 0.0;
        }
      },
      alpha: alpha,
      cameraCenter: _cameraCenterScratch,
    );

    _flushPendingProjectileHitEvents(cameraCenter: _cameraCenterScratch);

    super.update(dt);
  }

  /// Mounts static solid rectangles into the world.
  ///
  /// Called once on load and whenever the static solids list changes.
  /// One-way platforms are rendered with a green tint, solid platforms with
  /// purple.
  void _mountStaticSolids(List<StaticSolidSnapshot> solids) {
    if (solids.isEmpty) return;

    for (final solid in solids) {
      final color = solid.oneWayTop
          ? const Color(0x6648BB78) // green-ish translucent
          : const Color(0x668B5CF6); // purple translucent

      final rect = RectangleComponent(
        position: Vector2(solid.minX, solid.minY),
        size: Vector2(solid.maxX - solid.minX, solid.maxY - solid.minY),
        paint: Paint()..color = color,
      );
      rect.priority = _priorityStaticSolids;
      _staticSolids.add(rect);
      world.add(rect);
    }
  }

  /// Synchronizes enemy view components with the snapshot.
  ///
  /// Creates view components for new enemies, updates existing ones, and
  /// removes components for despawned enemies.
  void _syncEnemies(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final e in entities) {
      if (e.kind != EntityKind.enemy) continue;

      final entry = e.enemyId == null
          ? null
          : _enemyRenderRegistry.entryFor(e.enemyId!);
      if (entry == null) {
        _enemies.remove(e.id)?.removeFromParent();
        continue;
      }

      seen.add(e.id);

      var view = _enemies[e.id];
      if (view == null) {
        view = entry.viewFactory(entry.animSet, entry.renderScale)
          ..priority = _priorityEnemies;
        view.setFeedbackTuning(_combatFeedbackTuning);
        _enemies[e.id] = view;
        world.add(view);
      }

      final prev = prevById[e.id] ?? e;
      final worldX = math.lerpDouble(prev.pos.x, e.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, e.pos.y, alpha);
      final snappedX = math.snapWorldToPixelsInCameraSpace1d(
        worldX,
        cameraCenter.x,
      );
      final snappedY = math.snapWorldToPixelsInCameraSpace1d(
        worldY,
        cameraCenter.y,
      );

      _snapScratch.setValues(snappedX, snappedY);
      view.applySnapshot(e, tickHz: controller.tickHz, pos: _snapScratch);
      view.setStatusVisualMask(e.statusVisualMask);
    }

    if (_enemies.isEmpty) return;
    final toRemove = _toRemoveScratch..clear();
    for (final id in _enemies.keys) {
      if (!seen.contains(id)) toRemove.add(id);
    }
    for (final id in toRemove) {
      _enemies.remove(id)?.removeFromParent();
    }
  }

  void _handleGameEvent(GameEvent event) {
    if (event is PlayerImpactFeedbackEvent) {
      _cameraShake.trigger(
        intensity01: _shakeIntensityFromDamage100(event.amount100),
      );
      return;
    }
    if (event is EntityVisualCueEvent) {
      _pendingEntityVisualCueEvents.add(event);
      return;
    }
    if (event is ProjectileHitEvent) {
      _pendingProjectileHitEvents.add(event);
      return;
    }
    if (event is SpellImpactEvent) {
      _pendingSpellImpactEvents.add(event);
    }
  }

  double _shakeIntensityFromDamage100(int amount100) {
    if (amount100 <= 0) return 0.0;
    final normalized = (amount100 / _damageForMaxShake100).clamp(0.0, 1.0);
    return dart_math.sqrt(normalized);
  }

  void _flushPendingEntityVisualCueEvents({required int? playerEntityId}) {
    if (_pendingEntityVisualCueEvents.isEmpty) return;

    for (final event in _pendingEntityVisualCueEvents) {
      final intensity01 = _visualCueIntensity01(event.intensityBp);
      if (intensity01 <= 0.0) continue;

      final DeterministicAnimViewComponent? view;
      if (playerEntityId != null && event.entityId == playerEntityId) {
        view = _player;
      } else {
        view = _enemies[event.entityId];
      }
      if (view == null) continue;

      switch (event.kind) {
        case EntityVisualCueKind.directHit:
          view.triggerDirectHitFlash(intensity01: intensity01);
        case EntityVisualCueKind.dotPulse:
          view.triggerDotPulse(
            color: _combatFeedbackTuning.dotColorFor(event.damageType),
            intensity01: intensity01,
          );
        case EntityVisualCueKind.resourcePulse:
          view.triggerResourcePulse(
            color: _combatFeedbackTuning.resourceColorFor(event.resourceType),
            intensity01: intensity01,
          );
      }
    }

    _pendingEntityVisualCueEvents.clear();
  }

  double _visualCueIntensity01(int intensityBp) {
    if (intensityBp <= 0) return 0.0;
    return (intensityBp / _visualCueIntensityScaleBp).clamp(0.0, 1.0);
  }

  void _flushPendingProjectileHitEvents({required Vector2 cameraCenter}) {
    if (_pendingProjectileHitEvents.isEmpty) return;

    for (final event in _pendingProjectileHitEvents) {
      final entry = _projectileRenderRegistry.entryFor(event.projectileId);
      if (entry == null) continue;

      final hitAnim = entry.animSet.animations[AnimKey.hit];
      if (hitAnim == null) continue;

      final component = _CameraSpaceSnappedSpriteAnimationComponent(
        animation: hitAnim,
        size: entry.animSet.frameSize.clone(),
        worldPosX: event.pos.x,
        worldPosY: event.pos.y,
        anchor: entry.animSet.anchor,
        paint: Paint()..filterQuality = FilterQuality.none,
        removeOnFinish: true,
      )..priority = _priorityProjectiles;

      component.scale.setValues(entry.renderScale.x, entry.renderScale.y);
      component.angle = event.rotationRad;
      component.snapToCamera(cameraCenter);
      world.add(component);
    }

    _pendingProjectileHitEvents.clear();
  }

  void _flushPendingSpellImpactEvents({required Vector2 cameraCenter}) {
    if (_pendingSpellImpactEvents.isEmpty) return;

    for (final event in _pendingSpellImpactEvents) {
      final entry = _spellImpactRenderRegistry.entryFor(event.impactId);
      if (entry == null) continue;

      final hitAnim = entry.animSet.animations[AnimKey.hit];
      if (hitAnim == null) continue;

      final component = _CameraSpaceSnappedSpriteAnimationComponent(
        animation: hitAnim,
        size: entry.animSet.frameSize.clone(),
        worldPosX: event.pos.x,
        worldPosY: event.pos.y,
        anchor: entry.animSet.anchor,
        paint: Paint()..filterQuality = FilterQuality.none,
        removeOnFinish: true,
      )..priority = _priorityProjectiles;

      component.scale.setValues(entry.renderScale.x, entry.renderScale.y);
      component.snapToCamera(cameraCenter);
      world.add(component);
    }

    _pendingSpellImpactEvents.clear();
  }

  /// Synchronizes projectile view components with the snapshot.
  ///
  /// Creates rectangle components for new projectiles, updates position/size
  /// for existing ones, and removes components for despawned projectiles.
  void _syncProjectiles(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
    required int tick,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final e in entities) {
      if (e.kind != EntityKind.projectile) continue;
      seen.add(e.id);

      final projectileId = e.projectileId;
      final entry = projectileId == null
          ? null
          : _projectileRenderRegistry.entryFor(projectileId);

      if (entry != null) {
        var view = _projectileAnimViews[e.id];
        if (view == null) {
          view = entry.viewFactory(entry.animSet, entry.renderScale);
          view.priority = _priorityProjectiles;
          _projectileAnimViews[e.id] = view;
          _projectileSpawnTicks[e.id] = tick;
          world.add(view);
        }

        final prev = prevById[e.id] ?? e;
        final worldX = math.lerpDouble(prev.pos.x, e.pos.x, alpha);
        final worldY = math.lerpDouble(prev.pos.y, e.pos.y, alpha);
        _snapScratch.setValues(
          math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
          math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
        );

        final spawnTick = _projectileSpawnTicks[e.id] ?? tick;
        final startTicks = entry.spawnAnimTicks(controller.tickHz);
        final ageTicks = tick - spawnTick;
        final animOverride =
            startTicks > 0 && ageTicks >= 0 && ageTicks < startTicks
            ? AnimKey.spawn
            : AnimKey.idle;
        final overrideAnimFrame = animOverride == AnimKey.spawn
            ? ageTicks
            : null;

        view.applySnapshot(
          e,
          tickHz: controller.tickHz,
          pos: _snapScratch,
          overrideAnim: animOverride,
          overrideAnimFrame: overrideAnimFrame,
        );
        final spinSpeed = entry.spinSpeedRadPerSecond;
        if (spinSpeed == 0.0) {
          view.angle = e.rotationRad;
        } else {
          final spinSeconds = (ageTicks.toDouble() + alpha) / controller.tickHz;
          view.angle = e.rotationRad + spinSpeed * spinSeconds;
        }
      } else {
        // No fallback rendering for unknown/unregistered projectiles.
        //
        // If the projectile exists in Core but has no render wiring (or assets),
        // we simply avoid rendering it rather than using placeholder rectangles.
        _projectileAnimViews.remove(e.id)?.removeFromParent();
        _projectileSpawnTicks.remove(e.id);
      }
    }

    if (_projectileAnimViews.isNotEmpty) {
      final toRemove = _toRemoveScratch..clear();
      for (final id in _projectileAnimViews.keys) {
        if (!seen.contains(id)) toRemove.add(id);
      }
      for (final id in toRemove) {
        _projectileAnimViews.remove(id)?.removeFromParent();
        _projectileSpawnTicks.remove(id);
      }
    }
  }

  /// Synchronizes collectible/pickup view components with the snapshot.
  ///
  /// Creates deterministic animation components for pickups and removes
  /// components for collected pickups.
  void _syncCollectibles(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final e in entities) {
      if (e.kind != EntityKind.pickup) continue;
      seen.add(e.id);

      final variant = e.pickupVariant ?? PickupVariant.collectible;
      final entry = _pickupRenderRegistry.entryForVariant(variant);

      var view = _pickupAnimViews[e.id];
      if (view == null) {
        view = entry.viewFactory(entry.animSet, entry.renderScale);
        view.priority = _priorityCollectibles;
        _pickupAnimViews[e.id] = view;
        world.add(view);
      }

      final prev = prevById[e.id] ?? e;
      final worldX = math.lerpDouble(prev.pos.x, e.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, e.pos.y, alpha);
      _snapScratch.setValues(
        math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
      );
      view.applySnapshot(e, tickHz: controller.tickHz, pos: _snapScratch);
      view.angle = e.rotationRad;
    }

    if (_pickupAnimViews.isEmpty) return;
    final toRemove = _toRemoveScratch..clear();
    for (final id in _pickupAnimViews.keys) {
      if (!seen.contains(id)) toRemove.add(id);
    }
    for (final id in toRemove) {
      _pickupAnimViews.remove(id)?.removeFromParent();
    }
  }

  void _syncGhostLayer({required double alpha, required Vector2 cameraCenter}) {
    if (_ghostLayerDisabled) {
      if (_ghostLayerDisableReason != null) {
        // Read reason field so diagnostic context remains attached to disable state.
      }
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
    _syncGhostEnemies(
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
      playerView = PlayerViewComponent(
        animationSet: playerAnimSet,
        renderScale: Vector2.all(_playerRenderTuning.scale),
        feedbackTuning: _combatFeedbackTuning,
      )
        ..priority = _priorityGhostEntities
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

  void _syncGhostEnemies({
    required List<EntityRenderSnapshot> entities,
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    final seen = _seenIdsScratch..clear();
    for (final entity in entities) {
      if (entity.kind != EntityKind.enemy) continue;
      final enemyId = entity.enemyId;
      final entry = enemyId == null ? null : _enemyRenderRegistry.entryFor(enemyId);
      if (entry == null) {
        _ghostEnemies.remove(entity.id)?.removeFromParent();
        continue;
      }

      seen.add(entity.id);
      var view = _ghostEnemies[entity.id];
      if (view == null) {
        view = entry.viewFactory(entry.animSet, entry.renderScale)
          ..priority = _priorityGhostEntities
          ..setFeedbackTuning(_combatFeedbackTuning)
          ..setVisualStyle(RenderVisualStyle.ghost);
        _ghostEnemies[entity.id] = view;
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

    if (_ghostEnemies.isEmpty) {
      return;
    }
    final toRemove = _toRemoveScratch..clear();
    for (final id in _ghostEnemies.keys) {
      if (!seen.contains(id)) {
        toRemove.add(id);
      }
    }
    for (final id in toRemove) {
      _ghostEnemies.remove(id)?.removeFromParent();
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
      if (entity.kind != EntityKind.projectile) continue;
      seen.add(entity.id);

      final projectileId = entity.projectileId;
      final entry = projectileId == null
          ? null
          : _projectileRenderRegistry.entryFor(projectileId);
      if (entry == null) {
        _ghostProjectiles.remove(entity.id)?.removeFromParent();
        _ghostProjectileSpawnTicks.remove(entity.id);
        continue;
      }

      var view = _ghostProjectiles[entity.id];
      if (view == null) {
        view = entry.viewFactory(entry.animSet, entry.renderScale)
          ..priority = _priorityGhostEntities
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

  void _flushPendingGhostEntityVisualCueEvents() {
    if (_pendingGhostEntityVisualCueEvents.isEmpty) {
      return;
    }

    for (final event in _pendingGhostEntityVisualCueEvents) {
      final intensity01 = _visualCueIntensity01(event.intensityBp);
      if (intensity01 <= 0.0) continue;

      final DeterministicAnimViewComponent? view;
      if (_ghostPlayerEntityId != null && event.entityId == _ghostPlayerEntityId) {
        view = _ghostPlayer;
      } else {
        view = _ghostEnemies[event.entityId] ?? _ghostProjectiles[event.entityId];
      }
      if (view == null) continue;

      switch (event.kind) {
        case EntityVisualCueKind.directHit:
          view.triggerDirectHitFlash(intensity01: intensity01);
        case EntityVisualCueKind.dotPulse:
          view.triggerDotPulse(
            color: _combatFeedbackTuning.dotColorFor(event.damageType),
            intensity01: intensity01,
          );
        case EntityVisualCueKind.resourcePulse:
          view.triggerResourcePulse(
            color: _combatFeedbackTuning.resourceColorFor(event.resourceType),
            intensity01: intensity01,
          );
      }
    }

    _pendingGhostEntityVisualCueEvents.clear();
  }

  void _flushPendingGhostProjectileHitEvents({required Vector2 cameraCenter}) {
    if (_pendingGhostProjectileHitEvents.isEmpty) {
      return;
    }

    for (final event in _pendingGhostProjectileHitEvents) {
      final entry = _projectileRenderRegistry.entryFor(event.projectileId);
      if (entry == null) continue;

      final hitAnim = entry.animSet.animations[AnimKey.hit];
      if (hitAnim == null) continue;

      final component = _CameraSpaceSnappedSpriteAnimationComponent(
        animation: hitAnim,
        size: entry.animSet.frameSize.clone(),
        worldPosX: event.pos.x,
        worldPosY: event.pos.y,
        anchor: entry.animSet.anchor,
        paint: Paint()..filterQuality = FilterQuality.none,
        removeOnFinish: true,
      )..priority = _priorityGhostEntities;

      component.scale.setValues(entry.renderScale.x, entry.renderScale.y);
      component.angle = event.rotationRad;
      component.snapToCamera(cameraCenter);
      world.add(component);
    }

    _pendingGhostProjectileHitEvents.clear();
  }

  void _flushPendingGhostSpellImpactEvents({required Vector2 cameraCenter}) {
    if (_pendingGhostSpellImpactEvents.isEmpty) {
      return;
    }

    for (final event in _pendingGhostSpellImpactEvents) {
      final entry = _spellImpactRenderRegistry.entryFor(event.impactId);
      if (entry == null) continue;

      final hitAnim = entry.animSet.animations[AnimKey.hit];
      if (hitAnim == null) continue;

      final component = _CameraSpaceSnappedSpriteAnimationComponent(
        animation: hitAnim,
        size: entry.animSet.frameSize.clone(),
        worldPosX: event.pos.x,
        worldPosY: event.pos.y,
        anchor: entry.animSet.anchor,
        paint: Paint()..filterQuality = FilterQuality.none,
        removeOnFinish: true,
      )..priority = _priorityGhostEntities;

      component.scale.setValues(entry.renderScale.x, entry.renderScale.y);
      component.snapToCamera(cameraCenter);
      world.add(component);
    }

    _pendingGhostSpellImpactEvents.clear();
  }

  /// Synchronizes trigger/hitbox view components with the snapshot.
  ///
  /// Creates translucent red rectangle components for new triggers, updates
  /// position/size for existing ones, and removes components for despawned
  /// triggers.
  void _syncHitboxes(
    List<EntityRenderSnapshot> entities, {
    required Map<int, EntityRenderSnapshot> prevById,
    required double alpha,
    required Vector2 cameraCenter,
  }) {
    final seen = _seenIdsScratch..clear();

    for (final e in entities) {
      if (e.kind != EntityKind.trigger) continue;
      seen.add(e.id);

      var view = _hitboxes[e.id];
      if (view == null) {
        final size = e.size;
        view = RectangleComponent(
          size: Vector2(size?.x ?? 8.0, size?.y ?? 8.0),
          anchor: Anchor.center,
          paint: _hitboxPaint,
        );
        view.priority = _priorityHitboxes;
        _hitboxes[e.id] = view;
        world.add(view);
      } else {
        final size = e.size;
        if (size != null) {
          view.size.setValues(size.x, size.y);
        }
      }

      final prev = prevById[e.id] ?? e;
      final worldX = math.lerpDouble(prev.pos.x, e.pos.x, alpha);
      final worldY = math.lerpDouble(prev.pos.y, e.pos.y, alpha);
      view.position.setValues(
        math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
      );
    }

    if (_hitboxes.isEmpty) return;
    final toRemove = _toRemoveScratch..clear();
    for (final id in _hitboxes.keys) {
      if (!seen.contains(id)) toRemove.add(id);
    }
    for (final id in toRemove) {
      _hitboxes.remove(id)?.removeFromParent();
    }
  }

  /// Synchronizes static solid views with the snapshot.
  ///
  /// Uses identity comparison as a cheap version check since Core rebuilds
  /// the list only when geometry actually changes (spawn/cull).
  void _syncStaticSolids(List<StaticSolidSnapshot> solids) {
    // Core rebuilds the list only when geometry changes (spawn/cull),
    // so identity check is a cheap "version" check.
    if (identical(solids, _lastStaticSolidsSnapshot)) return;
    _lastStaticSolidsSnapshot = solids;

    for (final c in _staticSolids) {
      c.removeFromParent();
    }
    _staticSolids.clear();

    _mountStaticSolids(solids);
  }

  void _snapStaticSolids(
    List<StaticSolidSnapshot> solids, {
    required Vector2 cameraCenter,
  }) {
    if (solids.isEmpty) return;
    if (_staticSolids.length != solids.length) return;
    final transform = WorldViewTransform(
      cameraCenterX: cameraCenter.x,
      cameraCenterY: cameraCenter.y,
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
    );

    for (var i = 0; i < solids.length; i++) {
      final solid = solids[i];
      final view = _staticSolids[i];
      view.position.setValues(
        math.snapWorldToPixelsInViewX(solid.minX, transform),
        math.snapWorldToPixelsInViewY(solid.minY, transform),
      );
    }
  }

  @override
  void onRemove() {
    ghostSnapshotListenable?.removeListener(_onGhostRenderFeedChanged);
    ghostEventsListenable?.removeListener(_onGhostRenderFeedChanged);
    ghostReplayBlobListenable?.removeListener(_onGhostRenderFeedChanged);
    _clearGhostViews();
    controller.removeEventListener(_handleGameEvent);
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
  bool get debugGhostLayerDisabled => _ghostLayerDisabled;

  @visibleForTesting
  String? get debugGhostLayerDisableReason => _ghostLayerDisableReason;

  @visibleForTesting
  bool get debugHasGhostPlayerView => _ghostPlayer != null;

  @visibleForTesting
  int? get debugGhostPlayerEntityId => _ghostPlayerEntityId;

  @visibleForTesting
  int get debugGhostEnemyCount => _ghostEnemies.length;

  @visibleForTesting
  int get debugGhostProjectileCount => _ghostProjectiles.length;

  @visibleForTesting
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

  @visibleForTesting
  void debugSyncGhostLayerForTest({
    double alpha = 0.0,
    Vector2? cameraCenter,
  }) {
    final center = cameraCenter ?? Vector2.zero();
    _syncGhostLayer(alpha: alpha, cameraCenter: center);
    _flushPendingGhostEntityVisualCueEvents();
    _flushPendingGhostProjectileHitEvents(cameraCenter: center);
    _flushPendingGhostSpellImpactEvents(cameraCenter: center);
  }

  @visibleForTesting
  void debugDisableGhostLayerForTest(String reasonCode, {String? details}) {
    _disableGhostLayer(reasonCode, details: details);
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

/// Lightweight procedural camera shake.
///
/// The shake is additive to the authoritative camera center from Core.
class _CameraShakeController {
  double _elapsedSeconds = 0.0;
  double _durationSeconds = 0.0;
  double _amplitudePixels = 0.0;
  double _seedPhase = 0.0;

  void trigger({required double intensity01}) {
    final clamped = intensity01.clamp(0.0, 1.0);
    if (clamped <= 0.0) return;

    _durationSeconds = _lerp(0.12, 0.24, clamped);
    _amplitudePixels = _lerp(1.5, 5.5, clamped);
    _elapsedSeconds = 0.0;
    _seedPhase += dart_math.pi * 0.31;
  }

  void sample(double dtSeconds, Vector2 out) {
    if (_durationSeconds <= 0.0 || _elapsedSeconds >= _durationSeconds) {
      out.setZero();
      return;
    }

    _elapsedSeconds += dtSeconds;
    if (_elapsedSeconds >= _durationSeconds) {
      out.setZero();
      return;
    }

    final t = _elapsedSeconds / _durationSeconds;
    final damper = (1.0 - t) * (1.0 - t);
    final angle = _seedPhase + (_elapsedSeconds * _oscillationRadPerSecond);
    out.setValues(
      dart_math.sin(angle) * _amplitudePixels * damper,
      dart_math.cos(angle * 1.73) * (_amplitudePixels * 0.65) * damper,
    );
  }

  static const double _oscillationRadPerSecond = 44.0 * 2.0 * dart_math.pi;

  double _lerp(double min, double max, double t) => min + (max - min) * t;
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

/// Temporary black backdrop mask from floor level downward.
///
/// Keep this local and disposable: delete this class and the one mount call in
/// `onLoad` when no longer needed.
class _TemporaryFloorMaskComponent extends Component
    with HasGameReference<FlameGame> {
  _TemporaryFloorMaskComponent({
    required this.controller,
    required this.virtualWidth,
    required this.virtualHeight,
  });

  final GameController controller;
  final int virtualWidth;
  final int virtualHeight;

  final Paint _paint = Paint()..color = const Color(0xFF000000);

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final surfaces = controller.snapshot.groundSurfaces;
    if (surfaces.isEmpty) return;

    // Use the lowest visible ground top so the mask starts at floor level.
    var floorTopY = surfaces.first.topY;
    for (final surface in surfaces) {
      if (surface.topY > floorTopY) {
        floorTopY = surface.topY;
      }
    }

    final camX = -game.camera.viewfinder.transform.offset.x;
    final camY = -game.camera.viewfinder.transform.offset.y;
    final transform = WorldViewTransform(
      cameraCenterX: camX,
      cameraCenterY: camY,
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
    );

    final maskTopY = math.roundToPixels(transform.worldToViewY(floorTopY));
    final clampedTopY = maskTopY.clamp(0.0, virtualHeight.toDouble());
    if (clampedTopY >= virtualHeight.toDouble()) return;

    canvas.drawRect(
      Rect.fromLTWH(
        0.0,
        clampedTopY,
        virtualWidth.toDouble(),
        virtualHeight.toDouble() - clampedTopY,
      ),
      _paint,
    );
  }
}

class _CameraSpaceSnappedSpriteAnimationComponent
    extends SpriteAnimationComponent
    with HasGameReference<FlameGame> {
  _CameraSpaceSnappedSpriteAnimationComponent({
    required SpriteAnimation super.animation,
    required Vector2 super.size,
    required this.worldPosX,
    required this.worldPosY,
    super.anchor = Anchor.center,
    super.paint,
    super.removeOnFinish,
  });

  final double worldPosX;
  final double worldPosY;

  void snapToCamera(Vector2 cameraCenter) {
    position.setValues(
      math.snapWorldToPixelsInCameraSpace1d(worldPosX, cameraCenter.x),
      math.snapWorldToPixelsInCameraSpace1d(worldPosY, cameraCenter.y),
    );
  }

  @override
  void update(double dt) {
    snapToCamera(game.camera.viewfinder.position);
    super.update(dt);
  }
}
