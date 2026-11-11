import 'chunk_pattern.dart';
import 'chunk_pattern_source.dart';

/// One authored occurrence, independent from the identity of its source chunk.
/// Reusing a chunk requires a new occurrence ID, not a new chunk definition.
final class FiniteChunkOccurrence {
  FiniteChunkOccurrence({
    required this.id,
    required this.sourceLevelId,
    required ChunkPattern pattern,
    required this.tier,
  }) : pattern = pattern.immutableCopy() {
    for (final (name, value) in [
      ('id', id),
      ('sourceLevelId', sourceLevelId),
      ('chunkKey', pattern.chunkKey),
    ]) {
      if (value == null || value.isEmpty || value.trim() != value) {
        throw ArgumentError.value(value, name, 'Requires a stable identity.');
      }
    }
  }

  final String id;
  final String sourceLevelId;
  final ChunkPattern pattern;
  final ChunkPatternTier tier;
}

/// Exact finite selection: no seed choice, difficulty fallback or repeating tail.
///
/// This captures scheduler metadata, not terrain admission. Its caller must
/// validate each occurrence's owner, compiled terrain and actual adjacent seams
/// before constructing a playable mission. Runner pool membership is unchanged.
final class FiniteChunkPatternSource extends ChunkPatternSource {
  FiniteChunkPatternSource(Iterable<FiniteChunkOccurrence> occurrences)
    : occurrences = List.unmodifiable(occurrences) {
    if (this.occurrences.isEmpty) {
      throw ArgumentError('A finite route requires at least one occurrence.');
    }
    final ids = <String>{};
    for (final occurrence in this.occurrences) {
      if (!ids.add(occurrence.id)) {
        throw ArgumentError.value(
          occurrence.id,
          'occurrences',
          'Occurrence IDs must be unique within the route.',
        );
      }
    }
  }

  final List<FiniteChunkOccurrence> occurrences;
  int get length => occurrences.length;

  @override
  ChunkPatternSelection selectionFor({
    required int seed,
    required int chunkIndex,
    required ChunkPatternTier tier,
  }) {
    RangeError.checkValidIndex(chunkIndex, occurrences, 'chunkIndex');
    final occurrence = occurrences[chunkIndex];
    return ChunkPatternSelection(
      pattern: occurrence.pattern,
      tier: occurrence.tier,
      occurrenceId: occurrence.id,
    );
  }
}
