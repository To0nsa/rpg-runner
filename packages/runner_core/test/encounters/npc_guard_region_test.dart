import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/npcs/npc_guard_region.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  test(
    'section region includes earlier/later chunks at a nonzero world origin',
    () {
      final region = NpcGuardRegion.forChunk(
        chunkIndex: 8,
        startX: 4900,
        endX: 5500,
        assembly: _assembly(start: 7),
      );
      expect((region.firstChunkIndex, region.chunkCount), (7, 3));
      expect((region.minX, region.maxX), (4300, 6100));
      expect(region.contains(4300), isTrue);
      expect(region.contains(6099), isTrue);
      expect(region.contains(6100), isFalse);
    },
  );

  test('automatic and standalone chunks retain their actual width', () {
    final region = NpcGuardRegion.forChunk(
      chunkIndex: 3,
      startX: 1400,
      endX: 1800,
    );
    expect((region.firstChunkIndex, region.chunkCount), (3, 1));
    expect((region.minX, region.maxX), (1400, 1800));
  });

  test('repeated source sections have independent world bounds', () {
    final first = NpcGuardRegion.forChunk(
      chunkIndex: 7,
      startX: 4200,
      endX: 4800,
      assembly: _assembly(start: 7),
    );
    final repeated = NpcGuardRegion.forChunk(
      chunkIndex: 10,
      startX: 6000,
      endX: 6600,
      assembly: _assembly(start: 10),
    );
    expect(first.contains(repeated.minX), isFalse);
    expect(repeated.contains(first.maxX - 1), isFalse);
  });

  test('an occurrence outside its selected section is rejected', () {
    expect(
      () => NpcGuardRegion.forChunk(
        chunkIndex: 6,
        startX: 3600,
        endX: 4200,
        assembly: _assembly(start: 7),
      ),
      throwsArgumentError,
    );
    expect(
      () => NpcGuardRegion.forChunk(
        chunkIndex: 0,
        startX: 0,
        endX: double.infinity,
      ),
      throwsArgumentError,
    );
  });

  test(
    'actual and speculative streaming retain identical section occurrences',
    () {
      final streamer = TrackStreamer(
        seed: 42,
        tuning: const TrackTuning(
          chunkWidth: 600,
          spawnAheadMargin: 0,
          cullBehindMargin: 0,
        ),
        groundTopY: 200,
        patternSource: AssembledChunkPatternSource(
          baseSource: const ChunkPatternListSource(
            easyPatterns: [ChunkPattern(name: 'camp', assemblyGroupId: 'camp')],
          ),
          assembly: const LevelAssemblyDefinition(
            segments: [
              LevelAssemblySegment(
                segmentId: 'camp_section',
                groupId: 'camp',
                minChunkCount: 3,
                maxChunkCount: 3,
                requireDistinctChunks: false,
              ),
            ],
          ),
        ),
        earlyPatternChunks: 0,
        noEnemyChunks: 0,
      );
      streamer.step(cameraLeft: 0, cameraRight: 600, spawnEnemy: (_) {});
      final futures = streamer.upcomingSelections(viewWidth: 600, count: 8);
      for (final chunks in futures) {
        for (final chunk in chunks) {
          final section = chunk.assembly!;
          expect(section.segmentId, 'camp_section');
          expect(section.startChunkIndex, chunk.index ~/ 3 * 3);
          expect(section.chunkCount, 3);
          expect(section.runSequence, chunk.index ~/ 3);
        }
      }
      streamer.step(cameraLeft: 1801, cameraRight: 2401, spawnEnemy: (_) {});
      for (final chunk in streamer.activeChunks) {
        final projected = futures
            .expand((s) => s)
            .firstWhere((c) => c.index == chunk.index);
        expect(_identity(chunk.assembly!), _identity(projected.assembly!));
      }
    },
  );
}

ChunkAssemblySelection _assembly({required int start}) =>
    ChunkAssemblySelection(
      segmentId: 'camp',
      segmentIndex: 0,
      runSequence: start,
      cycleIndex: start,
      startChunkIndex: start,
      chunkCount: 3,
      repeatsFinalSegment: false,
    );

Object _identity(ChunkAssemblySelection s) =>
    (s.segmentId, s.runSequence, s.startChunkIndex, s.chunkCount, s.cycleIndex);
