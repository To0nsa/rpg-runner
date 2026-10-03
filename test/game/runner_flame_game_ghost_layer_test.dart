import 'dart:ui' as ui;

import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:rpg_runner/game/components/sprite_anim/deterministic_anim_view.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';
import 'package:rpg_runner/game/replay/ghost_render_frame.dart';
import 'package:rpg_runner/game/components/player/player_view.dart';
import 'package:rpg_runner/game/components/camera_space_snapped_sprite_animation.dart';

import 'package:flame/components.dart';
import 'package:flame/cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:runner_core/snapshots/actor_frame_snapshot.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:rpg_runner/game/components/sprite_anim/sprite_anim_set.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/aim_preview.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';
import 'package:rpg_runner/game/runner_flame_game.dart';
import 'package:rpg_runner/game/runner_flame/ghost_layer_system.dart';
import 'package:rpg_runner/game/runner_flame/live_world_sync_system.dart';
import 'package:rpg_runner/game/components/enemies/enemy_render_registry.dart';
import 'package:rpg_runner/game/components/npcs/npc_render_registry.dart';
import 'package:rpg_runner/game/components/pickups/pickup_render_registry.dart';
import 'package:rpg_runner/game/components/projectiles/projectile_render_registry.dart';
import 'package:rpg_runner/game/components/spell_impacts/spell_impact_render_registry.dart';
import 'package:rpg_runner/game/tuning/combat_feedback_tuning.dart';

import '../support/test_level.dart';
import '../test_tunings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'viewport culls actors and effects while retaining projectile age',
    () async {
      final harness = _buildHarness();
      addTearDown(harness.dispose);
      final image = await _singlePixelImage();
      addTearDown(image.dispose);
      final images = Images();
      addTearDown(images.clearCache);
      final npcs = NpcRenderRegistry();
      final projectiles = ProjectileRenderRegistry();
      final impacts = SpellImpactRenderRegistry();
      await Future.wait([
        npcs.load(images),
        projectiles.load(images),
        impacts.load(images),
      ]);
      final world = Component();
      final layer = GhostLayerSystem(
        controller: harness.controller,
        world: world,
        images: images,
        enemyRenderRegistry: EnemyRenderRegistry(),
        npcRenderRegistry: npcs,
        projectileRenderRegistry: projectiles,
        spellImpactRenderRegistry: impacts,
        combatFeedbackTuning: const CombatFeedbackTuning(),
        ghostRenderListenable: null,
      );
      addTearDown(layer.clearViews);
      final replay = _ghostReplayBlob(levelId: LevelId.field);
      final animSet = _buildAnimSet(image);
      ActorFrameSnapshot snapshot(int tick, double x) => _copySnapshot(
        harness.controller.snapshot,
        tick: tick,
        entities: [
          _entity(id: 1, kind: EntityKind.player, x: x, y: 0),
          EntityRenderSnapshot(
            id: 2,
            kind: EntityKind.npc,
            npcId: NpcId.warrior,
            pos: Vec2(x, 0),
            facing: Facing.left,
            anim: AnimKey.idle,
            grounded: true,
          ),
          EntityRenderSnapshot(
            id: 3,
            kind: EntityKind.projectile,
            projectileId: ProjectileId.iceBolt,
            pos: Vec2(x, 0),
            facing: Facing.left,
            anim: AnimKey.idle,
            grounded: false,
          ),
        ],
      );
      layer.debugSetGhostRenderStateForTest(
        snapshot: snapshot(1, 10000),
        replayBlob: replay,
        playerAnimSet: animSet,
        events: [
          const SpellImpactEvent(
            tick: 1,
            impactId: SpellImpactId.fireExplosion,
            pos: Vec2(10000, 0),
          ),
        ],
      );
      layer.syncLayer(alpha: 1, cameraCenter: Vector2.zero());
      layer.flushPendingSpellImpactEvents(cameraCenter: Vector2.zero());
      expect(layer.debugHasGhostPlayerView, isFalse);
      expect(layer.debugGhostNpcCount, 0);
      expect(layer.debugGhostProjectileCount, 0);
      expect(
        world.children.whereType<CameraSpaceSnappedSpriteAnimation>(),
        isEmpty,
      );

      layer.debugSetGhostRenderStateForTest(
        snapshot: snapshot(100, 0),
        prevSnapshot: snapshot(99, 10000),
        replayBlob: replay,
        playerAnimSet: animSet,
      );
      layer.syncLayer(alpha: 0, cameraCenter: Vector2.zero());
      expect(layer.debugGhostProjectileCount, 0);
      layer.syncLayer(alpha: 1, cameraCenter: Vector2.zero());
      expect(layer.debugHasGhostPlayerView, isTrue);
      expect(layer.debugGhostNpcCount, 1);
      expect(layer.debugGhostProjectileCount, 1);
      expect(
        world.children.whereType<DeterministicAnimView>().every(
          (view) => view.current == AnimKey.idle,
        ),
        isTrue,
        reason:
            'Entering the viewport must not restart projectile spawn animation',
      );
      layer.syncLayer(alpha: 1, cameraCenter: Vector2(10000, 0));
      expect(layer.debugHasGhostPlayerView, isFalse);
      expect(layer.debugGhostNpcCount, 0);
      expect(layer.debugGhostProjectileCount, 0);
    },
  );

  test(
    'viewport retains sprites overlapping the edge despite an outside anchor',
    () async {
      final harness = _buildHarness();
      addTearDown(harness.dispose);
      final image = await _singlePixelImage();
      addTearDown(image.dispose);
      final small = _buildAnimSet(image);
      final large = SpriteAnimSet(
        animations: small.animations,
        stepTimeSecondsByKey: small.stepTimeSecondsByKey,
        oneShotKeys: small.oneShotKeys,
        frameSize: Vector2(100, 80),
        anchor: Anchor.bottomRight,
      );
      final edge = harness.controller.snapshot.camera.viewWidth / 2;
      harness.game.debugSetGhostRenderStateForTest(
        snapshot: _copySnapshot(
          harness.controller.snapshot,
          tick: 1,
          entities: [
            _entity(id: 1, kind: EntityKind.player, x: edge + 5, y: 0),
          ],
        ),
        replayBlob: _ghostReplayBlob(levelId: LevelId.field),
        playerAnimSet: large,
      );
      harness.game.debugSyncGhostLayerForTest(cameraCenter: Vector2.zero());
      expect(harness.game.debugHasGhostPlayerView, isTrue);
    },
  );

  test(
    'atomic feed preserves adjacent ticks and consumes effects once',
    () async {
      final harness = _buildHarness();
      addTearDown(harness.dispose);
      final image = await _singlePixelImage();
      addTearDown(image.dispose);
      final images = Images();
      addTearDown(images.clearCache);
      final impacts = SpellImpactRenderRegistry();
      await impacts.load(images);
      final world = Component();
      final replay = _ghostReplayBlob(levelId: LevelId.field);
      final base = harness.controller.snapshot;
      ActorFrameSnapshot snapshot(int tick, double x) => _copySnapshot(
        base,
        tick: tick,
        entities: [_entity(id: 101, kind: EntityKind.player, x: x, y: 20)],
      );
      final previous = snapshot(5, 10);
      final current = snapshot(6, 30);
      final events = <GameEvent>[
        SpellImpactEvent(
          tick: 6,
          impactId: SpellImpactId.fireExplosion,
          pos: const Vec2(20, 20),
        ),
      ];
      final frame = GhostRenderFrame(
        replayBlob: replay,
        previous: previous,
        current: current,
        events: events,
      );
      events.clear();
      final feed = ValueNotifier<GhostRenderFrame?>(frame);
      addTearDown(feed.dispose);
      final layer = GhostLayerSystem(
        controller: harness.controller,
        world: world,
        images: images,
        enemyRenderRegistry: EnemyRenderRegistry(),
        npcRenderRegistry: NpcRenderRegistry(),
        projectileRenderRegistry: ProjectileRenderRegistry(),
        spellImpactRenderRegistry: impacts,
        combatFeedbackTuning: const CombatFeedbackTuning(),
        ghostRenderListenable: feed,
      );
      layer.debugSetGhostRenderStateForTest(
        replayBlob: replay,
        playerAnimSet: _buildAnimSet(image),
      );
      layer.attachListeners();
      addTearDown(layer.detachListeners);
      layer.syncLayer(alpha: 0.5, cameraCenter: Vector2.zero());
      expect(world.children.whereType<PlayerView>().single.position.x, 20);
      layer.flushPendingSpellImpactEvents(cameraCenter: Vector2.zero());
      expect(
        world.children.whereType<CameraSpaceSnappedSpriteAnimation>(),
        hasLength(1),
      );
      feed.value = GhostRenderFrame(
        replayBlob: replay,
        previous: current,
        current: snapshot(7, 50),
        events: const [],
      );
      layer.syncLayer(alpha: 0.5, cameraCenter: Vector2.zero());
      layer.flushPendingSpellImpactEvents(cameraCenter: Vector2.zero());
      expect(world.children.whereType<PlayerView>().single.position.x, 40);
      expect(
        world.children.whereType<CameraSpaceSnappedSpriteAnimation>(),
        hasLength(1),
      );
      feed.value = null;
      expect(layer.debugHasGhostPlayerView, isFalse);
    },
  );

  test(
    'all NPC identities synchronize in live and ghost pools and retire cleanly',
    () async {
      final harness = _buildHarness();
      addTearDown(harness.dispose);
      final images = Images();
      addTearDown(images.clearCache);
      final npcs = NpcRenderRegistry();
      await npcs.load(images);
      final enemies = EnemyRenderRegistry();
      final projectiles = ProjectileRenderRegistry();
      final live = LiveWorldSyncSystem(
        controller: harness.controller,
        world: Component(),
        playerCharacter: testPlayerCharacter,
        enemyRenderRegistry: enemies,
        npcRenderRegistry: npcs,
        projectileRenderRegistry: projectiles,
        pickupRenderRegistry: PickupRenderRegistry(),
        combatFeedbackTuning: const CombatFeedbackTuning(),
      );
      final ghost = GhostLayerSystem(
        controller: harness.controller,
        world: Component(),
        images: images,
        enemyRenderRegistry: enemies,
        npcRenderRegistry: npcs,
        projectileRenderRegistry: projectiles,
        spellImpactRenderRegistry: SpellImpactRenderRegistry(),
        combatFeedbackTuning: const CombatFeedbackTuning(),
        ghostRenderListenable: null,
      );
      final actors = [
        for (final id in NpcId.values)
          EntityRenderSnapshot(
            id: 300 + id.index,
            kind: EntityKind.npc,
            npcId: id,
            pos: Vec2(100.0 + id.index * 100, 100),
            facing: Facing.left,
            anim: AnimKey.death,
            grounded: true,
            animFrame: 7,
            npcHealth: const NpcHealthSnapshot(
              hp100: 0,
              maxHp100: 3500,
              protected: false,
            ),
          ),
      ];
      live.syncActors(
        actors,
        prevById: {},
        alpha: 1,
        cameraCenter: Vector2.zero(),
      );
      expect(live.actorViews, hasLength(3));
      expect(
        live.actorViews.values.every(
          (v) => v.current == AnimKey.death && v.scale.x < 0,
        ),
        isTrue,
      );
      ghost.debugSetGhostRenderStateForTest(
        snapshot: _copySnapshot(
          harness.controller.snapshot,
          tick: 1,
          entities: actors,
        ),
        replayBlob: _ghostReplayBlob(levelId: LevelId.field),
        playerAnimSet: npcs.entryFor(NpcId.warrior)!.animSet,
      );
      ghost.syncLayer(alpha: 1, cameraCenter: Vector2.zero());
      expect(ghost.debugGhostNpcCount, 3);
      expect(ghost.debugGhostEnemyCount, 0);
      live.syncActors([], prevById: {}, alpha: 1, cameraCenter: Vector2.zero());
      ghost.clearViews();
      expect(live.actorViews, isEmpty);
      expect(ghost.debugGhostNpcCount, 0);
    },
  );

  test('ghost sync creates and clears player view across lifecycle', () async {
    final harness = _buildHarness();
    final image = await _singlePixelImage();
    final animSet = _buildAnimSet(image);
    try {
      final base = harness.controller.snapshot;
      final prevSnapshot = _copySnapshot(
        base,
        tick: base.tick + 1,
        entities: <EntityRenderSnapshot>[
          _entity(id: 101, kind: EntityKind.player, x: 10, y: 20),
        ],
      );
      final snapshot = _copySnapshot(
        base,
        tick: base.tick + 2,
        entities: <EntityRenderSnapshot>[
          _entity(id: 101, kind: EntityKind.player, x: 30, y: 20),
        ],
      );

      harness.game.debugSetGhostRenderStateForTest(
        snapshot: snapshot,
        prevSnapshot: prevSnapshot,
        replayBlob: _ghostReplayBlob(levelId: LevelId.field),
        playerAnimSet: animSet,
      );
      harness.game.debugSyncGhostLayerForTest(
        alpha: 0.5,
        cameraCenter: Vector2.zero(),
      );

      expect(harness.game.debugHasGhostPlayerView, isTrue);
      expect(harness.game.debugGhostPlayerEntityId, 101);
      expect(harness.game.debugGhostEnemyCount, 0);
      expect(harness.game.debugGhostProjectileCount, 0);

      harness.game.debugSetGhostRenderStateForTest(
        snapshot: null,
        prevSnapshot: null,
        replayBlob: null,
        playerAnimSet: null,
      );
      harness.game.debugSyncGhostLayerForTest();

      expect(harness.game.debugHasGhostPlayerView, isFalse);
      expect(harness.game.debugGhostPlayerEntityId, isNull);
      expect(harness.game.debugGhostEnemyCount, 0);
      expect(harness.game.debugGhostProjectileCount, 0);
    } finally {
      image.dispose();
      harness.dispose();
    }
  });

  test('ghost render scope excludes pickup-only snapshots', () async {
    final harness = _buildHarness();
    final image = await _singlePixelImage();
    final animSet = _buildAnimSet(image);
    try {
      final base = harness.controller.snapshot;
      final snapshot = _copySnapshot(
        base,
        tick: base.tick + 1,
        entities: <EntityRenderSnapshot>[
          _entity(
            id: 201,
            kind: EntityKind.pickup,
            x: 40,
            y: 16,
            pickupVariant: PickupVariant.collectible,
          ),
        ],
      );

      harness.game.debugSetGhostRenderStateForTest(
        snapshot: snapshot,
        prevSnapshot: null,
        replayBlob: _ghostReplayBlob(levelId: LevelId.field),
        playerAnimSet: animSet,
      );
      harness.game.debugSyncGhostLayerForTest(cameraCenter: Vector2.zero());

      expect(harness.game.debugHasGhostPlayerView, isFalse);
      expect(harness.game.debugGhostEnemyCount, 0);
      expect(harness.game.debugGhostProjectileCount, 0);
    } finally {
      image.dispose();
      harness.dispose();
    }
  });

  test(
    'ghost layer disable logs context and prevents further ghost rendering',
    () async {
      final harness = _buildHarness();
      final image = await _singlePixelImage();
      final animSet = _buildAnimSet(image);
      final base = harness.controller.snapshot;
      final snapshot = _copySnapshot(
        base,
        tick: base.tick + 1,
        entities: <EntityRenderSnapshot>[
          _entity(id: 301, kind: EntityKind.player, x: 16, y: 18),
        ],
      );
      final logs = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          logs.add(message);
        }
      };

      try {
        harness.game.debugSetGhostRenderStateForTest(
          snapshot: snapshot,
          prevSnapshot: null,
          replayBlob: _ghostReplayBlob(levelId: LevelId.field),
          playerAnimSet: animSet,
        );
        harness.game.debugDisableGhostLayerForTest(
          'test-disable',
          details: 'simulated failure',
        );

        expect(harness.game.debugGhostLayerDisabled, isTrue);
        expect(harness.game.debugGhostLayerDisableReason, 'test-disable');
        expect(
          logs.any(
            (line) =>
                line.contains('Ghost layer disabled: reason=test-disable') &&
                line.contains('runId=') &&
                line.contains('tick=') &&
                line.contains('replayRunSessionId=ghost_run_1') &&
                line.contains('replayBoardId=board_1') &&
                line.contains('details=simulated failure'),
          ),
          isTrue,
        );

        harness.game.debugSyncGhostLayerForTest(cameraCenter: Vector2.zero());
        expect(harness.game.debugHasGhostPlayerView, isFalse);
        expect(harness.game.debugGhostEnemyCount, 0);
        expect(harness.game.debugGhostProjectileCount, 0);
      } finally {
        debugPrint = previousDebugPrint;
        image.dispose();
        harness.dispose();
      }
    },
  );
}

class _Harness {
  _Harness({
    required this.controller,
    required this.projectileAim,
    required this.meleeAim,
    required this.game,
  });

  final GameController controller;
  final ValueNotifier<AimPreviewState> projectileAim;
  final ValueNotifier<AimPreviewState> meleeAim;
  final RunnerFlameGame game;

  void dispose() {
    game.onRemove();
    game.onDispose();
    projectileAim.dispose();
    meleeAim.dispose();
    controller.dispose();
  }
}

_Harness _buildHarness() {
  final core = GameCore(
    levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
    playerCharacter: testPlayerCharacter,
    seed: 42,
  );
  final controller = GameController(core: core);
  final input = RunnerInputRouter(controller: controller);
  final projectileAim = ValueNotifier<AimPreviewState>(
    AimPreviewState.inactive,
  );
  final meleeAim = ValueNotifier<AimPreviewState>(AimPreviewState.inactive);
  final game = RunnerFlameGame(
    controller: controller,
    input: input,
    projectileAimPreview: projectileAim,
    meleeAimPreview: meleeAim,
    playerCharacter: testPlayerCharacter,
  );
  return _Harness(
    controller: controller,
    projectileAim: projectileAim,
    meleeAim: meleeAim,
    game: game,
  );
}

ActorFrameSnapshot _copySnapshot(
  GameStateSnapshot base, {
  required int tick,
  required List<EntityRenderSnapshot> entities,
}) {
  return ActorFrameSnapshot(
    tick: tick,
    distance: base.distance,
    gameOver: base.gameOver,
    entities: entities,
  );
}

EntityRenderSnapshot _entity({
  required int id,
  required EntityKind kind,
  required double x,
  required double y,
  int? pickupVariant,
}) {
  return EntityRenderSnapshot(
    id: id,
    kind: kind,
    pos: Vec2(x, y),
    facing: Facing.right,
    anim: AnimKey.idle,
    grounded: true,
    pickupVariant: pickupVariant,
  );
}

ReplayBlobV1 _ghostReplayBlob({required LevelId levelId}) {
  return ReplayBlobV1.withComputedDigest(
    runSessionId: 'ghost_run_1',
    boardId: 'board_1',
    boardKey: BoardKey(
      mode: RunMode.competitive,
      levelId: 'field',
      windowId: '2026-03',
      rulesetVersion: 'rules-v1',
      scoreVersion: 'score-v1',
    ),
    tickHz: 60,
    seed: 42,
    levelId: levelId.name,
    playerCharacterId: 'eloise',
    loadoutSnapshot: const <String, Object?>{
      'mask': 0,
      'mainWeaponId': 'debugSword',
      'offhandWeaponId': 'none',
      'spellBookId': 'emptyBook',
      'projectileSlotSpellId': 'iceBolt',
      'accessoryId': 'none',
      'abilityPrimaryId': 'slash',
      'abilitySecondaryId': 'parry',
      'abilityProjectileId': 'projectileBasic',
      'abilitySpellId': 'spellBasic',
      'abilityMobilityId': 'dash',
      'abilityJumpId': 'jump',
    },
    totalTicks: 0,
    commandStream: const <ReplayCommandFrameV1>[],
  );
}

SpriteAnimSet _buildAnimSet(ui.Image image) {
  final animation = SpriteAnimation(<SpriteAnimationFrame>[
    SpriteAnimationFrame(Sprite(image), 0.1),
  ]);
  return SpriteAnimSet(
    animations: <AnimKey, SpriteAnimation>{AnimKey.idle: animation},
    stepTimeSecondsByKey: const <AnimKey, double>{AnimKey.idle: 0.1},
    oneShotKeys: const <AnimKey>{},
    frameSize: Vector2.all(1.0),
  );
}

Future<ui.Image> _singlePixelImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), paint);
  final picture = recorder.endRecording();
  return picture.toImage(1, 1);
}
