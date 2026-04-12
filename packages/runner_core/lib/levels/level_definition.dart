/// Data-first definition of a level configuration (Core-only).
library;

import '../collision/static_world_geometry.dart';
import '../track/chunk_pattern_defaults.dart';
import '../track/chunk_pattern_source.dart';
import '../tuning/core_tuning.dart';
import 'level_id.dart';
import 'level_assembly.dart';
import 'level_world_constants.dart';

/// Core configuration for a single level.
///
/// This is pure data: no Flutter/Flame imports and no runtime side effects.
class LevelDefinition {
  LevelDefinition({
    required this.id,
    required ChunkPatternSource chunkPatternSource,
    required this.staticWorldGeometry,
    this.tuning = const CoreTuning(),
    this.cameraCenterY = defaultLevelCameraCenterY,
    this.earlyPatternChunks = defaultEarlyPatternChunks,
    this.easyPatternChunks = defaultEasyPatternChunks,
    this.normalPatternChunks = defaultNormalPatternChunks,
    this.noEnemyChunks = defaultNoEnemyChunks,
    this.visualThemeId,
    LevelAssemblyDefinition? assembly,
  }) : assert(earlyPatternChunks >= 0),
       assert(easyPatternChunks >= 0),
       assert(normalPatternChunks >= 0),
       assert(noEnemyChunks >= 0),
       _baseChunkPatternSource = _normalizeBaseChunkPatternSource(
         chunkPatternSource: chunkPatternSource,
         assembly: assembly,
       ),
       _assembly = _normalizeAssembly(
         chunkPatternSource: chunkPatternSource,
         assembly: assembly,
       ),
       assert(
         staticWorldGeometry.groundPlane != null,
         'LevelDefinition.staticWorldGeometry.groundPlane must be set',
       ) {
    if (staticWorldGeometry.groundPlane == null) {
      throw StateError(
        'LevelDefinition($id) requires staticWorldGeometry.groundPlane',
      );
    }
  }

  /// Stable identifier for this level.
  final LevelId id;

  /// Core tuning overrides for this level.
  final CoreTuning tuning;

  /// Base collision geometry for the level (ground + fixed platforms).
  final StaticWorldGeometry staticWorldGeometry;

  /// World-space camera center Y for snapshot/render framing.
  final double cameraCenterY;

  /// Authoritative world-space ground top Y for gameplay and spawning.
  ///
  /// This is derived from [staticWorldGeometry.groundPlane] and is guaranteed
  /// to exist by constructor validation.
  double get groundTopY => staticWorldGeometry.groundPlane!.topY;

  /// Pattern pool used for procedural chunk generation.
  final ChunkPatternSource _baseChunkPatternSource;

  /// Pattern pool used for procedural chunk generation.
  ///
  /// When [assembly] is authored, this derives the effective assembled source
  /// from the base authored chunk list instead of storing a second independent
  /// assembly copy on the source itself.
  ChunkPatternSource get chunkPatternSource =>
      _resolveChunkPatternSource(_baseChunkPatternSource, _assembly);

  /// Number of early chunks that use "early" chunk patterns.
  final int earlyPatternChunks;

  /// Number of chunks after the opening window that request `easy` patterns.
  final int easyPatternChunks;

  /// Number of chunks after the easy window that request `normal` patterns.
  final int normalPatternChunks;

  /// Number of early chunks that suppress enemy spawns.
  final int noEnemyChunks;

  /// Optional render theme identifier (e.g., lookup key for assets).
  final String? visualThemeId;

  /// Optional authored chunk assembly scheduler for this level.
  final LevelAssemblyDefinition? _assembly;

  /// Optional authored chunk assembly scheduler for this level.
  LevelAssemblyDefinition? get assembly => _assembly;

  /// Returns a copy with selected fields overridden.
  LevelDefinition copyWith({
    LevelId? id,
    CoreTuning? tuning,
    double? cameraCenterY,
    StaticWorldGeometry? staticWorldGeometry,
    ChunkPatternSource? chunkPatternSource,
    int? earlyPatternChunks,
    int? easyPatternChunks,
    int? normalPatternChunks,
    int? noEnemyChunks,
    String? visualThemeId,
    LevelAssemblyDefinition? assembly,
  }) {
    return LevelDefinition(
      id: id ?? this.id,
      chunkPatternSource: chunkPatternSource ?? _baseChunkPatternSource,
      tuning: tuning ?? this.tuning,
      cameraCenterY: cameraCenterY ?? this.cameraCenterY,
      staticWorldGeometry: staticWorldGeometry ?? this.staticWorldGeometry,
      earlyPatternChunks: earlyPatternChunks ?? this.earlyPatternChunks,
      easyPatternChunks: easyPatternChunks ?? this.easyPatternChunks,
      normalPatternChunks: normalPatternChunks ?? this.normalPatternChunks,
      noEnemyChunks: noEnemyChunks ?? this.noEnemyChunks,
      visualThemeId: visualThemeId ?? this.visualThemeId,
      assembly: assembly ?? this.assembly,
    );
  }
}

ChunkPatternSource _normalizeBaseChunkPatternSource({
  required ChunkPatternSource chunkPatternSource,
  required LevelAssemblyDefinition? assembly,
}) {
  if (chunkPatternSource case final AssembledChunkPatternSource assembled) {
    if (assembly != null && !_assembliesEqual(assembled.assembly, assembly)) {
      throw ArgumentError(
        'LevelDefinition received conflicting assembly definitions in '
        'chunkPatternSource and assembly.',
      );
    }
    return assembled.baseSource;
  }
  if (assembly != null &&
      assembly.segments.isNotEmpty &&
      chunkPatternSource is! ChunkPatternListSource) {
    throw ArgumentError(
      'LevelDefinition assembly requires a ChunkPatternListSource base source.',
    );
  }
  return chunkPatternSource;
}

LevelAssemblyDefinition? _normalizeAssembly({
  required ChunkPatternSource chunkPatternSource,
  required LevelAssemblyDefinition? assembly,
}) {
  if (chunkPatternSource case final AssembledChunkPatternSource assembled) {
    return assembled.assembly;
  }
  if (assembly == null || assembly.segments.isEmpty) {
    return null;
  }
  return assembly;
}

ChunkPatternSource _resolveChunkPatternSource(
  ChunkPatternSource baseSource,
  LevelAssemblyDefinition? assembly,
) {
  if (assembly == null || assembly.segments.isEmpty) {
    return baseSource;
  }
  if (baseSource is! ChunkPatternListSource) {
    throw StateError(
      'LevelDefinition assembly requires a ChunkPatternListSource base source.',
    );
  }
  return AssembledChunkPatternSource(
    baseSource: baseSource,
    assembly: assembly,
  );
}

bool _assembliesEqual(
  LevelAssemblyDefinition left,
  LevelAssemblyDefinition right,
) {
  if (left.loopSegments != right.loopSegments ||
      left.segments.length != right.segments.length) {
    return false;
  }
  for (var i = 0; i < left.segments.length; i += 1) {
    if (!_assemblySegmentsEqual(left.segments[i], right.segments[i])) {
      return false;
    }
  }
  return true;
}

bool _assemblySegmentsEqual(
  LevelAssemblySegment left,
  LevelAssemblySegment right,
) {
  return left.segmentId == right.segmentId &&
      left.groupId == right.groupId &&
      left.minChunkCount == right.minChunkCount &&
      left.maxChunkCount == right.maxChunkCount &&
      left.requireDistinctChunks == right.requireDistinctChunks;
}
