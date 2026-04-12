import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:rpg_runner/game/components/sprite_anim/sprite_anim_set.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/aim_preview.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';
import 'package:rpg_runner/game/runner_flame_game.dart';

import '../support/test_level.dart';
import '../test_tunings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
          _entity(
            id: 101,
            kind: EntityKind.player,
            x: 10,
            y: 20,
          ),
        ],
      );
      final snapshot = _copySnapshot(
        base,
        tick: base.tick + 2,
        entities: <EntityRenderSnapshot>[
          _entity(
            id: 101,
            kind: EntityKind.player,
            x: 30,
            y: 20,
          ),
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

  test('ghost layer disable logs context and prevents further ghost rendering', () async {
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
  });
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
  final projectileAim = ValueNotifier<AimPreviewState>(AimPreviewState.inactive);
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

GameStateSnapshot _copySnapshot(
  GameStateSnapshot base, {
  required int tick,
  required List<EntityRenderSnapshot> entities,
}) {
  return GameStateSnapshot(
    tick: tick,
    runId: base.runId,
    seed: base.seed,
    levelId: base.levelId,
    visualThemeId: base.visualThemeId,
    distance: base.distance,
    paused: base.paused,
    gameOver: base.gameOver,
    camera: base.camera,
    hud: base.hud,
    entities: entities,
    staticSolids: base.staticSolids,
    groundSurfaces: base.groundSurfaces,
    staticPrefabSprites: base.staticPrefabSprites,
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
    boardKey: const BoardKey(
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
