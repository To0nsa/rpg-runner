// Authoritative, deterministic simulation layer (pure Dart).
//
// This is the "truth" of the game: it applies tick-stamped commands, advances
// the simulation by fixed ticks, and produces snapshots/events for the
// renderer/UI. It must not import Flutter or Flame.
import 'commands/command.dart';
import 'contracts/v0_render_contract.dart';
import 'math/vec2.dart';
import 'snapshots/enums.dart';
import 'snapshots/entity_render_snapshot.dart';
import 'snapshots/game_state_snapshot.dart';
import 'snapshots/player_hud_snapshot.dart';

/// Minimal placeholder `GameCore` used to validate architecture wiring.
///
/// This will be replaced by the full ECS/systems implementation in later
/// milestones. The core invariants remain: fixed ticks, command-driven input,
/// deterministic state updates, snapshot output.
class GameCore {
  GameCore({required this.seed});

  /// Seed used for deterministic generation/RNG.
  final int seed;

  /// Current simulation tick.
  int tick = 0;

  /// Whether simulation should advance.
  bool paused = false;

  /// Run progression metric (placeholder).
  double distance = 0;

  /// Player world position (placeholder).
  Vec2 playerPos = Vec2(80, v0GroundTopY - 8);

  /// Player world velocity (placeholder).
  Vec2 playerVel = const Vec2(1, 0);

  /// Player facing direction (placeholder).
  Facing playerFacing = Facing.right;

  /// Applies all commands scheduled for the current tick.
  ///
  /// In the final architecture, commands are the only mechanism for the UI to
  /// influence the simulation.
  void applyCommands(List<Command> commands) {
    for (final command in commands) {
      switch (command) {
        case MoveAxisCommand(:final axis):
          playerVel = Vec2(axis, playerVel.y);
          if (axis < 0) {
            playerFacing = Facing.left;
          } else if (axis > 0) {
            playerFacing = Facing.right;
          }
        case JumpPressedCommand():
        case DashPressedCommand():
        case AttackPressedCommand():
          break;
      }
    }
  }

  /// Advances the simulation by exactly one fixed tick.
  void stepOneTick() {
    if (paused) return;

    tick += 1;
    playerPos = playerPos + playerVel;
    distance += playerVel.x.abs();
  }

  /// Builds an immutable snapshot for render/UI consumption.
  GameStateSnapshot buildSnapshot() {
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
          anim: AnimKey.run,
        ),
      ],
    );
  }
}
