import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_seam_signature.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  test(
    'example compiles water separately and binds it with atomic terrain',
    () {
      final runtime = _compile();
      expect(runtime.stagedTerrain.waterRegions.single.id, 'pool');
      expect(runtime.stagedTerrain.polygons, hasLength(1));
      final dry = _compile(withWater: false);
      expect(
        runtime.stagedTerrain.edgeSignature,
        dry.stagedTerrain.edgeSignature,
      );
      expect(
        runtime.stagedTerrain.waterSignature,
        isNot(dry.stagedTerrain.waterSignature),
      );
      final candidate = _candidate(runtime, origin: 600 * 1024);
      final water = candidate.waterRegions.single;
      expect(water.leftTicks, 728 * 1024);
      expect(water.topTicks, 224 * 1024);
      expect(candidate.renderSnapshot.waterRegions.single, same(water));
      final rebound = candidate.withGeometryVersion(8);
      expect(rebound.waterRegions.single, same(water));
      expect(rebound.renderSnapshot.waterRegions.single, same(water));
      expect(rebound.geometry.version, 8);
      final validated = validatePolygonTerrainSeams(
        chunks: [runtime.compiled],
        manifest: PolygonTerrainSeamManifest(
          signature: TerrainAuthoringSeamSignature([]),
          sourcePath: 'isolated pool',
        ),
      );
      expect(validated.issues, isEmpty);
      final generated = renderStagedPolygonTerrainDart(validated.batch!);
      expect(generated, contains('waterRegions: <WaterRegionData>['));
      expect(generated, contains('materialKey: "biome_water"'));
    },
  );

  test('strict water decoding rejects malformed and ambiguous rectangles', () {
    final valid = <String, Object>{
      'id': 'pool',
      'x': 10,
      'y': 20,
      'width': 100,
      'height': 40,
      'materialKey': 'biome_water',
    };
    for (final input in <Object?>[
      null,
      'water',
      [
        {...valid, 'width': 0},
      ],
      [
        {...valid, 'x': 0.5},
      ],
      [
        {...valid, 'depth': 1},
      ],
      [
        {...valid, 'height': 900},
      ],
      [valid, valid],
      [
        valid,
        {...valid, 'id': 'second'},
      ],
    ]) {
      expect(
        () => decodeWaterRegions(
          input,
          sourcePath: 'waterRegions',
          chunkWidth: 600,
          chunkHeight: 320,
        ),
        throwsFormatException,
        reason: '$input',
      );
    }
    expect(
      decodeWaterRegions(
        [
          valid,
          {...valid, 'id': 'second', 'x': 110},
        ],
        sourcePath: 'waterRegions',
        chunkWidth: 600,
        chunkHeight: 320,
      ),
      hasLength(2),
    );
  });

  test(
    'published pool enables strokes, resolves floor and preserves replay',
    () {
      final candidate = _candidate(_compile());
      GameCore create() {
        final core = GameCore.terrainMotionHarness(
          seed: 41,
          playerCharacter: eloiseCharacter,
          levelDefinition: LevelDefinition(
            id: LevelId.field,
            chunkPatternSource: const ChunkPatternListSource(
              easyPatterns: [],
              hardPatterns: [],
            ),
            groundTopY: 224,
            killPlaneY: 400,
            tuning: const CoreTuning(
              track: TrackTuning(enabled: false),
              camera: CameraTuning(speedLagMulX: 0),
            ),
          ),
          terrainGeometry: candidate.geometry,
        );
        core.queueTerrainHarnessStagedCandidate(
          candidate.withGeometryVersion(3),
        );
        core.setPlayerPosXYUnsafeForTest(220, 245);
        return core;
      }

      final first = create();
      final second = create();
      var swam = false;
      var stroked = false;
      for (var tick = 1; tick <= 180; tick++) {
        final commands = <Command>[
          if (tick == 30 || tick == 75) JumpPressedCommand(tick: tick),
        ];
        for (final core in [first, second]) {
          core.applyCommands(commands);
          core.stepOneTick();
        }
        swam |= first.buildSnapshot().playerEntity!.isSwimming;
        if (tick == 30) stroked = first.playerVelY < 0;
        expect(second.playerPosX, first.playerPosX);
        expect(second.playerPosY, first.playerPosY);
        expect(second.playerVelY, first.playerVelY);
        expect(first.gameOver, isFalse);
      }
      expect(swam, isTrue);
      expect(stroked, isTrue);
      for (var i = 0; i < 300; i++) {
        first.applyCommands(const []);
        first.stepOneTick();
      }
      expect(first.playerGrounded, isTrue);
      expect(first.buildSnapshot().playerEntity!.isSwimming, isTrue);
      expect(first.playerPosY, lessThan(288));
      for (var i = 0; i < 120 && first.playerPosX > 100; i++) {
        final tick = first.tick + 1;
        first.applyCommands([
          MoveAxisCommand(tick: tick, axis: -1),
          if (i % 20 == 0) JumpPressedCommand(tick: tick),
        ]);
        first.stepOneTick();
        expect(first.gameOver, isFalse);
      }
      expect(
        first.playerPosX,
        lessThanOrEqualTo(100),
        reason: 'Strokes must clear the solid bank from the pool floor.',
      );
      expect(first.buildSnapshot().playerEntity!.isSwimming, isFalse);
      final dry = _candidate(_compile(withWater: false)).withGeometryVersion(4);
      first.queueTerrainHarnessStagedCandidate(dry);
      first.applyCommands(const []);
      first.stepOneTick();
      expect(first.buildSnapshot().playerEntity!.isSwimming, isFalse);
      expect(
        first.buildSnapshot().stagedTerrainRenderSnapshot!.waterRegions,
        isEmpty,
      );
    },
  );
}

PolygonTerrainRuntimeChunk _compile({bool withWater = true}) {
  var root = Directory.current;
  while (!File('${root.path}/docs/examples/water_pool_chunk.json')
      .existsSync()) {
    if (root.parent.path == root.path) {
      throw StateError('Repository root not found.');
    }
    root = root.parent;
  }
  final json = jsonDecode(
    File('${root.path}/docs/examples/water_pool_chunk.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  if (!withWater) json.remove('waterRegions');
  final result = compilePolygonTerrainRuntimeChunkSource(
    prefabSourcePath: 'prefab_defs.json',
    prefabContents: '{"schemaVersion":3,"slices":[],"prefabs":[]}',
    tileSourcePath: 'tile_defs.json',
    tileContents: '{"schemaVersion":2,"tileSlices":[],"platformModules":[]}',
    chunkSourcePath: 'water_pool_chunk.json',
    chunkContents: jsonEncode(json),
  );
  expect(result.issues, isEmpty);
  return result.chunk!;
}

StagedTerrainStreamCandidate _candidate(
  PolygonTerrainRuntimeChunk runtime, {
  int origin = 0,
}) {
  final catalog = StagedTerrainChunkCatalog(chunks: [runtime.stagedTerrain]);
  return const StagedTerrainStreamCandidateBuilder().buildFromBindings(
    bindings: [
      catalog.bind(
        chunkKey: runtime.stagedTerrain.chunkKey,
        chunkIndex: 0,
        worldOriginXTicks: origin,
      ),
    ],
    geometryVersion: 2,
    groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
  );
}
