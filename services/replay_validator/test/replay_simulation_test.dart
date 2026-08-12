import 'package:replay_validator/src/replay_simulation.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/hit/hit_resolver.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/faction_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/tuning/spatial_grid_tuning.dart';
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

  test('validator-linked Core rejects a target AABB-corner-only contact', () {
    final world = EcsWorld();
    final owner = world.createEntity();
    world.transform.add(owner, posX: 0, posY: 0, velX: 0, velY: 0);
    world.faction.add(owner, const FactionDef(faction: Faction.player));

    final target = world.createEntity();
    const collider = ColliderAabbDef(halfX: 2, halfY: 6);
    world.transform.add(target, posX: 3.9, posY: 11.9, velX: 0, velY: 0);
    world.colliderAabb.add(target, collider);
    world.worldContactCapsule.add(
      target,
      WorldContactCapsuleDef.fromAabb(collider),
    );
    world.health.add(
      target,
      const HealthDef(hp: 100, hpMax: 100, regenPerSecond100: 0),
    );
    world.faction.add(target, const FactionDef(faction: Faction.enemy));

    final broadphase = BroadphaseGrid(
      index: GridIndex2D(
        cellSize: const SpatialGridTuning().broadphaseCellSize,
      ),
    )..rebuild(world);
    final overlaps = <int>[];
    HitResolver().collectOrderedOverlapsCapsule(
      broadphase: broadphase,
      ax: 0,
      ay: -4,
      bx: 0,
      by: 4,
      radius: 2,
      owner: owner,
      sourceFaction: Faction.player,
      outTargetIndices: overlaps,
    );

    expect(overlaps, isEmpty);
  });
}

GameCore _buildCore() => GameCore(
  seed: 871,
  levelDefinition: LevelRegistry.byId(
    LevelId.field,
  ).copyWith(noEnemyChunks: 9999),
  playerCharacter: PlayerCharacterRegistry.eloise,
);
