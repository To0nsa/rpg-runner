import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/collision/static_world_geometry.dart';
import 'package:walkscape_runner/core/commands/command.dart';
import 'package:walkscape_runner/core/contracts/render_contract.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/players/player_catalog.dart';
import 'package:walkscape_runner/core/tuning/movement_tuning.dart';
import 'package:walkscape_runner/core/tuning/track_tuning.dart';

import '../test_tunings.dart';

void _tick(GameCore core, {double axis = 0}) {
  final targetTick = core.tick + 1;
  core.applyCommands([
    if (axis != 0) MoveAxisCommand(tick: targetTick, axis: axis),
  ]);
  core.stepOneTick();
}

void main() {
  test('walk into obstacle wall stops horizontal motion', () {
    const r = 8.0;
    const obstacleMinX = 120.0;
    const obstacleMaxX = 140.0;

    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
      trackTuning: const TrackTuning(enabled: false),
      movementTuning: const MovementTuning(playerRadius: r),
      staticWorldGeometry: const StaticWorldGeometry(
        groundPlane: StaticGroundPlane(topY: groundTopY * 1.0),
        solids: <StaticSolid>[
          StaticSolid(
            minX: obstacleMinX,
            minY: 220,
            maxX: obstacleMaxX,
            maxY: groundTopY * 1.0,
            sides: StaticSolid.sideAll,
            oneWayTop: false,
          ),
        ],
      ),
    );

    // Place the player left of the obstacle so walking right exercises the wall.
    core.setPlayerPosXY(obstacleMinX - r - 40, core.playerPosY);
    core.setPlayerVelXY(0, core.playerVelY);
    _tick(core);

    final expectedStopX = obstacleMinX - r;

    var safety = 240;
    while (core.playerPosX < expectedStopX - 1 && safety > 0) {
      _tick(core, axis: 1);
      safety -= 1;
    }
    expect(safety, greaterThan(0));

    // Keep pushing; we should not tunnel through.
    for (var i = 0; i < 30; i += 1) {
      _tick(core, axis: 1);
    }

    expect(core.playerPosX, closeTo(expectedStopX, 1e-6));
    expect(core.playerVelX, closeTo(0, 1e-9));
  });

  test('Body.sideMask can disable right-side collision', () {
    const r = 8.0;
    const obstacleMinX = 120.0;
    const obstacleMaxX = 140.0;

    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
      trackTuning: const TrackTuning(enabled: false),
      movementTuning: const MovementTuning(playerRadius: r),
      playerCatalog: const PlayerCatalog(
        bodyTemplate: BodyDef(sideMask: BodyDef.sideLeft),
      ),
      staticWorldGeometry: const StaticWorldGeometry(
        groundPlane: StaticGroundPlane(topY: groundTopY * 1.0),
        solids: <StaticSolid>[
          StaticSolid(
            minX: obstacleMinX,
            minY: 220,
            maxX: obstacleMaxX,
            maxY: groundTopY * 1.0,
            sides: StaticSolid.sideAll,
            oneWayTop: false,
          ),
        ],
      ),
    );

    // Place the player left of the obstacle so walking right attempts to collide.
    core.setPlayerPosXY(obstacleMinX - r - 40, core.playerPosY);
    core.setPlayerVelXY(0, core.playerVelY);
    _tick(core);

    // Walk right for a while; without right-side collision, we should pass through.
    for (var i = 0; i < 120; i += 1) {
      _tick(core, axis: 1);
    }

    expect(core.playerPosX, greaterThan(obstacleMaxX + r + 5));
  });

  test('walking into obstacle from the right stops on its right wall', () {
    const r = 8.0;
    const obstacleMinX = 120.0;
    const obstacleMaxX = 140.0;

    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
      trackTuning: const TrackTuning(enabled: false),
      movementTuning: const MovementTuning(playerRadius: r),
      staticWorldGeometry: const StaticWorldGeometry(
        groundPlane: StaticGroundPlane(topY: groundTopY * 1.0),
        solids: <StaticSolid>[
          StaticSolid(
            minX: obstacleMinX,
            minY: 220,
            maxX: obstacleMaxX,
            maxY: groundTopY * 1.0,
            sides: StaticSolid.sideAll,
            oneWayTop: false,
          ),
        ],
      ),
    );

    // Place the player to the right of the obstacle.
    core.setPlayerPosXY(obstacleMaxX + r + 40, core.playerPosY);
    core.setPlayerVelXY(0, core.playerVelY);

    // Clear spawn grounded state consistency (pos override doesn't change it).
    _tick(core);

    final expectedStopX = obstacleMaxX + r;
    for (var i = 0; i < 180; i += 1) {
      _tick(core, axis: -1);
    }

    expect(core.playerPosX, closeTo(expectedStopX, 1e-6));
    expect(core.playerVelX, closeTo(0, 1e-9));
  });
}
