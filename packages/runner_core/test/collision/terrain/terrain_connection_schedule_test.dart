import 'dart:io';

import 'package:runner_core/collision/terrain/terrain_authoring_scheduler.dart';
import 'package:runner_core/collision/terrain/terrain_connection_schedule.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

void main() {
  test('exact state budget fails deterministically for a combinatorial distinct pool', () {
    for (var attempt = 0; attempt < 2; attempt++) {
      expect(
        () => build(
          {for (var i = 0; i < 16; i++) 'flat_$i': ('normal', 'normal')},
          segments: [
            const TerrainAuthoringSchedulerSegment(
              segmentId: 'large',
              groupId: 'default',
              minChunkCount: 8,
              maxChunkCount: 8,
              requireDistinctChunks: true,
            ),
          ],
        ),
        throwsA(
          isA<TerrainConnectionException>().having(
            (error) => error.code,
            'code',
            'terrain_authoring_scheduler_analysis_capacity_exceeded',
          ),
        ),
      );
    }
  });

  test(
    'contract digest changes for counts even when reachable pairs agree',
    () {
      final profiles = {'a': ('normal', 'normal'), 'b': ('normal', 'normal')};
      TerrainConnectionSchedule schedule(int count) => build(
        profiles,
        segments: [
          TerrainAuthoringSchedulerSegment(
            segmentId: 'flat',
            groupId: 'default',
            minChunkCount: count,
            maxChunkCount: count,
            requireDistinctChunks: false,
          ),
        ],
      );
      final one = schedule(1);
      final two = schedule(2);
      expect(
        one.transitions.map(
          (pair) => '${pair.leftChunkKey}>${pair.rightChunkKey}',
        ),
        two.transitions.map(
          (pair) => '${pair.leftChunkKey}>${pair.rightChunkKey}',
        ),
      );
      expect(one.contractDigest, isNot(two.contractDigest));
    },
  );

  test('long streaming and repeated queries retain the same continuation', () {
    final watch = Stopwatch()..start();
    final plan = build(
      {for (var i = 0; i < 10; i++) 'flat_$i': ('normal', 'normal')},
      segments: [
        const TerrainAuthoringSchedulerSegment(
          segmentId: 'distinct',
          groupId: 'default',
          minChunkCount: 4,
          maxChunkCount: 4,
          requireDistinctChunks: true,
        ),
      ],
    );
    final analysisMicros = watch.elapsedMicroseconds;
    watch.reset();
    final cursor = plan.cursor(77);
    for (var index = 0; index < 100000; index += 4) {
      expect({
        for (var offset = 0; offset < 4; offset++)
          cursor.selectionFor(index + offset).chunk.chunkKey,
      }, hasLength(4));
    }
    final last = cursor.selectionFor(99999).chunk.chunkKey;
    expect(plan.cursor(77).selectionFor(99999).chunk.chunkKey, last);
    // A diagnostic measurement, never a wall-clock admission rule.
    stdout.writeln(
      'CONNECTION_PROFILE states=${plan.stateCount} edges=${plan.edgeCount} analysis_us=$analysisMicros streaming_200k_us=${watch.elapsedMicroseconds}',
    );
  });
  test(
    'filters a matching successor with no future exit and retains a hill loop',
    () {
      final plan = build({
        'up': ('normal', 'high'),
        'down': ('high', 'normal'),
        'trap': ('high', 'missing'),
      });
      expect(
        plan.transitions.any((edge) => edge.rightChunkKey == 'trap'),
        isFalse,
      );
      expect(
        plan.transitionExclusions('up', 'trap').single,
        contains('future section'),
      );
      expect(plan.transitionExclusions('up', 'down'), isEmpty);
      expect(
        plan.transitionExclusions('trap', 'down').single,
        contains('no reachable occurrence'),
      );
      final cursor = plan.cursor(17);
      expect(
        [for (var i = 0; i < 20; i++) cursor.selectionFor(i).chunk.chunkKey],
        [
          for (var i = 0; i < 10; i++) ...['up', 'down'],
        ],
      );
      final witness = plan.witnessThrough('down')!;
      expect(witness.chunkKeys[witness.selectedIndex], 'down');
      expect(witness.loopStartIndex, lessThan(witness.chunkKeys.length));
    },
  );

  test(
    'equal heights cannot substitute for complete matching physical profiles',
    () {
      expect(
        () => build({
          'up': ('normal', 'high:solid'),
          'down': ('high:oneWay', 'normal'),
        }),
        throwsA(isA<TerrainConnectionException>()),
      );
    },
  );

  test('every authored length must permit continuation across sections', () {
    final segments = [
      const TerrainAuthoringSchedulerSegment(
        segmentId: 'climb',
        groupId: 'default',
        minChunkCount: 1,
        maxChunkCount: 2,
        requireDistinctChunks: true,
      ),
      const TerrainAuthoringSchedulerSegment(
        segmentId: 'flat',
        groupId: 'plateau',
        minChunkCount: 1,
        maxChunkCount: 1,
        requireDistinctChunks: false,
      ),
    ];
    expect(
      () => build(
        {
          'up': ('normal', 'high'),
          'down': ('high', 'normal'),
          'flat': ('high', 'high'),
        },
        segments: segments,
        groups: {'flat': 'plateau'},
      ),
      throwsA(isA<TerrainConnectionException>()),
    );
  });

  test(
    'Flow uses the next section pool and prunes incompatible predecessors',
    () {
      final plan = build(
        {
          'good': ('normal', 'high'),
          'trap': ('normal', 'missing'),
          'next': ('high', 'normal'),
        },
        segments: [
          const TerrainAuthoringSchedulerSegment(
            segmentId: 'grove',
            groupId: 'grove',
            difficulty: ChunkPatternTier.easy,
            minChunkCount: 1,
            maxChunkCount: 1,
            requireDistinctChunks: false,
          ),
          const TerrainAuthoringSchedulerSegment(
            segmentId: 'ruin',
            groupId: 'ruin',
            difficulty: ChunkPatternTier.hard,
            minChunkCount: 1,
            maxChunkCount: 1,
            requireDistinctChunks: false,
          ),
        ],
        groups: {'good': 'grove', 'trap': 'grove', 'next': 'ruin'},
        tiers: {
          'good': ChunkPatternTier.easy,
          'trap': ChunkPatternTier.easy,
          'next': ChunkPatternTier.hard,
        },
      );
      expect(plan.reachableChunkKeys, {'good', 'next'});
      final cursor = plan.cursor(17);
      expect(
        [for (var i = 0; i < 12; i++) cursor.selectionFor(i).chunk.chunkKey],
        [
          for (var i = 0; i < 6; i++) ...['good', 'next'],
        ],
      );
      expect(plan.transitionExclusions('good', 'trap'), isNotEmpty);
    },
  );

  test('distinctness and repeated section boundary are proven together', () {
    final plan = build(
      {'up': ('normal', 'high'), 'down': ('high', 'normal')},
      segments: [
        const TerrainAuthoringSchedulerSegment(
          segmentId: 'hill',
          groupId: 'default',
          minChunkCount: 2,
          maxChunkCount: 2,
          requireDistinctChunks: true,
        ),
      ],
    );
    final cursor = plan.cursor(9);
    for (var i = 0; i < 100; i += 2) {
      expect(cursor.selectionFor(i).chunk.chunkKey, 'up');
      expect(cursor.selectionFor(i + 1).chunk.chunkKey, 'down');
    }
  });

  test('selection does not depend on query order or source ordering', () {
    final inputs = {
      'a': ('normal', 'normal'),
      'b': ('normal', 'normal'),
      'up': ('normal', 'high'),
      'down': ('high', 'normal'),
    };
    final plan = build(inputs);
    final cursor = plan.cursor(37);
    final expected = [
      for (var i = 0; i < 500; i++) cursor.selectionFor(i).chunk.chunkKey,
    ];
    for (final i in [400, 0, 7, 7, 100, 2, 499]) {
      expect(cursor.selectionFor(i).chunk.chunkKey, expected[i]);
    }
    final reversed = build(Map.fromEntries(inputs.entries.toList().reversed))
        .cursor(37);
    expect([
      for (var i = 0; i < 500; i++) reversed.selectionFor(i).chunk.chunkKey,
    ], expected);
  });
}

TerrainConnectionSchedule build(
  Map<String, (String, String)> profiles, {
  List<TerrainAuthoringSchedulerSegment>? segments,
  Map<String, String> groups = const {},
  Map<String, ChunkPatternTier> tiers = const {},
}) => TerrainConnectionSchedule.build(
  level: TerrainAuthoringSchedulerLevel(
    levelId: 'test',
    earlyPatternChunks: 0,
    easyPatternChunks: 0,
    normalPatternChunks: 0,
    assembly: segments == null
        ? null
        : TerrainAuthoringSchedulerAssembly(
            loopSegments: true,
            segments: segments,
          ),
  ),
  chunks: profiles.keys.map(
    (key) => TerrainAuthoringSchedulerChunk(
      chunkKey: key,
      levelId: 'test',
      tier: tiers[key] ?? ChunkPatternTier.hard,
      assemblyGroupId: groups[key] ?? 'default',
      isActive: true,
    ),
  ),
  connections: profiles.map(
    (key, value) => MapEntry(
      key,
      TerrainChunkConnection(
        entrance: value.$1,
        exit: value.$2,
        canStart: value.$1 == 'normal',
      ),
    ),
  ),
);
