import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_controller_diagnostic.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/characters/eloise_wip.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  for (final character in [eloiseCharacter, eloiseWipCharacter]) {
    for (final direction in [1, -1]) {
      final label = '${character.id.name}, direction $direction';
      for (final mode in TerrainCollisionMode.values) {
        test('$label lands diagonally across a ${mode.name} top corner', () {
          final core = _core(character, _box(mode));
          _startFall(core, character, direction: direction, x: 94, y: 71.5);

          for (var tick = 0; tick < 20; tick += 1) {
            _step(core, direction.toDouble());
          }

          expect(_entryProgress(core, direction), greaterThan(115));
          expect(core.playerGrounded, isTrue);
          expect(core.playerPosY, lessThan(80));
          expect(
            core.buildTerrainPlayerDebugSnapshot()!.diagnostic,
            TerrainControllerDiagnostic.none,
          );
        });
      }

      test('$label enters the authored platform over its pixel rim', () {
        final core = _core(character, _pixelRimPlatform);
        _startFall(
          core,
          character,
          direction: direction,
          x: 98,
          y: 71.5,
          mirrorX: 232,
        );
        var landed = false;
        for (var tick = 0; tick < 9; tick += 1) {
          _step(core, direction.toDouble());
          if (core.playerGrounded) landed = true;
          if (landed) {
            expect(core.playerGrounded, isTrue, reason: 'tick ${core.tick}');
            expect(core.playerPosY, lessThan(80));
          }
        }
        expect(landed, isTrue);
        expect(_entryProgress(core, direction, mirrorX: 232), greaterThan(112));
      });

      test('$label jumps upward through the platform rim', () {
        final core = _core(character, _pixelRimPlatform);
        _startFall(
          core,
          character,
          direction: direction,
          x: 102,
          y: 145,
          mirrorX: 232,
        );
        core.setPlayerVelXY(direction * 60, -500);
        for (var tick = 0; tick < 12; tick += 1) {
          _step(core, direction * 0.3);
          final debug = core.buildTerrainPlayerDebugSnapshot()!;
          expect(debug.hitCeiling || debug.hitLeft || debug.hitRight, isFalse);
          expect(core.playerGrounded, isFalse);
        }
        expect(core.playerPosY, lessThan(76));
      });
    }
  }
}

void _startFall(
  GameCore core,
  PlayerCharacterDefinition character, {
  required int direction,
  required double x,
  required double y,
  double mirrorX = 300,
}) {
  _step(core, direction.toDouble());
  final centerX = direction > 0 ? x : mirrorX - x;
  core.setPlayerPosXYUnsafeForTest(
    centerX - direction * character.catalog.colliderOffsetX,
    y - character.catalog.colliderOffsetY,
  );
  core.setPlayerVelXY(direction * 200, 360);
}

void _step(GameCore core, double axis) {
  core.applyCommands([MoveAxisCommand(tick: core.tick + 1, axis: axis)]);
  core.stepOneTick();
}

double _entryProgress(GameCore core, int direction, {double mirrorX = 300}) =>
    direction > 0 ? core.playerPosX : mirrorX - core.playerPosX;

GameCore _core(
  PlayerCharacterDefinition character,
  TerrainPolygonInput platform,
) => GameCore.terrainMotionHarness(
  seed: 7,
  playerCharacter: character,
  levelDefinition: LevelDefinition(
    id: LevelId.field,
    chunkPatternSource: const ChunkPatternListSource(easyPatterns: []),
    cameraCenterY: 135,
    groundTopY: 300,
    killPlaneY: 1000,
    tuning: const CoreTuning(
      camera: CameraTuning(speedLagMulX: 0, followThresholdRatio: 1),
      track: TrackTuning(enabled: false, playerStartX: 50),
    ),
  ),
  terrainGeometry: const TerrainCompiler().compile([
    _polygon('ground', [(0, 300), (1000, 300), (1000, 500), (0, 500)]),
    platform,
  ], geometryVersion: 1),
);

TerrainPolygonInput _box(TerrainCollisionMode mode) => _polygon('platform', [
  (100, 100),
  (200, 100),
  (200, 150),
  (100, 150),
], mode: mode);

// The collision outline of tiny_swords_ground_platform_03_32x64_platform,
// translated to its left edge at x=100 and highest surface at y=100.
final _pixelRimPlatform = _polygon('pixel-rim', [
  (100, 103),
  (101, 103),
  (101, 102),
  (102, 102),
  (102, 101),
  (104, 101),
  (104, 100),
  (128, 100),
  (128, 101),
  (130, 101),
  (130, 102),
  (131, 102),
  (131, 103),
  (132, 103),
  (132, 164),
  (100, 164),
], mode: TerrainCollisionMode.oneWay);

TerrainPolygonInput _polygon(
  String name,
  List<(double, double)> vertices, {
  TerrainCollisionMode mode = TerrainCollisionMode.solid,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$name',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'edge-landings',
    shapeId: name,
  ),
  vertices: vertices,
  collisionMode: mode,
);
