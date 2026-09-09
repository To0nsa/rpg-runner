import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_identity.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/playtest/chunk_playtest_scenario.dart';
import 'package:runner_core/playtest/level_playtest_scenario.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_data.dart';
import 'package:test/test.dart';

const _levelName = 'never_generated_workshop';
const _player = PlayerCharacterRegistry.eloise;
const _loadout = EquippedLoadoutDef();

void main() {
  test('sample and restarted Core preserve explicit section tiers', () {
    final level = _level().copyWith(
      chunkPatternSource: ChunkPatternListSource(
        earlyPatterns: [_pattern('opening')],
        easyPatterns: [_pattern('easy_a'), _pattern('easy_b')],
        hardPatterns: [_pattern('hard')],
      ),
      assembly: const LevelAssemblyDefinition(
        loopSegments: false,
        segments: [
          LevelAssemblySegment(
            segmentId: 'opening',
            groupId: 'default',
            difficulty: ChunkPatternTier.early,
            minChunkCount: 1,
            maxChunkCount: 1,
            requireDistinctChunks: true,
          ),
          LevelAssemblySegment(
            segmentId: 'easy',
            groupId: 'default',
            difficulty: ChunkPatternTier.easy,
            minChunkCount: 2,
            maxChunkCount: 2,
            requireDistinctChunks: true,
          ),
          LevelAssemblySegment(
            segmentId: 'hard',
            groupId: 'default',
            difficulty: ChunkPatternTier.hard,
            minChunkCount: 1,
            maxChunkCount: 1,
            requireDistinctChunks: true,
          ),
        ],
      ),
    );
    final scenario = _scenario(
      level: level,
      chunks: [
        _terrain('opening'),
        _terrain('easy_a', difficulty: 'easy'),
        _terrain('easy_b', difficulty: 'easy'),
        _terrain('hard', difficulty: 'hard'),
      ],
    );
    final sample = scenario.sampleChunks(count: 6);
    expect(sample.map((s) => s.requestedTier), [
      ChunkPatternTier.early,
      ChunkPatternTier.easy,
      ChunkPatternTier.easy,
      ChunkPatternTier.hard,
      ChunkPatternTier.hard,
      ChunkPatternTier.hard,
    ]);
    expect(
      sample.map((s) => s.resolvedTier),
      sample.map((s) => s.requestedTier),
    );
    expect(sample.skip(1).take(2).map((s) => s.chunkKey).toSet(), {
      'easy_a',
      'easy_b',
    });
    expect(sample.map((s) => s.enemiesSuppressed), [
      true,
      true,
      true,
      false,
      false,
      false,
    ]);
    _expectSameRun(
      GameCore.levelPlaytest(scenario: scenario),
      GameCore.levelPlaytest(scenario: scenario),
    );
  });

  test(
    'identity preserves provenance, including authored registered names',
    () {
      const registered = RegisteredLevelIdentity(LevelId.field);
      final authored = AuthoredLevelIdentity('field');
      expect(registered.value, authored.value);
      expect(registered, isNot(authored));
      expect(authored, AuthoredLevelIdentity('field'));
      expect(registered.requireRegisteredId(), LevelId.field);
      expect(authored.requireRegisteredId, throwsStateError);
      for (final invalid in ['', ' field', 'Field', 'two words', '../field']) {
        expect(() => AuthoredLevelIdentity(invalid), throwsArgumentError);
      }
      for (final id in [_levelName, 'field']) {
        final level = _level(identity: id);
        expect(level.copyWith(noEnemyChunks: 0).identity, level.identity);
        expect(
          () => GameCore(
            seed: 4401,
            levelDefinition: level,
            playerCharacter: _player,
          ),
          throwsStateError,
        );
      }
    },
  );

  test('never-generated first chunk enters both explicit Core scenarios', () {
    final terrain = _terrain('new_starter');
    final pattern = _pattern('new_starter');
    final level = _level(patterns: [pattern]);
    final whole = _scenario(level: level, chunks: [terrain]);
    final focused = ChunkPlaytestScenario(
      levelDefinition: level,
      terrainChunks: const [],
      draftTerrain: terrain,
      draftPattern: pattern,
      visualThemeId: 'new_background',
      seed: 4401,
      playerCharacter: _player,
      equippedLoadout: _loadout,
    );
    final fullCore = GameCore.levelPlaytest(scenario: whole);
    final chunkCore = GameCore.chunkPlaytest(scenario: focused);
    for (final core in [fullCore, chunkCore]) {
      final snapshot = core.buildSnapshot();
      expect(snapshot.levelIdentity, AuthoredLevelIdentity(_levelName));
      expect(snapshot.runId, 0);
      expect(snapshot.visualThemeId, 'new_background');
      expect(snapshot.stagedTerrainRenderSnapshot!.polygons, isNotEmpty);
      expect(
        snapshot.stagedTerrainRenderSnapshot!.polygons.map(
          (polygon) => polygon.sourceId.chunkKey,
        ),
        everyElement('new_starter'),
      );
    }
    expect(
      fullCore.buildSnapshot().entities.where(
        (entity) => entity.kind == EntityKind.enemy,
      ),
      isEmpty,
    );
    expect(
      chunkCore.buildSnapshot().entities.where(
        (entity) =>
            entity.kind == EntityKind.enemy && entity.enemyId == EnemyId.grojib,
      ),
      isNotEmpty,
    );
    expect(whole.buildRuntimeLevelDefinition().noEnemyChunks, 3);
    expect(focused.buildRuntimeLevelDefinition().noEnemyChunks, 0);
  });

  test('registered whole-level play matches normal Core at every tick', () {
    final level = LevelRegistry.byId(LevelId.forest);
    final scenario = _scenario(
      level: level,
      chunks: stagedAuthoredTerrain.chunks.where(
        (chunk) => chunk.levelId == 'forest',
      ),
    );
    final normal = GameCore(
      seed: 4401,
      levelDefinition: level,
      playerCharacter: _player,
      equippedLoadoutOverride: _loadout,
    );
    final preview = GameCore.levelPlaytest(scenario: scenario);
    _expectSameRun(normal, preview);
  });

  test('captured sequence and restart survive caller collection mutations', () {
    final patterns = [
      _pattern('a', group: 'woods'),
      _pattern('b', group: 'ruins'),
    ];
    final segments = [
      const LevelAssemblySegment(
        segmentId: 'first',
        groupId: 'woods',
        minChunkCount: 2,
        maxChunkCount: 2,
        requireDistinctChunks: false,
      ),
      const LevelAssemblySegment(
        segmentId: 'last',
        groupId: 'ruins',
        minChunkCount: 1,
        maxChunkCount: 1,
        requireDistinctChunks: false,
      ),
    ];
    final chunks = [
      _terrain('a', group: 'woods'),
      _terrain('b', group: 'ruins'),
    ];
    final level = _level(
      patterns: patterns,
      assembly: LevelAssemblyDefinition(
        loopSegments: false,
        segments: segments,
      ),
    );
    final scenario = _scenario(level: level, chunks: chunks);
    patterns.clear();
    segments.clear();
    chunks.clear();
    final sample = scenario.sampleChunks();
    expect(sample.map((entry) => entry.chunkKey), [
      'a',
      'a',
      ...List.filled(10, 'b'),
    ]);
    expect(sample.map((entry) => entry.requestedTier), [
      ...List.filled(3, ChunkPatternTier.early),
      ...List.filled(2, ChunkPatternTier.easy),
      ...List.filled(4, ChunkPatternTier.normal),
      ...List.filled(3, ChunkPatternTier.hard),
    ]);
    expect(
      sample.map((entry) => entry.resolvedTier),
      everyElement(ChunkPatternTier.early),
    );
    expect(sample.map((entry) => entry.enemiesSuppressed), [
      ...List.filled(3, true),
      ...List.filled(9, false),
    ]);
    expect(sample[0].assembly!.segmentId, 'first');
    expect(sample[0].assembly!.chunkCount, 2);
    expect(sample[0].startsSection, isTrue);
    expect(sample[1].startsSection, isFalse);
    expect(sample[2].assembly!.repeatsFinalSegment, isFalse);
    expect(sample[3].assembly!.repeatsFinalSegment, isTrue);
    expect(sample[3].assembly!.cycleIndex, 1);
    expect(() => sample.clear(), throwsUnsupportedError);
    expect(() => scenario.sampleChunks(count: 129), throwsRangeError);
    expect(
      scenario.sampleChunks().map((entry) => entry.chunkKey),
      sample.map((entry) => entry.chunkKey),
    );
    for (final seed in [1, 4401, 8273]) {
      final runtime = scenario.buildRuntimeLevelDefinition();
      final source = runtime.chunkPatternSource;
      expect(
        List.generate(
          12,
          (index) => source
              .patternFor(
                seed: seed,
                chunkIndex: index,
                tier: index < 3
                    ? ChunkPatternTier.early
                    : ChunkPatternTier.hard,
              )
              .chunkKey,
        ),
        ['a', 'a', ...List.filled(10, 'b')],
      );
      expect(runtime.cameraCenterY, 137);
      expect(runtime.earlyPatternChunks, 3);
      expect(runtime.noEnemyChunks, 3);
    }
    _expectSameRun(
      GameCore.levelPlaytest(scenario: scenario),
      GameCore.levelPlaytest(scenario: scenario),
    );
    expect(
      () => scenario.terrainCatalog.chunksByKey.clear(),
      throwsUnsupportedError,
    );
  });

  test('complete pool is admitted before Core, including unsampled chunks', () {
    final level = _level(patterns: [_pattern('a'), _pattern('b')]);
    for (final bad in [
      _terrain('b', levelId: 'another_level'),
      _terrain('b', status: 'deprecated'),
      _terrain('b', width: 599),
      _terrain('b', group: 'wrong'),
      _terrain('b', difficulty: 'hard'),
    ]) {
      expect(
        () => _scenario(level: level, chunks: [_terrain('a'), bad]),
        throwsA(isA<PlaytestScenarioException>()),
      );
    }
    expect(
      () => _scenario(level: level, chunks: [_terrain('a')]),
      throwsA(isA<PlaytestScenarioException>()),
    );
    expect(
      () => _scenario(level: level, chunks: [_terrain('a'), _terrain('a')]),
      throwsArgumentError,
    );
    expect(
      () => _scenario(
        level: _level(patterns: [_pattern('a'), _pattern('a')]),
        chunks: [_terrain('a')],
      ),
      throwsA(isA<PlaytestScenarioException>()),
    );
    expect(
      () => _scenario(
        level: _level(patterns: []),
        chunks: [],
      ),
      throwsA(isA<PlaytestScenarioException>()),
    );
  });

  test('distinct capacity and every reachable boundary remain mandatory', () {
    final assembly = LevelAssemblyDefinition(
      segments: [
        const LevelAssemblySegment(
          segmentId: 'unique',
          groupId: 'default',
          minChunkCount: 2,
          maxChunkCount: 2,
          requireDistinctChunks: true,
        ),
      ],
    );
    expect(
      () => _scenario(level: _level(assembly: assembly)),
      throwsA(
        isA<PlaytestScenarioException>().having(
          (error) => error.code,
          'code',
          contains('distinct'),
        ),
      ),
    );
    expect(
      () => _scenario(
        level: _level(patterns: [_pattern('a'), _pattern('b')]),
        chunks: [_terrain('a'), _terrain('b', breakRightBoundary: true)],
      ),
      throwsA(
        isA<PlaytestScenarioException>().having(
          (error) => error.code,
          'code',
          'staged_reachable_seam_mismatch',
        ),
      ),
    );
  });
}

LevelPlaytestScenario _scenario({
  LevelDefinition? level,
  Iterable<StagedTerrainChunkData>? chunks,
}) => LevelPlaytestScenario(
  levelDefinition: level ?? _level(),
  terrainChunks: chunks ?? [_terrain('a')],
  seed: 4401,
  playerCharacter: _player,
  equippedLoadout: _loadout,
);

LevelDefinition _level({
  String identity = _levelName,
  List<ChunkPattern>? patterns,
  LevelAssemblyDefinition? assembly,
}) => LevelDefinition.authored(
  identity: AuthoredLevelIdentity(identity),
  groundTopY: 224,
  cameraCenterY: 137,
  earlyPatternChunks: 3,
  easyPatternChunks: 2,
  normalPatternChunks: 4,
  noEnemyChunks: 3,
  visualThemeId: 'new_background',
  chunkPatternSource: ChunkPatternListSource(
    earlyPatterns: patterns ?? [_pattern('a')],
    easyPatterns: const [],
  ),
  assembly: assembly,
);

ChunkPattern _pattern(String key, {String group = 'default'}) => ChunkPattern(
  name: key,
  chunkKey: key,
  assemblyGroupId: group,
  spawnMarkers: const [
    SpawnMarker(
      enemyId: EnemyId.grojib,
      x: 300,
      chancePercent: 100,
      salt: 99173,
    ),
  ],
);

void _expectSameRun(GameCore first, GameCore second) {
  for (var tick = 0; tick < 480; tick++) {
    final a = first.buildSnapshot();
    final b = second.buildSnapshot();
    expect(
      [
        a.tick,
        a.levelIdentity,
        a.visualThemeId,
        a.distance,
        a.gameOver,
        a.camera.centerX,
        a.camera.centerY,
        a.hud.hp,
        a.hud.mana,
        a.hud.stamina,
        for (final e in a.entities) '${e.id}|${e.kind}|${e.pos.x}|${e.pos.y}',
      ],
      [
        b.tick,
        b.levelIdentity,
        b.visualThemeId,
        b.distance,
        b.gameOver,
        b.camera.centerX,
        b.camera.centerY,
        b.hud.hp,
        b.hud.mana,
        b.hud.stamina,
        for (final e in b.entities) '${e.id}|${e.kind}|${e.pos.x}|${e.pos.y}',
      ],
    );
    expect(
      first.drainEvents().map((e) => e.runtimeType.toString()),
      second.drainEvents().map((e) => e.runtimeType.toString()),
    );
    final commands = <Command>[
      MoveAxisCommand(tick: tick + 1, axis: 1),
      if (tick % 65 == 0) JumpPressedCommand(tick: tick + 1),
    ];
    first.applyCommands(commands);
    second.applyCommands(commands);
    first.stepOneTick();
    second.stepOneTick();
  }
}

// Preserve the compiled flat geometry while remapping all source lineage.
StagedTerrainChunkData _terrain(
  String key, {
  String levelId = _levelName,
  String status = 'active',
  int width = 600,
  String group = 'default',
  String difficulty = 'early',
  bool breakRightBoundary = false,
}) {
  final base = stagedAuthoredTerrain.chunks.firstWhere(
    (c) => c.levelId == 'forest',
  );
  StagedTerrainSourceId sourceId(StagedTerrainSourceId id) =>
      StagedTerrainSourceId(
        chunkKey: key,
        shapeId: id.shapeId,
        placementKey: id.placementKey,
      );
  StagedTerrainEdgeId? edgeId(StagedTerrainEdgeId? id) => id == null
      ? null
      : StagedTerrainEdgeId(
          sourceId: sourceId(id.sourceId),
          localEdgeIndex: id.localEdgeIndex,
          subEdgeIndex: id.subEdgeIndex,
        );
  StagedTerrainPoint point(StagedTerrainPoint p) =>
      breakRightBoundary && p.xTicks == base.width * 1024
      ? StagedTerrainPoint(p.xTicks - 1024, p.yTicks)
      : p;
  StagedTerrainEdgeData edge(StagedTerrainEdgeData e) => StagedTerrainEdgeData(
    id: edgeId(e.id)!,
    start: point(e.start),
    end: point(e.end),
    tangent: e.tangent,
    outwardNormal: e.outwardNormal,
    collisionMode: e.collisionMode,
    surfaceKind: e.surfaceKind,
    materialKey: e.materialKey,
    previousId: edgeId(e.previousId),
    nextId: edgeId(e.nextId),
    startJoin: e.startJoin,
    endJoin: e.endJoin,
  );
  return StagedTerrainChunkData(
    chunkKey: key,
    id: key,
    revision: 1,
    status: status,
    levelId: levelId,
    tileSize: base.tileSize,
    width: width,
    height: base.height,
    difficulty: difficulty,
    assemblyGroupId: group,
    authoringPolygonSignature: base.authoringPolygonSignature,
    sourceSignature: base.sourceSignature,
    edgeSignature: base.edgeSignature,
    renderEdgeSignature: base.renderEdgeSignature,
    placementSignature: base.placementSignature,
    triangleSignature: base.triangleSignature,
    polygons: base.polygons.map(
      (p) => StagedTerrainPolygonData(
        sourcePath: 'assets/authoring/level/chunks/$levelId/$key.json',
        id: sourceId(p.id),
        sourceVertices: p.sourceVertices,
        vertices: p.vertices,
        collisionMode: p.collisionMode,
        surfaceKind: p.surfaceKind,
        materialKey: p.materialKey,
      ),
    ),
    edges: base.edges.map(edge),
    renderEdges: base.renderEdges.map(edge),
    triangles: base.triangles.map(
      (t) => StagedTerrainTriangleData(
        sourceId: sourceId(t.sourceId),
        first: t.first,
        second: t.second,
        third: t.third,
      ),
    ),
    placementLineage: const [],
  );
}
