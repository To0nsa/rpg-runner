import 'package:replay_validator/src/replay_simulation.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:test/test.dart';

void main() {
  test('shared replay loop matches direct Core command application', () {
    final frames = <ReplayCommandFrameV1>[
      for (var tick = 1; tick <= 120; tick += 1)
        ReplayCommandFrameV1(
          tick: tick,
          moveAxis: 1,
          aimDirX: tick == 60 ? 1 : null,
          aimDirY: tick == 60 ? 0 : null,
          pressedMask:
              (tick == 20 ? ReplayCommandFrameV1.pressedJumpBit : 0) |
              (tick == 40 ? ReplayCommandFrameV1.pressedDashBit : 0) |
              (tick == 60 ? ReplayCommandFrameV1.pressedProjectileBit : 0),
        ),
    ];
    final replayed = _buildCore();
    final direct = _buildCore();
    final checkpoints = <int>[];

    final result = runReplaySimulation(
      core: replayed,
      totalTicks: 120,
      commandStream: frames,
      onCheckpoint: checkpoints.add,
    );
    for (final frame in frames) {
      direct.applyCommands(<Command>[
        MoveAxisCommand(tick: frame.tick, axis: 1),
        if (frame.tick == 20) JumpPressedCommand(tick: frame.tick),
        if (frame.tick == 40) DashPressedCommand(tick: frame.tick),
        if (frame.tick == 60) ...<Command>[
          AimDirCommand(tick: frame.tick, x: 1, y: 0),
          ProjectilePressedCommand(tick: frame.tick),
        ],
      ]);
      direct.stepOneTick();
      direct.drainEvents();
    }

    expect(result.ticksExecuted, 120);
    expect(result.runEnded, isNull);
    expect(checkpoints, <int>[1]);
    expect(replayed.tick, direct.tick);
    expect(replayed.playerPosX, direct.playerPosX);
    expect(replayed.playerPosY, direct.playerPosY);
    expect(replayed.playerVelX, direct.playerVelX);
    expect(replayed.playerVelY, direct.playerVelY);
    expect(replayed.distance, direct.distance);
    expect(
      replayed.buildSnapshot().entities.map(
        (entity) => (
          entity.id,
          entity.kind,
          entity.pos.x,
          entity.pos.y,
          entity.vel?.x,
          entity.vel?.y,
        ),
      ),
      orderedEquals(
        direct.buildSnapshot().entities.map(
          (entity) => (
            entity.id,
            entity.kind,
            entity.pos.x,
            entity.pos.y,
            entity.vel?.x,
            entity.vel?.y,
          ),
        ),
      ),
    );
  });
}

GameCore _buildCore() => GameCore(
  seed: 871,
  levelDefinition: LevelRegistry.byId(
    LevelId.field,
  ).copyWith(noEnemyChunks: 9999),
  playerCharacter: PlayerCharacterRegistry.eloise,
);
