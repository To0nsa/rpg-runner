import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/finite_chunk_pattern_source.dart';
import 'package:runner_core/training/authored_training_field.dart';
import 'package:test/test.dart';

void main() {
  for (final enemy in [
    EnemyId.grojib,
    EnemyId.hashash,
    EnemyId.derf,
    EnemyId.unocoDemon,
  ]) {
    test('${enemy.name}: instantiated once and idle while distant', () {
      final core = _core(enemy);
      addTearDown(core.stopTerrainPreparation);
      final initial = _enemy(core);
      for (var t = 0; t < 240; t++) {
        _step(core, 0);
        final actor = _enemy(core);
        expect(actor.id, initial.id);
        expect(actor.pos.x, closeTo(initial.pos.x, 0.01));
        expect(actor.pos.y, closeTo(initial.pos.y, 1));
      }
      expect(
        core.buildSnapshot().entities.where((e) => e.projectileId != null),
        isEmpty,
      );
    });
  }

  test(
    'a real distant projectile hit wakes a waiting marker without approaching',
    () {
      final core = _core(EnemyId.grojib, homeX: 650);
      addTearDown(core.stopTerrainPreparation);
      for (var t = 0; t < 120; t++) {
        _step(core, 0);
      }
      expect(_enemy(core).pos.x, 650);
      final tick = core.tick + 1;
      core.applyCommands([
        AimDirCommand(tick: tick, x: 1, y: 0),
        ProjectilePressedCommand(tick: tick),
      ]);
      core.stepOneTick();
      for (var t = 0; t < 180 && _enemy(core).pos.x >= 645; t++) {
        _step(core, 0);
      }
      expect(core.playerPosX, closeTo(300, 1));
      expect(_enemy(core).pos.x, lessThan(645));
    },
  );

  for (final enemy in [EnemyId.hashash, EnemyId.derf, EnemyId.unocoDemon]) {
    test(
      '${enemy.name}: continuous approach and retreat returns the same actor home',
      () {
        final core = _core(enemy);
        addTearDown(core.stopTerrainPreparation);
        final initial = _enemy(core);
        while (core.playerPosX < 1240 && core.tick < 720) {
          _step(core, 1);
        }
        // Derf completes its normal transformation before starting ground pursuit.
        for (var t = 0; t < 75; t++) {
          _step(core, 0);
        }
        expect(_enemy(core).pos.x, lessThan(initial.pos.x - 5));
        while (core.playerPosX > 300 && core.tick < 1500) {
          _step(core, -1);
        }
        for (var t = 0; t < 360; t++) {
          _step(core, 0);
        }
        expect(_enemy(core).id, initial.id);
        expect(_enemy(core).pos.x, closeTo(initial.pos.x, 4));
        expect(_enemy(core).pos.y, closeTo(initial.pos.y, 4));
      },
    );
  }

  test(
    'same command stream reproduces activation, combat and return snapshots',
    () {
      final a = _core(EnemyId.unocoDemon);
      final b = _core(EnemyId.unocoDemon);
      addTearDown(a.stopTerrainPreparation);
      addTearDown(b.stopTerrainPreparation);
      for (var t = 0; t < 1200; t++) {
        final axis = t < 210
            ? 1
            : t < 240
            ? 0
            : t < 480
            ? -1
            : 0;
        _step(a, axis);
        _step(b, axis);
        final ea = _enemy(a), eb = _enemy(b);
        expect(
          (ea.id, ea.pos.x, ea.pos.y, ea.anim, a.buildSnapshot().hud.hp),
          (eb.id, eb.pos.x, eb.pos.y, eb.anim, b.buildSnapshot().hud.hp),
        );
      }
    },
  );

  for (final hz in [30, 60, 90]) {
    for (final follows in [false, true]) {
      test(
        '$hz Hz: Grojib ${follows ? 'follows' : 'returns'} after continuous retreat',
        () {
          final core = _core(EnemyId.grojib, follows: follows, hz: hz);
          addTearDown(core.stopTerrainPreparation);
          final initial = _enemy(core);
          // Keep actor state continuous across both actual chunk seams.
          while (core.playerPosX < 1240 && core.tick < hz * 12) {
            _step(core, 1);
          }
          expect(core.playerPosX, greaterThanOrEqualTo(1240));
          for (var t = 0; t < hz ~/ 4; t++) {
            _step(core, 0);
          }
          expect(_enemy(core).pos.x, lessThan(initial.pos.x - 5));
          while (core.playerPosX > 300 && core.tick < hz * 25) {
            _step(core, -1);
          }
          final trace = <String>[];
          for (var t = 0; t < hz * 5; t++) {
            _step(core, 0);
            if (t >= hz * 5 - 12) {
              trace.add(
                '${_enemy(core).pos} ${_enemy(core).vel} ${_enemy(core).anim}',
              );
            }
          }
          expect(_enemy(core).id, initial.id);
          expect(
            _enemy(core).pos.x,
            follows ? lessThan(900) : closeTo(initial.pos.x, 4),
            reason: 'home=${initial.pos} trace=$trace',
          );
        },
      );
    }
  }
}

void _step(GameCore core, int axis) {
  core.applyCommands([
    MoveAxisCommand(tick: core.tick + 1, axis: axis.toDouble()),
  ]);
  core.stepOneTick();
  expect(core.gameOver, isFalse);
}

EntityRenderSnapshot _enemy(GameCore core) =>
    core.buildSnapshot().entities.singleWhere((e) => e.enemyId != null);

GameCore _core(
  EnemyId enemy, {
  bool follows = false,
  int hz = 60,
  double homeX = 1500,
}) {
  final field = trainingFieldDefinition;
  final flat = field.chunks.first;
  final chunk = homeX ~/ 600;
  final target = (missionChunkId: 'chunk_$chunk', markerSalt: 42);
  final mission = CampaignMissionDefinition(
    id: 'enemy_activation_fixture',
    route: FiniteChunkPatternSource([
      for (var i = 0; i < 5; i++)
        FiniteMissionChunk(
          id: 'chunk_$i',
          sourceLevelId: 'training_field',
          tier: ChunkPatternTier.easy,
          pattern: ChunkPattern(
            name: flat.name,
            chunkKey: flat.chunkKey,
            spawnMarkers: i == chunk
                ? [
                    SpawnMarker(
                      enemyId: enemy,
                      x: homeX % 600,
                      chancePercent: 100,
                      salt: 42,
                    ),
                  ]
                : [],
          ),
        ),
    ]),
    terrainChunks: field.terrain.chunks,
    visualThemeId: field.visualThemeId,
    start: CampaignPoint(missionChunkId: 'chunk_0', x: 300, y: 224),
    exit: CampaignRegion(
      origin: CampaignPoint(missionChunkId: 'chunk_4', x: 580, y: 0),
      width: 10,
      height: 10,
    ),
    requiredEnemies: [target],
    persistentPursuitEnemies: follows ? [target] : [],
  );
  return GameCore.campaignPlaytest(
    mission: mission,
    playerCharacter: PlayerCharacterRegistry.eloise,
    seed: 42,
    tickHz: hz,
  );
}
