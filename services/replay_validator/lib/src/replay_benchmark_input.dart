import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/snapshots/enums.dart';

import 'replay_benchmark_terrain.dart';

/// Records fixture inputs from read-only Core state; never changes movement rules.
///
/// Use one instance per run and call [nextFrame] once before each fixed tick.
/// These decisions belong only to recording, outside the timed replay loop.
final class ReplayBenchmarkInput {
  ReplayBenchmarkInput(this.levelId);

  final LevelId levelId;
  bool _wasGrounded = true;
  bool _pressedJumpLastTick = false;
  late final _terrain = ReplayBenchmarkTerrain();
  double? _progressX;
  int _progressTick = 0;
  bool _retreating = false;
  bool _retreatWasAirborne = false;
  int _retreatStartedTick = 0;

  /// Emits movement and jump presses for [tick] from the preceding tick's state.
  ReplayCommandFrameV1 nextFrame(GameCore core, {required int tick}) {
    final grounded = core.playerGrounded;
    if (levelId == LevelId.forest) {
      _progressX ??= core.playerPosX;
      if (core.playerPosX >= _progressX! + 4) {
        _progressX = core.playerPosX;
        _progressTick = tick;
      }
      if (_retreating) {
        _retreatWasAirborne |= !grounded;
        if ((_retreatWasAirborne && grounded) ||
            tick - _retreatStartedTick >= 2 * core.tickHz) {
          _retreating = false;
          _progressTick = tick;
        } else {
          _wasGrounded = grounded;
          _pressedJumpLastTick = false;
          return ReplayCommandFrameV1(
            tick: tick,
            moveAxis: -0.5,
            pressedMask: 0,
          );
        }
      }
      // Two seconds without new ground: recover a missed elevated foothold
      // using an ordinary half-speed backward jump before the stall gate fires.
      if (grounded &&
          core.buildSnapshot().hud.canAffordJump &&
          tick - _progressTick >= 2 * core.tickHz &&
          _terrain.canRetreat(core, core.buildTerrainPlayerDebugSnapshot()!)) {
        _retreating = true;
        _retreatWasAirborne = false;
        _retreatStartedTick = tick;
        _wasGrounded = grounded;
        _pressedJumpLastTick = true;
        return ReplayCommandFrameV1(
          tick: tick,
          moveAxis: -0.5,
          pressedMask: ReplayCommandFrameV1.pressedJumpBit,
        );
      }
    }
    final jump = switch (levelId) {
      LevelId.forest || LevelId.field => _terrainJump(core),
      _ => false,
    };
    _wasGrounded = grounded;
    _pressedJumpLastTick = jump;
    return ReplayCommandFrameV1(
      tick: tick,
      moveAxis: 1,
      pressedMask: jump ? ReplayCommandFrameV1.pressedJumpBit : 0,
    );
  }

  bool _terrainJump(GameCore core) {
    if (!core.playerGrounded) {
      // Walking off an uphill support can retain upward velocity. The prior
      // input distinguishes that coyote jump from a jump already requested.
      if (_wasGrounded && !_pressedJumpLastTick) return true;
      if (core.playerVelY < 0) return false;
      return core.buildActorFrameSnapshot().entities.any(
        (entity) => entity.kind == EntityKind.player && entity.isSwimming,
      );
    }

    final contact = core.buildTerrainPlayerDebugSnapshot()!;
    if (contact.hitRight) return true;
    if (levelId == LevelId.forest && _terrain.shouldJump(core, contact)) {
      return true;
    }
    final terrain = core.buildSnapshot().stagedTerrainRenderSnapshot!;
    // World units before a floor ledge: clear raised stepping stones while
    // retaining enough horizontal jump range for Field's ordinary gaps.
    const ledgeLead = 30 * terrainPhysicsTicksPerWorldUnit;
    for (final edge in terrain.edges) {
      final remaining = edge.end.xTicks - contact.capsuleCenterXTicks;
      final support = contact.supportEdgeId;
      if (edge.outwardNormal.y >= 0 ||
          remaining < 0 ||
          remaining > ledgeLead ||
          support == null ||
          edge.id.chunkIndex != support.chunkIndex ||
          edge.id.chunkKey != support.chunkKey ||
          edge.id.placementKey != support.placementKey ||
          edge.id.shapeId != support.shapeId ||
          edge.id.localEdgeIndex != support.localEdgeIndex) {
        continue;
      }
      // A continuing floor at a chunk seam is not a drop. Direct terrain
      // edges exclude render-only pit fills; prefab walls use contact above.
      if (terrain.edges.any(
        (next) =>
            next.id == edge.nextId &&
            next.outwardNormal.x > 0 &&
            next.outwardNormal.y >= 0,
      )) {
        return levelId != LevelId.forest ||
            _terrain.canJumpForward(core, contact);
      }
    }
    return false;
  }
}
