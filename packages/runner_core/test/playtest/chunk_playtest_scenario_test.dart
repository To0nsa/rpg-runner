import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/playtest/chunk_playtest_scenario.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_data.dart';
import 'package:test/test.dart';

const _selectedKey = 'forest_earlt_flat';
const _draftMaterial = 'chunk_playtest_draft_material';
const _draftAsset = 'playtest/draft-only.png';

void main() {
  test(
    'builds an early canonical path with a deterministic streaming loop',
    () {
      final scenario = _scenario();

      expect(scenario.path.chunkKeys, contains(_selectedKey));
      expect(scenario.path.selectedChunkIndex, lessThanOrEqualTo(1));
      expect(
        scenario.path.transitionRecords,
        hasLength(scenario.path.chunkKeys.length),
      );
      expect(scenario.path.loopStartIndex, inInclusiveRange(0, 1));
      expect(
        scenario.path.previewChunkKeys(16),
        everyElement(isIn(scenario.path.chunkKeys)),
      );
      expect(
        scenario.path
            .previewChunkKeys(16)
            .skip(scenario.path.selectedChunkIndex),
        contains(_selectedKey),
      );

      final runtimeLevel = scenario.buildRuntimeLevelDefinition();
      for (var index = 0; index < 16; index += 1) {
        final pattern = runtimeLevel.chunkPatternSource.patternFor(
          seed: scenario.seed,
          chunkIndex: index,
          tier: index.isEven ? ChunkPatternTier.early : ChunkPatternTier.hard,
        );
        expect(pattern.chunkKey, scenario.path.chunkKeyForIndex(index));
        if (pattern.chunkKey == _selectedKey) {
          expect(pattern.visualSprites.single.assetPath, _draftAsset);
        }
      }
    },
  );

  test(
    'headless Core publishes draft pattern and terrain only in playtest',
    () {
      final scenario = _scenario();
      final playtest = GameCore.chunkPlaytest(scenario: scenario);
      final snapshot = playtest.buildSnapshot();

      expect(snapshot.runId, 0);
      expect(snapshot.seed, scenario.seed);
      expect(snapshot.levelId, LevelId.forest);
      expect(snapshot.visualThemeId, 'forest_chunk_playtest');
      expect(
        snapshot.staticPrefabSprites.where(
          (sprite) => sprite.assetPath == _draftAsset,
        ),
        isNotEmpty,
      );
      expect(
        snapshot.stagedTerrainRenderSnapshot!.polygons.where(
          (polygon) =>
              polygon.sourceId.chunkKey == _selectedKey &&
              polygon.materialKey == _draftMaterial,
        ),
        isNotEmpty,
      );
      expect(
        snapshot.stagedTerrainRenderSnapshot!.polygons.map(
          (polygon) => polygon.materialKey,
        ),
        everyElement(_draftMaterial),
      );
      expect(
        snapshot.entities.where(
          (entity) =>
              entity.kind == EntityKind.enemy &&
              entity.enemyId == EnemyId.grojib,
        ),
        isNotEmpty,
      );

      final normal = GameCore(
        seed: scenario.seed,
        runId: 73,
        levelDefinition: LevelRegistry.byId(LevelId.forest),
        playerCharacter: PlayerCharacterRegistry.eloise,
        equippedLoadoutOverride: const EquippedLoadoutDef(),
      ).buildSnapshot();
      expect(normal.runId, 73);
      expect(
        normal.staticPrefabSprites.where(
          (sprite) => sprite.assetPath == _draftAsset,
        ),
        isEmpty,
      );
      expect(
        normal.stagedTerrainRenderSnapshot!.polygons.where(
          (polygon) => polygon.materialKey == _draftMaterial,
        ),
        isEmpty,
      );
    },
  );

  test('same scenario and command stream produce identical snapshots', () {
    final scenario = _scenario();
    final first = GameCore.chunkPlaytest(scenario: scenario);
    final second = GameCore.chunkPlaytest(scenario: scenario);

    expect(_snapshotRecord(second), _snapshotRecord(first));
    for (var nextTick = 1; nextTick <= 480; nextTick += 1) {
      final commands = <Command>[
        MoveAxisCommand(tick: nextTick, axis: 1),
        if (nextTick % 75 == 0) JumpPressedCommand(tick: nextTick),
      ];
      first.applyCommands(commands);
      second.applyCommands(commands);
      first.stepOneTick();
      second.stepOneTick();
      expect(_snapshotRecord(second), _snapshotRecord(first));
      expect(
        second.drainEvents().map((event) => event.runtimeType.toString()),
        orderedEquals(
          first.drainEvents().map((event) => event.runtimeType.toString()),
        ),
      );
      if (first.gameOver) break;
    }
  });

  test('rebuilding the same scenario restarts from exact tick-zero state', () {
    final scenario = _scenario();
    final advanced = GameCore.chunkPlaytest(scenario: scenario);
    final initialRecord = _snapshotRecord(advanced);

    for (var nextTick = 1; nextTick <= 90; nextTick += 1) {
      advanced.applyCommands(<Command>[
        MoveAxisCommand(tick: nextTick, axis: 1),
      ]);
      advanced.stepOneTick();
    }
    expect(advanced.tick, 90);

    final restarted = GameCore.chunkPlaytest(scenario: scenario);
    expect(restarted.tick, 0);
    expect(_snapshotRecord(restarted), initialRecord);
  });

  test('scenario defensively owns the selected pattern collections', () {
    final sprites = <ChunkVisualSpriteRel>[
      const ChunkVisualSpriteRel(
        assetPath: _draftAsset,
        srcX: 0,
        srcY: 0,
        srcWidth: 16,
        srcHeight: 16,
        x: 16,
        y: 192,
        width: 16,
        height: 16,
      ),
    ];
    final scenario = ChunkPlaytestScenario(
      levelDefinition: LevelRegistry.byId(LevelId.forest),
      visualThemeId: 'forest_chunk_playtest',
      seed: 4401,
      draftPattern: ChunkPattern(
        name: 'forest_early_flat_draft',
        chunkKey: _selectedKey,
        visualSprites: sprites,
      ),
      draftTerrain: _draftTerrain(),
      playerCharacter: PlayerCharacterRegistry.eloise,
      equippedLoadout: const EquippedLoadoutDef(),
    );

    sprites.clear();

    expect(scenario.draftPattern.visualSprites, hasLength(1));
    expect(
      scenario
          .buildRuntimeLevelDefinition()
          .chunkPatternSource
          .patternFor(
            seed: scenario.seed,
            chunkIndex: scenario.path.selectedChunkIndex,
            tier: ChunkPatternTier.early,
          )
          .visualSprites,
      hasLength(1),
    );
  });

  test('inactive and exact-boundary-incompatible drafts fail before Core', () {
    expect(
      () => _scenario(draftTerrain: _draftTerrain(status: 'deprecated')),
      throwsA(
        isA<ChunkPlaytestScenarioException>().having(
          (error) => error.code,
          'code',
          'chunk_playtest_selected_chunk_inactive',
        ),
      ),
    );
    expect(
      () => _scenario(draftTerrain: _draftTerrain(breakRightBoundary: true)),
      throwsA(
        isA<ChunkPlaytestScenarioException>().having(
          (error) => error.code,
          'code',
          'staged_reachable_seam_mismatch',
        ),
      ),
    );
  });

  test('wrong level, group, and width fail before Core', () {
    expect(
      () => _scenario(draftTerrain: _draftTerrain(levelId: 'field')),
      throwsA(
        isA<ChunkPlaytestScenarioException>().having(
          (error) => error.code,
          'code',
          'chunk_playtest_selected_level_mismatch',
        ),
      ),
    );
    expect(
      () => _scenario(draftTerrain: _draftTerrain(assemblyGroupId: 'woodcamp')),
      throwsA(
        isA<ChunkPlaytestScenarioException>().having(
          (error) => error.code,
          'code',
          'chunk_playtest_selected_group_mismatch',
        ),
      ),
    );
    expect(
      () => _scenario(draftTerrain: _draftTerrain(width: 599)),
      throwsA(
        isA<ChunkPlaytestScenarioException>().having(
          (error) => error.code,
          'code',
          'chunk_playtest_selected_width_mismatch',
        ),
      ),
    );
  });
}

ChunkPlaytestScenario _scenario({
  LevelDefinition? levelDefinition,
  StagedTerrainChunkData? draftTerrain,
}) => ChunkPlaytestScenario(
  levelDefinition: levelDefinition ?? LevelRegistry.byId(LevelId.forest),
  visualThemeId: 'forest_chunk_playtest',
  seed: 4401,
  draftPattern: const ChunkPattern(
    name: 'forest_early_flat_draft',
    chunkKey: _selectedKey,
    assemblyGroupId: 'default',
    visualSprites: <ChunkVisualSpriteRel>[
      ChunkVisualSpriteRel(
        assetPath: _draftAsset,
        srcX: 0,
        srcY: 0,
        srcWidth: 16,
        srcHeight: 16,
        x: 16,
        y: 192,
        width: 16,
        height: 16,
      ),
    ],
    spawnMarkers: <SpawnMarker>[
      SpawnMarker(
        enemyId: EnemyId.grojib,
        x: 300,
        chancePercent: 100,
        salt: 99173,
      ),
    ],
  ),
  draftTerrain: draftTerrain ?? _draftTerrain(),
  playerCharacter: PlayerCharacterRegistry.eloise,
  equippedLoadout: const EquippedLoadoutDef(),
);

StagedTerrainChunkData _draftTerrain({
  String status = 'active',
  String? levelId,
  int? width,
  String? assemblyGroupId,
  bool breakRightBoundary = false,
}) {
  final admitted = stagedAuthoredTerrain.chunks.singleWhere(
    (chunk) => chunk.chunkKey == _selectedKey,
  );
  final rightBoundaryX = admitted.width * 1024;
  StagedTerrainEdgeData draftEdge(StagedTerrainEdgeData edge) =>
      StagedTerrainEdgeData(
        id: edge.id,
        start: _moveRightBoundaryPoint(
          edge.start,
          rightBoundaryX: rightBoundaryX,
          enabled: breakRightBoundary,
        ),
        end: _moveRightBoundaryPoint(
          edge.end,
          rightBoundaryX: rightBoundaryX,
          enabled: breakRightBoundary,
        ),
        tangent: edge.tangent,
        outwardNormal: edge.outwardNormal,
        collisionMode: edge.collisionMode,
        surfaceKind: edge.surfaceKind,
        materialKey: edge.materialKey,
        previousId: edge.previousId,
        nextId: edge.nextId,
        startJoin: edge.startJoin,
        endJoin: edge.endJoin,
      );
  return StagedTerrainChunkData(
    chunkKey: admitted.chunkKey,
    id: '${admitted.id}_draft',
    revision: admitted.revision + 1,
    status: status,
    levelId: levelId ?? admitted.levelId,
    tileSize: admitted.tileSize,
    width: width ?? admitted.width,
    height: admitted.height,
    difficulty: admitted.difficulty,
    assemblyGroupId: assemblyGroupId ?? admitted.assemblyGroupId,
    authoringPolygonSignature: admitted.authoringPolygonSignature,
    sourceSignature: admitted.sourceSignature,
    edgeSignature: admitted.edgeSignature,
    renderEdgeSignature: admitted.renderEdgeSignature,
    placementSignature: admitted.placementSignature,
    triangleSignature: admitted.triangleSignature,
    polygons: admitted.polygons.map(
      (polygon) => StagedTerrainPolygonData(
        sourcePath: polygon.sourcePath,
        id: polygon.id,
        sourceVertices: polygon.sourceVertices,
        vertices: polygon.vertices,
        collisionMode: polygon.collisionMode,
        surfaceKind: polygon.surfaceKind,
        materialKey: _draftMaterial,
      ),
    ),
    edges: admitted.edges.map(draftEdge),
    renderEdges: admitted.renderEdges.map(draftEdge),
    triangles: admitted.triangles,
    placementLineage: admitted.placementLineage,
  );
}

StagedTerrainPoint _moveRightBoundaryPoint(
  StagedTerrainPoint point, {
  required int rightBoundaryX,
  required bool enabled,
}) {
  if (!enabled || point.xTicks != rightBoundaryX) return point;
  return StagedTerrainPoint(point.xTicks - 1024, point.yTicks);
}

String _snapshotRecord(GameCore core) {
  final snapshot = core.buildSnapshot();
  final terrain = snapshot.stagedTerrainRenderSnapshot;
  return <Object?>[
    snapshot.tick,
    snapshot.runId,
    snapshot.seed,
    snapshot.levelId,
    snapshot.visualThemeId,
    snapshot.distance,
    snapshot.paused,
    snapshot.gameOver,
    snapshot.camera.centerX,
    snapshot.camera.centerY,
    snapshot.hud.hp,
    snapshot.hud.mana,
    snapshot.hud.stamina,
    for (final entity in snapshot.entities)
      '${entity.id}|${entity.kind.name}|${entity.pos.x}|${entity.pos.y}|'
          '${entity.vel?.x}|${entity.vel?.y}|${entity.grounded}|'
          '${entity.facing.name}|${entity.anim.name}|${entity.animFrame}',
    for (final sprite in snapshot.staticPrefabSprites)
      '${sprite.assetPath}|${sprite.x}|${sprite.y}|${sprite.zIndex}',
    terrain?.geometryVersion,
    for (final polygon in terrain?.polygons ?? const [])
      '${polygon.sourceId}|${polygon.materialKey}|${polygon.vertices.length}',
    for (final edge in terrain?.edges ?? const []) edge.id.toString(),
  ].join('\n');
}
