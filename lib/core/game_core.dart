// Authoritative, deterministic simulation layer (pure Dart).
//
// This is the "truth" of the game: it applies tick-stamped commands, advances
// the simulation by fixed ticks, and produces snapshots/events for the
// renderer/UI. It must not import Flutter or Flame.
import 'dart:math';

import 'commands/command.dart';
import 'contracts/v0_render_contract.dart';
import 'math/vec2.dart';
import 'snapshots/enums.dart';
import 'snapshots/entity_render_snapshot.dart';
import 'snapshots/game_state_snapshot.dart';
import 'snapshots/player_hud_snapshot.dart';
import 'tuning/v0_movement_tuning.dart';

/// Minimal placeholder `GameCore` used to validate architecture wiring.
///
/// This will be replaced by the full ECS/systems implementation in later
/// milestones. The core invariants remain: fixed ticks, command-driven input,
/// deterministic state updates, snapshot output.
class GameCore {
  GameCore({
    required this.seed,
    this.tickHz = v0DefaultTickHz,
    V0MovementTuning movementTuning = const V0MovementTuning(),
  }) : _movement = V0MovementTuningDerived.from(movementTuning, tickHz: tickHz);

  /// Seed used for deterministic generation/RNG.
  final int seed;

  /// Fixed simulation tick frequency.
  final int tickHz;

  final V0MovementTuningDerived _movement;

  /// Current simulation tick.
  int tick = 0;

  /// Whether simulation should advance.
  bool paused = false;

  /// Run progression metric (placeholder).
  double distance = 0;

  /// Player world position (placeholder).
  late Vec2 playerPos = Vec2(
    80,
    v0GroundTopY.toDouble() - _movement.base.playerRadius,
  );

  /// Player world velocity (placeholder).
  Vec2 playerVel = const Vec2(0, 0);

  /// Player facing direction (placeholder).
  Facing playerFacing = Facing.right;

  // Current input state for the tick being simulated.
  double _moveAxis = 0;
  bool _jumpPressed = false;
  bool _dashPressed = false;

  // Movement state (V0).
  bool _grounded = true;
  int _coyoteTicksLeft = 0;
  int _jumpBufferTicksLeft = 0;

  int _dashTicksLeft = 0;
  int _dashCooldownTicksLeft = 0;
  double _dashDirX = 1;

  /// Applies all commands scheduled for the current tick.
  ///
  /// In the final architecture, commands are the only mechanism for the UI to
  /// influence the simulation.
  void applyCommands(List<Command> commands) {
    // Reset tick-scoped input so "missing commands" does not create stuck input.
    _moveAxis = 0;
    _jumpPressed = false;
    _dashPressed = false;

    for (final command in commands) {
      switch (command) {
        case MoveAxisCommand(:final axis):
          _moveAxis = axis.clamp(-1.0, 1.0);
          if (_dashTicksLeft == 0) {
            if (_moveAxis < 0) {
              playerFacing = Facing.left;
            } else if (_moveAxis > 0) {
              playerFacing = Facing.right;
            }
          }
        case JumpPressedCommand():
          _jumpPressed = true;
        case DashPressedCommand():
          _dashPressed = true;
        case AttackPressedCommand():
          break;
      }
    }
  }

  /// Advances the simulation by exactly one fixed tick.
  void stepOneTick() {
    if (paused) return;

    tick += 1;

    _tickMovement();
  }

  void _tickMovement() {
    final dt = _movement.dtSeconds;
    final tuning = _movement.base;

    // Tick-based timers.
    if (_dashCooldownTicksLeft > 0) _dashCooldownTicksLeft -= 1;
    if (_dashTicksLeft > 0) _dashTicksLeft -= 1;

    if (_jumpBufferTicksLeft > 0) _jumpBufferTicksLeft -= 1;

    final wasGrounded = _grounded;
    if (wasGrounded) {
      _coyoteTicksLeft = _movement.coyoteTicks;
    } else if (_coyoteTicksLeft > 0) {
      _coyoteTicksLeft -= 1;
    }

    // Convert button edge-trigger into a short jump buffer window.
    if (_jumpPressed) {
      _jumpBufferTicksLeft = _movement.jumpBufferTicks;
    }

    // Dash request (edge-triggered).
    if (_dashPressed) {
      _tryStartDash();
    }

    final dashing = _dashTicksLeft > 0;

    if (dashing) {
      // Dash: constant horizontal speed, no gravity, and zero vertical velocity.
      playerVel = Vec2(_dashDirX * tuning.dashSpeedX, 0);
    } else {
      playerVel = playerVel.withX(
        _applyHorizontalMove(playerVel.x, _moveAxis, dt),
      );

      // Jump attempt before gravity (mirrors the SFML sample: jump sets vY, then gravity applies).
      if (_jumpBufferTicksLeft > 0 && (wasGrounded || _coyoteTicksLeft > 0)) {
        playerVel = playerVel.withY(-tuning.jumpSpeed);
        _jumpBufferTicksLeft = 0;
        _coyoteTicksLeft = 0;
      }

      // Gravity.
      playerVel = playerVel.withY(playerVel.y + tuning.gravityY * dt);
    }

    // Clamp speeds.
    final clampedVelX = playerVel.x
        .clamp(-tuning.maxVelX, tuning.maxVelX)
        .toDouble();
    final clampedVelY = playerVel.y
        .clamp(-tuning.maxVelY, tuning.maxVelY)
        .toDouble();
    playerVel = Vec2(clampedVelX, clampedVelY);

    // Integrate position.
    playerPos = playerPos + playerVel.scale(dt);

    // V0 ground collision: keep the player's bottom sitting on the ground band top.
    final floorY = v0GroundTopY.toDouble() - tuning.playerRadius;
    if (playerPos.y > floorY) {
      playerPos = playerPos.withY(floorY);
      playerVel = playerVel.withY(0);
      _grounded = true;
    } else {
      _grounded = false;
    }

    // Progress metric: count only forward movement.
    distance += max(0.0, playerVel.x) * dt;
  }

  double _applyHorizontalMove(double velocityX, double axis, double dt) {
    final tuning = _movement.base;
    if (axis != 0) {
      final desiredX = axis * tuning.maxSpeedX;
      final deltaX = desiredX - velocityX;
      final maxDelta = tuning.accelerationX * dt;
      if (deltaX.abs() > maxDelta) {
        return velocityX + (deltaX > 0 ? maxDelta : -maxDelta);
      }
      return desiredX;
    }

    final speedX = velocityX.abs();
    if (speedX <= 0) return 0;
    final drop = tuning.decelerationX * dt;
    if (speedX <= drop || speedX <= tuning.minMoveSpeed) {
      return 0;
    }
    return velocityX + (velocityX > 0 ? -drop : drop);
  }

  void _tryStartDash() {
    if (_dashTicksLeft > 0) return;
    if (_dashCooldownTicksLeft > 0) return;

    final dirX = _moveAxis != 0
        ? (_moveAxis > 0 ? 1.0 : -1.0)
        : (playerFacing == Facing.right ? 1.0 : -1.0);

    _dashDirX = dirX;
    playerFacing = dirX > 0 ? Facing.right : Facing.left;

    _dashTicksLeft = _movement.dashDurationTicks;
    _dashCooldownTicksLeft = _movement.dashCooldownTicks;

    // Reset vertical speed so dash doesn't inherit jump/fall motion.
    playerVel = playerVel.withY(0);
  }

  /// Builds an immutable snapshot for render/UI consumption.
  GameStateSnapshot buildSnapshot() {
    final tuning = _movement.base;
    final dashing = _dashTicksLeft > 0;
    final onGround = _grounded;

    final AnimKey anim;
    if (dashing) {
      anim = AnimKey.run;
    } else if (!onGround) {
      anim = playerVel.y < 0 ? AnimKey.jump : AnimKey.fall;
    } else if (playerVel.x.abs() > tuning.minMoveSpeed) {
      anim = AnimKey.run;
    } else {
      anim = AnimKey.idle;
    }

    return GameStateSnapshot(
      tick: tick,
      seed: seed,
      distance: distance,
      paused: paused,
      hud: const PlayerHudSnapshot(
        hp: 100,
        hpMax: 100,
        mana: 50,
        manaMax: 50,
        endurance: 100,
        enduranceMax: 100,
        score: 0,
        coins: 0,
      ),
      entities: [
        EntityRenderSnapshot(
          id: 1,
          kind: EntityKind.player,
          pos: playerPos,
          vel: playerVel,
          facing: playerFacing,
          anim: anim,
        ),
      ],
    );
  }
}
