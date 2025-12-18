import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/collision/static_world_geometry.dart';
import 'package:walkscape_runner/core/commands/command.dart';
import 'package:walkscape_runner/core/contracts/v0_render_contract.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/math/vec2.dart';
import 'package:walkscape_runner/core/tuning/v0_movement_tuning.dart';

void _tick(
  GameCore core, {
  double axis = 0,
}) {
  final targetTick = core.tick + 1;
  core.applyCommands([
    if (axis != 0) MoveAxisCommand(tick: targetTick, axis: axis),
  ]);
  core.stepOneTick();
}

void main() {
  test('lands on a one-way platform above the ground', () {
    const topY = 180.0;
    const r = 8.0;

    final core = GameCore(
      seed: 1,
      tickHz: v0DefaultTickHz,
      movementTuning: const V0MovementTuning(playerRadius: r),
      staticWorldGeometry: const StaticWorldGeometry(
        groundPlane: StaticGroundPlane(topY: v0GroundTopY * 1.0),
        solids: <StaticSolid>[
          StaticSolid(minX: 0, minY: topY, maxX: 240, maxY: topY + 16),
        ],
      ),
    );

    core.playerPos = const Vec2(120, 40);
    core.playerVel = const Vec2(0, 0);

    // Clear the initial grounded state inherited from spawn-on-ground.
    _tick(core);
    expect(core.playerGrounded, isFalse);

    var safety = 180;
    while (!core.playerGrounded && safety > 0) {
      _tick(core);
      safety -= 1;
    }

    expect(safety, greaterThan(0));
    expect(core.playerPos.y, closeTo(topY - r, 1e-9));
    expect(core.playerVel.y, closeTo(0, 1e-9));
    expect(core.playerPos.y, lessThan(v0GroundTopY.toDouble() - r));
  });

  test('one-way platform does not block upward motion from below', () {
    const topY = 180.0;
    const r = 8.0;

    final core = GameCore(
      seed: 1,
      tickHz: v0DefaultTickHz,
      movementTuning: const V0MovementTuning(playerRadius: r),
      staticWorldGeometry: const StaticWorldGeometry(
        groundPlane: StaticGroundPlane(topY: v0GroundTopY * 1.0),
        solids: <StaticSolid>[
          StaticSolid(minX: 0, minY: topY, maxX: 240, maxY: topY + 16),
        ],
      ),
    );

    final startY = topY + 40;
    core.playerPos = Vec2(120, startY);
    core.playerVel = const Vec2(0, -800);

    _tick(core);

    expect(core.playerPos.y, lessThan(startY));
    expect(core.playerPos.y, isNot(closeTo(topY - r, 1e-9)));
  });

  test('walking off a platform clears grounded before hitting the ground', () {
    const topY = 180.0;
    const r = 8.0;
    const platformMaxX = 240.0;

    final core = GameCore(
      seed: 1,
      tickHz: v0DefaultTickHz,
      movementTuning: const V0MovementTuning(playerRadius: r),
      staticWorldGeometry: const StaticWorldGeometry(
        groundPlane: StaticGroundPlane(topY: v0GroundTopY * 1.0),
        solids: <StaticSolid>[
          StaticSolid(minX: 0, minY: topY, maxX: platformMaxX, maxY: topY + 16),
        ],
      ),
    );

    // Start on top of the platform.
    core.playerPos = const Vec2(120, topY - r);
    core.playerVel = const Vec2(0, 0);

    // Let one tick settle the grounded state (gravity pushes down slightly).
    _tick(core);
    expect(core.playerGrounded, isTrue);
    expect(core.playerPos.y, closeTo(topY - r, 1e-6));

    // Walk right until the player's AABB no longer overlaps the platform.
    var leftPlatform = false;
    var sawAirborne = false;
    var safety = 600;
    while (safety > 0 && !sawAirborne) {
      _tick(core, axis: 1);
      safety -= 1;

      if (!leftPlatform && core.playerPos.x > platformMaxX + r + 1) {
        leftPlatform = true;
      }
      if (leftPlatform && !core.playerGrounded) {
        sawAirborne = true;
      }
    }

    expect(safety, greaterThan(0));
    expect(leftPlatform, isTrue);
    expect(sawAirborne, isTrue);
    expect(core.playerPos.y, greaterThan(topY - r));
    expect(core.playerPos.y, lessThan(v0GroundTopY.toDouble() - r));
  });
}
