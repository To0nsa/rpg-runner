import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  for (final character in PlayerCharacterRegistry.playable) {
    for (final direction in [-1.0, 1.0]) {
      for (final hz in [30, 60, 120]) {
        for (final running in [false, true]) {
          test(
            'Derf transforms and hits ${character.id.name} '
            '${running ? 'running away' : 'standing'} direction=$direction at $hz Hz',
            () {
              final core = GameCore.terrainMotionHarness(
                seed: 7,
                tickHz: hz,
                playerCharacter: character,
                levelDefinition: LevelDefinition(
                  id: LevelId.field,
                  groundTopY: 300,
                  earlyPatternChunks: 0,
                  noEnemyChunks: 0,
                  tuning: const CoreTuning(
                    camera: CameraTuning(fallBehindGraceDistance: 10000),
                    track: TrackTuning(
                      enabled: true,
                      chunkWidth: 20000,
                      spawnAheadMargin: 0,
                      playerStartX: 300,
                      cullBehindMargin: 10000,
                    ),
                  ),
                  chunkPatternSource: ChunkPatternListSource(
                    easyPatterns: [_pattern(direction)],
                    hardPatterns: [_pattern(direction)],
                  ),
                ),
                terrainGeometry: _floor,
              );
              addTearDown(core.stopTerrainPreparation);
              final initialHp = core.buildSnapshot().hud.hp;
              var transformed = false;
              var chased = false;
              var struck = false;
              var hit = false;
              for (var i = 0; i < 10 * hz; i++) {
                core.applyCommands([
                  MoveAxisCommand(
                    tick: core.tick + 1,
                    axis: running ? direction : 0,
                  ),
                ]);
                core.stepOneTick();
                final snapshot = core.buildSnapshot();
                expect(
                  snapshot.entities.where((e) => e.enemyId == EnemyId.derf),
                  hasLength(1),
                  reason:
                      'tick=${core.tick} player=${core.playerPosX} '
                      '${core.lastSpawnPlacementDiagnostic}',
                );
                final derf = snapshot.entities.singleWhere(
                  (e) => e.enemyId == EnemyId.derf,
                );
                transformed |= derf.anim == AnimKey.transform;
                chased |=
                    (derf.pos.x - (300 - direction * 100)) * direction > 20;
                struck |= derf.anim == AnimKey.strike;
                if (snapshot.hud.hp < initialHp) {
                  hit = true;
                  break;
                }
              }
              expect(transformed, isTrue);
              if (running) expect(chased, isTrue);
              expect(struck, isTrue);
              expect(
                hit,
                isTrue,
                reason: 'A normal run must not evade every tentacle strike',
              );
            },
          );
        }
      }
    }
  }
}

ChunkPattern _pattern(double direction) => ChunkPattern(
  name: 'derf-running-target',
  spawnMarkers: [
    SpawnMarker(
      enemyId: EnemyId.derf,
      x: 300 - direction * 100,
      chancePercent: 100,
      salt: 1,
      placement: SpawnPlacementMode.ground,
    ),
  ],
);

final _floor = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/derf-running-target',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'floor',
    ),
    vertices: [(-5000, 300), (10000, 300), (10000, 600), (-5000, 600)],
    surfaceKind: 'ground',
  ),
], geometryVersion: 1);
