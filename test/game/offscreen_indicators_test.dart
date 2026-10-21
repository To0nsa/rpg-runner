import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:rpg_runner/game/spatial/offscreen_indicators.dart';
import 'package:rpg_runner/game/spatial/world_view_transform.dart';

import '../../packages/runner_core/test/test_support/boss_victory_fixture.dart';

const camera = WorldViewTransform(
  cameraCenterX: 300,
  cameraCenterY: 135,
  viewWidth: 600,
  viewHeight: 270,
);
const visible = Rect.fromLTWH(0, 0, 600, 270);

OffscreenIndicatorTarget target(
  int id,
  double x,
  double y, {
  bool player = false,
}) => OffscreenIndicatorTarget(
  id: id,
  isPlayer: player,
  body: Rect.fromCenter(center: Offset(x, y), width: 20, height: 20),
);

OffscreenIndicatorFrame frame(
  List<OffscreenIndicatorTarget> targets, {
  int runId = 1,
}) => OffscreenIndicatorFrame(runId: runId, camera: camera, targets: targets);

void main() {
  test('feed excludes other entity kinds, death poses and ended runs', () {
    final base = bossVictoryCore().buildSnapshot();
    EntityRenderSnapshot actor(int id, EntityKind kind, AnimKey anim) =>
        EntityRenderSnapshot(
          id: id,
          kind: kind,
          pos: const Vec2(-50, 100),
          facing: Facing.right,
          anim: anim,
          grounded: true,
        );
    GameStateSnapshot snapshot({bool ended = false}) => GameStateSnapshot(
      tick: base.tick,
      runId: base.runId,
      seed: base.seed,
      levelIdentity: base.levelIdentity,
      visualThemeId: base.visualThemeId,
      distance: base.distance,
      paused: false,
      gameOver: ended,
      camera: base.camera,
      hud: base.hud,
      staticPrefabSprites: const [],
      entities: [
        actor(1, EntityKind.player, AnimKey.run),
        actor(2, EntityKind.enemy, AnimKey.spawn),
        actor(3, EntityKind.enemy, AnimKey.death),
        actor(4, EntityKind.enemy, AnimKey.casterDeath),
        actor(5, EntityKind.npc, AnimKey.run),
        actor(6, EntityKind.projectile, AnimKey.idle),
      ],
    );
    final live = OffscreenIndicatorFrame.fromSnapshots(
      current: snapshot(),
      previousById: const {},
      alpha: .5,
      camera: camera,
    );
    expect(live.targets.map((e) => e.id), [1, 2]);
    expect(live.targets.first.body.center, const Offset(-50, 100));
    final ended = OffscreenIndicatorFrame.fromSnapshots(
      current: snapshot(ended: true),
      previousById: const {},
      alpha: .5,
      camera: camera,
    );
    expect(ended.targets, isEmpty);
  });

  test(
    'left, top and corner get one marker each; visible/right/bottom do not',
    () {
      final result = OffscreenIndicatorProjector().project(
        frame([
          target(1, -35, 100, player: true),
          target(2, 200, -60),
          target(3, -85, -110),
          target(4, 100, 100),
          target(5, 650, 100),
          target(6, 200, 300),
          target(7, -5, 100), // Part of the body is still visible.
        ]),
        visible,
      );
      expect(result.map((e) => e.id), [1, 2, 3]);
      expect(result.map((e) => e.edge), [
        OffscreenIndicatorEdge.left,
        OffscreenIndicatorEdge.top,
        OffscreenIndicatorEdge.topLeft,
      ]);
      expect(result.map((e) => e.distanceMeters), [1, 2, 5]);
      expect(result.map((e) => e.anchor), [
        const Offset(0, 100),
        const Offset(200, 0),
        Offset.zero,
      ]);
      expect(result.first.isPlayer, isTrue);
    },
  );

  test(
    'two-unit entry buffer retains an existing marker until body touches view',
    () {
      final projector = OffscreenIndicatorProjector();
      List<OffscreenIndicator> at(double x) =>
          projector.project(frame([target(1, x, 100)]), visible);
      expect(at(-11), isEmpty);
      expect(at(-12), hasLength(1));
      expect(at(-10.5), hasLength(1));
      expect(at(-10), isEmpty);
      expect(at(-11), isEmpty);
    },
  );

  test(
    'removed entities and a new run cannot inherit visibility hysteresis',
    () {
      final projector = OffscreenIndicatorProjector();
      expect(
        projector.project(frame([target(1, -20, 100)]), visible),
        hasLength(1),
      );
      expect(projector.project(frame([]), visible), isEmpty);
      expect(projector.project(frame([target(1, -11, 100)]), visible), isEmpty);
      projector.project(frame([target(1, -20, 100)]), visible);
      expect(
        projector.project(frame([target(1, -11, 100)], runId: 2), visible),
        isEmpty,
      );
    },
  );

  test('camera motion changes distance without moving actors', () {
    final projector = OffscreenIndicatorProjector();
    final actors = frame([target(1, 0, 100)]);
    expect(projector.project(actors, visible), isEmpty);
    final result = projector.project(
      actors,
      visible.shift(const Offset(35, 0)),
    );
    expect(result.single.distanceMeters, 1);
  });

  test(
    'frame samples current live actors and interpolates known positions',
    () {
      final core = bossVictoryCore();
      final current = core.buildSnapshot();
      final player = current.playerEntity!;
      final previous = EntityRenderSnapshot(
        id: player.id,
        kind: EntityKind.player,
        pos: Vec2(player.pos.x - 100, player.pos.y - 40),
        facing: Facing.right,
        anim: AnimKey.idle,
        grounded: true,
      );
      final sampled = OffscreenIndicatorFrame.fromSnapshots(
        current: current,
        previousById: {player.id: previous},
        alpha: .25,
        camera: camera,
      );
      final body = sampled.targets.singleWhere((e) => e.isPlayer).body;
      expect(body.center, Offset(player.pos.x - 75, player.pos.y - 30));
      expect(body.width, closeTo(player.size!.x, 1e-9));
      expect(body.height, closeTo(player.size!.y, 1e-9));
      expect(
        sampled.targets.every(
          (e) => current.entities.any(
            (actor) =>
                actor.id == e.id &&
                (actor.kind == EntityKind.player ||
                    actor.kind == EntityKind.enemy) &&
                actor.anim != AnimKey.death &&
                actor.anim != AnimKey.casterDeath,
          ),
        ),
        isTrue,
      );
    },
  );
}
