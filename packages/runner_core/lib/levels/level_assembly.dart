/// Runtime-authored level assembly sequencing contracts.
library;

/// Authored chunk run definition for a level assembly sequence.
class LevelAssemblySegment {
  const LevelAssemblySegment({
    required this.segmentId,
    required this.groupId,
    required this.minChunkCount,
    required this.maxChunkCount,
    required this.requireDistinctChunks,
  }) : assert(minChunkCount > 0),
       assert(maxChunkCount > 0),
       assert(maxChunkCount >= minChunkCount);

  final String segmentId;
  final String groupId;
  final int minChunkCount;
  final int maxChunkCount;
  final bool requireDistinctChunks;
}

/// Full authored segment scheduler definition for a level.
class LevelAssemblyDefinition {
  const LevelAssemblyDefinition({
    this.loopSegments = true,
    this.segments = const <LevelAssemblySegment>[],
  });

  final bool loopSegments;
  final List<LevelAssemblySegment> segments;
}
