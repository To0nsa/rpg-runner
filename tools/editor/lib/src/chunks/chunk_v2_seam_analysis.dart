import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';

import '../domain/authoring_types.dart';
import '../levels/level_domain_models.dart';
import '../terrain_authoring/terrain_physics_text.dart';
import 'chunk_domain_models.dart';
import 'chunk_v2_collision_expansion.dart';
import 'chunk_v2_file_data.dart';

const int _maxAssemblyFiniteWindowChunks = 256;

/// Side of a chunk-local compiled boundary.
enum ChunkV2BoundarySide { left, right }

/// One normalized positive-length interval occupied on a chunk boundary.
@immutable
final class ChunkV2BoundaryInterval
    implements Comparable<ChunkV2BoundaryInterval> {
  const ChunkV2BoundaryInterval({
    required this.collisionMode,
    required this.minYTicks,
    required this.maxYTicks,
  });

  final TerrainCollisionMode collisionMode;
  final int minYTicks;
  final int maxYTicks;

  String get canonicalRecord => '${collisionMode.name}:$minYTicks..$maxYTicks';

  @override
  int compareTo(ChunkV2BoundaryInterval other) {
    var order = collisionMode.index.compareTo(other.collisionMode.index);
    if (order != 0) return order;
    order = minYTicks.compareTo(other.minYTicks);
    return order != 0 ? order : maxYTicks.compareTo(other.maxYTicks);
  }

  @override
  bool operator ==(Object other) =>
      other is ChunkV2BoundaryInterval &&
      collisionMode == other.collisionMode &&
      minYTicks == other.minYTicks &&
      maxYTicks == other.maxYTicks;

  @override
  int get hashCode => Object.hash(collisionMode, minYTicks, maxYTicks);
}

/// One boundary endpoint that must find compatible cross-chunk continuation.
@immutable
final class ChunkV2BoundaryVertex implements Comparable<ChunkV2BoundaryVertex> {
  const ChunkV2BoundaryVertex({
    required this.collisionMode,
    required this.surfaceKind,
    required this.yTicks,
  });

  final TerrainCollisionMode collisionMode;
  final String? surfaceKind;
  final int yTicks;

  String get canonicalRecord =>
      '${collisionMode.name}:${surfaceKind ?? ''}:$yTicks';

  @override
  int compareTo(ChunkV2BoundaryVertex other) {
    var order = collisionMode.index.compareTo(other.collisionMode.index);
    if (order != 0) return order;
    order = (surfaceKind ?? '').compareTo(other.surfaceKind ?? '');
    return order != 0 ? order : yTicks.compareTo(other.yTicks);
  }

  @override
  bool operator ==(Object other) =>
      other is ChunkV2BoundaryVertex &&
      collisionMode == other.collisionMode &&
      surfaceKind == other.surfaceKind &&
      yTicks == other.yTicks;

  @override
  int get hashCode => Object.hash(collisionMode, surfaceKind, yTicks);
}

/// Canonical evidence for one side of accepted compiled chunk geometry.
///
/// Physical compatibility uses normalized [coverageIntervals] and
/// [continuationVertices]. [edgeRecords] preserve exact compiled geometry and
/// material metadata for diagnostics without making render material phase a
/// Phase 4 blocking rule.
@immutable
final class ChunkV2BoundarySignature {
  ChunkV2BoundarySignature({
    required this.chunkKey,
    required this.side,
    required Iterable<ChunkV2BoundaryInterval> coverageIntervals,
    required Iterable<ChunkV2BoundaryVertex> continuationVertices,
    required Iterable<String> edgeRecords,
    required Map<ChunkV2BoundaryVertex, Iterable<String?>> materialKeysByVertex,
  }) : coverageIntervals = List<ChunkV2BoundaryInterval>.unmodifiable(
         List<ChunkV2BoundaryInterval>.of(coverageIntervals)..sort(),
       ),
       continuationVertices = List<ChunkV2BoundaryVertex>.unmodifiable(
         List<ChunkV2BoundaryVertex>.of(continuationVertices)..sort(),
       ),
       edgeRecords = List<String>.unmodifiable(
         List<String>.of(edgeRecords)..sort(),
       ),
       materialKeysByVertex =
           Map<ChunkV2BoundaryVertex, List<String?>>.unmodifiable(<
             ChunkV2BoundaryVertex,
             List<String?>
           >{
             for (final entry in materialKeysByVertex.entries)
               entry.key: List<String?>.unmodifiable(
                 entry.value.toSet().toList()
                   ..sort((left, right) => (left ?? '').compareTo(right ?? '')),
               ),
           }) {
    final canonical = <String>[
      'authoring-boundary-v1',
      'side=${side.name}',
      if (isEmpty) 'empty',
      for (final interval in this.coverageIntervals)
        'coverage=${interval.canonicalRecord}',
      for (final vertex in this.continuationVertices)
        'vertex=${vertex.canonicalRecord}',
      for (final record in this.edgeRecords) 'edge=$record',
    ].join('\n');
    canonicalRecord = canonical;
    digest = sha256.convert(utf8.encode(canonical)).toString();
  }

  final String chunkKey;
  final ChunkV2BoundarySide side;
  final List<ChunkV2BoundaryInterval> coverageIntervals;
  final List<ChunkV2BoundaryVertex> continuationVertices;
  final List<String> edgeRecords;
  final Map<ChunkV2BoundaryVertex, List<String?>> materialKeysByVertex;
  late final String canonicalRecord;
  late final String digest;

  bool get isEmpty => coverageIntervals.isEmpty && continuationVertices.isEmpty;

  String get physicalRecord => <String>[
    if (isEmpty) 'empty',
    for (final interval in coverageIntervals)
      'coverage=${interval.canonicalRecord}',
    for (final vertex in continuationVertices)
      'vertex=${vertex.canonicalRecord}',
  ].join(';');
}

/// Exact physical comparison of a right boundary against a left boundary.
@immutable
final class ChunkV2BoundaryComparison {
  ChunkV2BoundaryComparison({
    required this.left,
    required this.right,
    required Iterable<ChunkV2BoundaryInterval> leftOnlyIntervals,
    required Iterable<ChunkV2BoundaryInterval> rightOnlyIntervals,
    required Iterable<ChunkV2BoundaryVertex> leftOnlyVertices,
    required Iterable<ChunkV2BoundaryVertex> rightOnlyVertices,
    required Iterable<ChunkV2BoundaryVertex> materialMismatchVertices,
  }) : leftOnlyIntervals = List<ChunkV2BoundaryInterval>.unmodifiable(
         leftOnlyIntervals,
       ),
       rightOnlyIntervals = List<ChunkV2BoundaryInterval>.unmodifiable(
         rightOnlyIntervals,
       ),
       leftOnlyVertices = List<ChunkV2BoundaryVertex>.unmodifiable(
         leftOnlyVertices,
       ),
       rightOnlyVertices = List<ChunkV2BoundaryVertex>.unmodifiable(
         rightOnlyVertices,
       ),
       materialMismatchVertices = List<ChunkV2BoundaryVertex>.unmodifiable(
         materialMismatchVertices,
       );

  final ChunkV2BoundarySignature left;
  final ChunkV2BoundarySignature right;
  final List<ChunkV2BoundaryInterval> leftOnlyIntervals;
  final List<ChunkV2BoundaryInterval> rightOnlyIntervals;
  final List<ChunkV2BoundaryVertex> leftOnlyVertices;
  final List<ChunkV2BoundaryVertex> rightOnlyVertices;
  final List<ChunkV2BoundaryVertex> materialMismatchVertices;

  bool get isCompatible =>
      leftOnlyIntervals.isEmpty &&
      rightOnlyIntervals.isEmpty &&
      leftOnlyVertices.isEmpty &&
      rightOnlyVertices.isEmpty;

  List<int> get mismatchYTicks {
    final values = <int>{};
    for (final interval in <ChunkV2BoundaryInterval>[
      ...leftOnlyIntervals,
      ...rightOnlyIntervals,
    ]) {
      values
        ..add(interval.minYTicks)
        ..add(interval.maxYTicks);
    }
    for (final vertex in <ChunkV2BoundaryVertex>[
      ...leftOnlyVertices,
      ...rightOnlyVertices,
    ]) {
      values.add(vertex.yTicks);
    }
    return List<int>.unmodifiable(values.toList()..sort());
  }
}

/// Structural scheduler provenance for one directed reachable chunk pair.
@immutable
final class ChunkV2ReachableTransition {
  const ChunkV2ReachableTransition({
    required this.levelId,
    required this.transitionId,
    required this.description,
    required this.leftChunkKey,
    required this.rightChunkKey,
  });

  final String levelId;
  final String transitionId;
  final String description;
  final String leftChunkKey;
  final String rightChunkKey;

  String get canonicalRecord =>
      '$levelId|$transitionId|$leftChunkKey>$rightChunkKey';
}

/// One scheduler-reachable seam and its compiled physical comparison.
@immutable
final class ChunkV2ReachableSeam {
  const ChunkV2ReachableSeam({
    required this.transition,
    required this.comparison,
  });

  final ChunkV2ReachableTransition transition;
  final ChunkV2BoundaryComparison comparison;
}

/// Immutable global scheduler/seam analysis shared by validation and UI.
@immutable
final class ChunkV2SeamAnalysis {
  ChunkV2SeamAnalysis({
    required Map<String, ChunkV2BoundarySignature> leftSignaturesByChunkKey,
    required Map<String, ChunkV2BoundarySignature> rightSignaturesByChunkKey,
    required Iterable<ChunkV2ReachableTransition> transitions,
    required Iterable<ChunkV2ReachableSeam> seams,
    required Iterable<ValidationIssue> issues,
  }) : leftSignaturesByChunkKey = Map.unmodifiable(leftSignaturesByChunkKey),
       rightSignaturesByChunkKey = Map.unmodifiable(rightSignaturesByChunkKey),
       transitions = List.unmodifiable(transitions),
       seams = List.unmodifiable(seams),
       issues = List.unmodifiable(issues) {
    final records =
        this.transitions
            .map((transition) => transition.canonicalRecord)
            .toList()
          ..sort();
    reachableAdjacencyRecord = <String>[
      'authoring-seams-v1',
      ...records,
    ].join('\n');
    reachableAdjacencyDigest = sha256
        .convert(utf8.encode(reachableAdjacencyRecord))
        .toString();
  }

  final Map<String, ChunkV2BoundarySignature> leftSignaturesByChunkKey;
  final Map<String, ChunkV2BoundarySignature> rightSignaturesByChunkKey;
  final List<ChunkV2ReachableTransition> transitions;
  final List<ChunkV2ReachableSeam> seams;
  final List<ValidationIssue> issues;
  late final String reachableAdjacencyRecord;
  late final String reachableAdjacencyDigest;

  List<ChunkV2ReachableSeam> seamsForChunk(String chunkKey) =>
      List<ChunkV2ReachableSeam>.unmodifiable(
        seams.where(
          (seam) =>
              seam.transition.leftChunkKey == chunkKey ||
              seam.transition.rightChunkKey == chunkKey,
        ),
      );
}

/// Builds one canonical signature directly from accepted Core geometry.
ChunkV2BoundarySignature buildChunkV2BoundarySignature({
  required String chunkKey,
  required int chunkWidth,
  required TerrainGeometry geometry,
  required ChunkV2BoundarySide side,
}) {
  final boundaryXTicks = switch (side) {
    ChunkV2BoundarySide.left => 0,
    ChunkV2BoundarySide.right => chunkWidth * terrainPhysicsTicksPerWorldUnit,
  };
  final rawIntervals = <ChunkV2BoundaryInterval>[];
  final vertices = <ChunkV2BoundaryVertex>{};
  final edgeRecords = <String>[];
  final materialKeys = <ChunkV2BoundaryVertex, Set<String?>>{};

  for (final edge in geometry.edges) {
    final startOnBoundary = edge.start.xTicks == boundaryXTicks;
    final endOnBoundary = edge.end.xTicks == boundaryXTicks;
    if (!startOnBoundary && !endOnBoundary) continue;

    edgeRecords.add(_boundaryEdgeRecord(edge));
    if (startOnBoundary && endOnBoundary) {
      final minY = edge.start.yTicks < edge.end.yTicks
          ? edge.start.yTicks
          : edge.end.yTicks;
      final maxY = edge.start.yTicks > edge.end.yTicks
          ? edge.start.yTicks
          : edge.end.yTicks;
      if (minY != maxY) {
        rawIntervals.add(
          ChunkV2BoundaryInterval(
            collisionMode: edge.collisionMode,
            minYTicks: minY,
            maxYTicks: maxY,
          ),
        );
      }
      continue;
    }

    final point = startOnBoundary ? edge.start : edge.end;
    final vertex = ChunkV2BoundaryVertex(
      collisionMode: edge.collisionMode,
      surfaceKind: edge.surfaceKind,
      yTicks: point.yTicks,
    );
    vertices.add(vertex);
    materialKeys.putIfAbsent(vertex, () => <String?>{}).add(edge.materialKey);
  }

  return ChunkV2BoundarySignature(
    chunkKey: chunkKey,
    side: side,
    coverageIntervals: _mergeBoundaryIntervals(rawIntervals),
    continuationVertices: vertices,
    edgeRecords: edgeRecords,
    materialKeysByVertex: materialKeys,
  );
}

/// Compares the right side of [left] with the left side of [right].
ChunkV2BoundaryComparison compareChunkV2Boundaries({
  required ChunkV2BoundarySignature left,
  required ChunkV2BoundarySignature right,
}) {
  if (left.side != ChunkV2BoundarySide.right ||
      right.side != ChunkV2BoundarySide.left) {
    throw ArgumentError('Seams require a right signature followed by a left.');
  }
  final leftIntervals = left.coverageIntervals.toSet();
  final rightIntervals = right.coverageIntervals.toSet();
  final leftVertices = left.continuationVertices.toSet();
  final rightVertices = right.continuationVertices.toSet();
  final sharedVertices = leftVertices.intersection(rightVertices).toList()
    ..sort();
  final materialMismatches = sharedVertices
      .where((vertex) {
        final leftMaterials =
            left.materialKeysByVertex[vertex] ?? const <String?>[];
        final rightMaterials =
            right.materialKeysByVertex[vertex] ?? const <String?>[];
        return !_nullableStringListsEqual(leftMaterials, rightMaterials);
      })
      .toList(growable: false);

  return ChunkV2BoundaryComparison(
    left: left,
    right: right,
    leftOnlyIntervals: (leftIntervals.difference(rightIntervals).toList()
      ..sort()),
    rightOnlyIntervals: (rightIntervals.difference(leftIntervals).toList()
      ..sort()),
    leftOnlyVertices: (leftVertices.difference(rightVertices).toList()..sort()),
    rightOnlyVertices: (rightVertices.difference(leftVertices).toList()
      ..sort()),
    materialMismatchVertices: materialMismatches,
  );
}

/// Enumerates scheduler-reachable directed pairs and validates their seams.
ChunkV2SeamAnalysis analyzeChunkV2Seams({
  required Iterable<ChunkV2FileData> chunks,
  required Iterable<LevelDef> levels,
  required Map<String, ChunkV2CollisionExpansionResult>
  collisionExpansionByChunkKey,
  Map<String, String> sourcePathByChunkKey = const <String, String>{},
}) {
  final orderedChunks = List<ChunkV2FileData>.of(
    chunks.where((chunk) => chunk.status == chunkStatusActive),
  )..sort(_compareChunks);
  final orderedLevels = List<LevelDef>.of(levels)
    ..sort((left, right) => left.levelId.compareTo(right.levelId));
  final issues = <ValidationIssue>[];
  final leftSignatures = <String, ChunkV2BoundarySignature>{};
  final rightSignatures = <String, ChunkV2BoundarySignature>{};

  for (final chunk in orderedChunks) {
    final expansion = collisionExpansionByChunkKey[chunk.chunkKey]?.expansion;
    if (expansion == null) continue;
    leftSignatures[chunk.chunkKey] = buildChunkV2BoundarySignature(
      chunkKey: chunk.chunkKey,
      chunkWidth: chunk.width,
      geometry: expansion.geometry,
      side: ChunkV2BoundarySide.left,
    );
    rightSignatures[chunk.chunkKey] = buildChunkV2BoundarySignature(
      chunkKey: chunk.chunkKey,
      chunkWidth: chunk.width,
      geometry: expansion.geometry,
      side: ChunkV2BoundarySide.right,
    );
  }

  final levelById = <String, LevelDef>{
    for (final level in orderedLevels) level.levelId: level,
  };
  for (final levelId in orderedChunks.map((chunk) => chunk.levelId).toSet()) {
    if (levelById.containsKey(levelId)) continue;
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'chunk_v2_seam_level_context_missing',
        message:
            'Active chunks for level $levelId cannot be seam-validated because '
            'its authored LevelDef scheduler context is unavailable.',
      ),
    );
  }

  final transitions = <ChunkV2ReachableTransition>[];
  final issueKeys = <String>{};
  for (final level in orderedLevels) {
    final levelChunks = orderedChunks
        .where((chunk) => chunk.levelId == level.levelId)
        .toList(growable: false);
    if (levelChunks.isEmpty) continue;
    final enumerator = _SchedulerEnumerator(
      level: level,
      chunks: levelChunks,
      issues: issues,
      issueKeys: issueKeys,
    );
    transitions.addAll(enumerator.enumerate());
  }
  transitions.sort(_compareTransitions);

  final seams = <ChunkV2ReachableSeam>[];
  for (final transition in transitions) {
    final left = rightSignatures[transition.leftChunkKey];
    final right = leftSignatures[transition.rightChunkKey];
    if (left == null || right == null) continue;
    final comparison = compareChunkV2Boundaries(left: left, right: right);
    final seam = ChunkV2ReachableSeam(
      transition: transition,
      comparison: comparison,
    );
    seams.add(seam);
    if (!comparison.isCompatible) {
      final coordinates = comparison.mismatchYTicks
          .map(TerrainPhysicsText.formatTicks)
          .join(', ');
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_v2_reachable_seam_mismatch',
          message:
              'Level ${transition.levelId} transition '
              '${transition.transitionId} (${transition.description}) emits '
              '${transition.leftChunkKey}[right] -> '
              '${transition.rightChunkKey}[left], but compiled boundary '
              'coverage/continuation differs at y=[$coordinates] px. '
              'Expected/right ${left.digest} ${left.physicalRecord}; '
              'actual/left ${right.digest} ${right.physicalRecord}.',
          sourcePath: sourcePathByChunkKey[transition.leftChunkKey],
        ),
      );
    }
  }

  issues.sort(_compareValidationIssues);
  return ChunkV2SeamAnalysis(
    leftSignaturesByChunkKey: leftSignatures,
    rightSignaturesByChunkKey: rightSignatures,
    transitions: transitions,
    seams: seams,
    issues: issues,
  );
}

final class _SchedulerEnumerator {
  _SchedulerEnumerator({
    required this.level,
    required this.chunks,
    required this.issues,
    required this.issueKeys,
  });

  final LevelDef level;
  final List<ChunkV2FileData> chunks;
  final List<ValidationIssue> issues;
  final Set<String> issueKeys;

  List<ChunkV2ReachableTransition> enumerate() {
    final assembly = level.assembly;
    if (assembly == null || assembly.segments.isEmpty) {
      return _enumerateTierPools();
    }
    return _enumerateAssembly(assembly);
  }

  List<ChunkV2ReachableTransition> _enumerateTierPools() {
    final transitions = <ChunkV2ReachableTransition>[];
    final windows = <(ChunkPatternTier, int)>[
      (ChunkPatternTier.early, level.earlyPatternChunks),
      (ChunkPatternTier.easy, level.easyPatternChunks),
      (ChunkPatternTier.normal, level.normalPatternChunks),
    ].where((window) => window.$2 > 0).toList(growable: false);
    for (final window in windows) {
      if (window.$2 < 2) continue;
      _addPoolPairs(
        transitions,
        transitionId: 'tier=${window.$1.name}:within-window',
        description: 'within ${window.$1.name} tier pool',
        left: _resolvePool(tier: window.$1),
        right: _resolvePool(tier: window.$1),
        distinctWithinRun: false,
      );
    }
    final scheduledTiers = <ChunkPatternTier>[
      ...windows.map((window) => window.$1),
      ChunkPatternTier.hard,
    ];
    for (var index = 0; index < scheduledTiers.length - 1; index += 1) {
      final leftTier = scheduledTiers[index];
      final rightTier = scheduledTiers[index + 1];
      _addPoolPairs(
        transitions,
        transitionId: 'tier=${leftTier.name}>${rightTier.name}:boundary',
        description: 'tier boundary ${leftTier.name} -> ${rightTier.name}',
        left: _resolvePool(tier: leftTier),
        right: _resolvePool(tier: rightTier),
        distinctWithinRun: false,
      );
    }
    _addPoolPairs(
      transitions,
      transitionId: 'steady-hard:tier=hard>hard',
      description: 'steady hard tier pool',
      left: _resolvePool(tier: ChunkPatternTier.hard),
      right: _resolvePool(tier: ChunkPatternTier.hard),
      distinctWithinRun: false,
    );
    return _deduplicateTransitions(transitions);
  }

  List<ChunkV2ReachableTransition> _enumerateAssembly(
    LevelAssemblyDef assembly,
  ) {
    final transitions = <ChunkV2ReachableTransition>[];
    final hardStart = _hardStart(level);
    if (hardStart > _maxAssemblyFiniteWindowChunks) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_v2_scheduler_analysis_capacity_exceeded',
          message:
              'Level ${level.levelId} has a $hardStart-chunk finite tier '
              'window with assembly enabled; exact seam analysis supports at '
              'most $_maxAssemblyFiniteWindowChunks before the hard tail.',
        ),
      );
    } else {
      var states = <_AssemblyState>{
        for (final length in _boundedLengths(
          assembly.segments.first,
          remainingFiniteIndexes: hardStart + 1,
        ))
          _AssemblyState(segmentIndex: 0, offset: 0, runLength: length),
      };

      for (var index = 0; index < hardStart; index += 1) {
        final leftTier = _tierForIndex(level, index);
        final rightTier = _tierForIndex(level, index + 1);
        final nextStates = <_AssemblyState>{};
        final orderedStates = states.toList()..sort();
        for (final state in orderedStates) {
          final segment = assembly.segments[state.segmentIndex];
          if (state.offset + 1 < state.runLength) {
            final next = state.nextOffset();
            nextStates.add(next);
            _validateDistinctCapacity(segment, leftTier);
            _validateDistinctCapacity(segment, rightTier);
            _addPoolPairs(
              transitions,
              transitionId:
                  'tier=${leftTier.name}>${rightTier.name}:'
                  'segment=${segment.segmentId}:within-run',
              description:
                  'within ${segment.segmentId} (${segment.groupId}) run',
              left: _resolvePool(tier: leftTier, groupId: segment.groupId),
              right: _resolvePool(tier: rightTier, groupId: segment.groupId),
              distinctWithinRun: segment.requireDistinctChunks,
            );
            continue;
          }

          final nextSegmentIndex = _nextSegmentIndex(
            assembly,
            state.segmentIndex,
          );
          final nextSegment = assembly.segments[nextSegmentIndex];
          _validateDistinctCapacity(segment, leftTier);
          _validateDistinctCapacity(nextSegment, rightTier);
          for (final length in _boundedLengths(
            nextSegment,
            remainingFiniteIndexes: hardStart - index,
          )) {
            nextStates.add(
              _AssemblyState(
                segmentIndex: nextSegmentIndex,
                offset: 0,
                runLength: length,
              ),
            );
          }
          _addPoolPairs(
            transitions,
            transitionId:
                'tier=${leftTier.name}>${rightTier.name}:'
                'segment=${segment.segmentId}>${nextSegment.segmentId}:'
                'between-runs',
            description:
                'between ${segment.segmentId} (${segment.groupId}) and '
                '${nextSegment.segmentId} (${nextSegment.groupId}) runs',
            left: _resolvePool(tier: leftTier, groupId: segment.groupId),
            right: _resolvePool(tier: rightTier, groupId: nextSegment.groupId),
            distinctWithinRun: false,
          );
        }
        states = nextStates;
      }
    }

    for (
      var segmentIndex = 0;
      segmentIndex < assembly.segments.length;
      segmentIndex += 1
    ) {
      final segment = assembly.segments[segmentIndex];
      _validateDistinctCapacity(segment, ChunkPatternTier.hard);
      if (segment.maxChunkCount >= 2) {
        _addPoolPairs(
          transitions,
          transitionId: 'steady-hard:segment=${segment.segmentId}:within-run',
          description:
              'within ${segment.segmentId} (${segment.groupId}) hard run',
          left: _resolvePool(
            tier: ChunkPatternTier.hard,
            groupId: segment.groupId,
          ),
          right: _resolvePool(
            tier: ChunkPatternTier.hard,
            groupId: segment.groupId,
          ),
          distinctWithinRun: segment.requireDistinctChunks,
        );
      }
      final nextIndex = _nextSegmentIndex(assembly, segmentIndex);
      final nextSegment = assembly.segments[nextIndex];
      _addPoolPairs(
        transitions,
        transitionId:
            'steady-hard:segment=${segment.segmentId}>'
            '${nextSegment.segmentId}:between-runs',
        description:
            'between ${segment.segmentId} (${segment.groupId}) and '
            '${nextSegment.segmentId} (${nextSegment.groupId}) hard runs',
        left: _resolvePool(
          tier: ChunkPatternTier.hard,
          groupId: segment.groupId,
        ),
        right: _resolvePool(
          tier: ChunkPatternTier.hard,
          groupId: nextSegment.groupId,
        ),
        distinctWithinRun: false,
      );
    }
    return _deduplicateTransitions(transitions);
  }

  void _validateDistinctCapacity(
    LevelAssemblySegmentDef segment,
    ChunkPatternTier tier,
  ) {
    if (!segment.requireDistinctChunks) return;
    final pool = _resolvePool(tier: tier, groupId: segment.groupId);
    if (pool == null || pool.chunks.length >= segment.maxChunkCount) return;
    final key = '${level.levelId}|${segment.segmentId}|${tier.name}';
    if (!issueKeys.add('distinct|$key')) return;
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'chunk_v2_scheduler_distinct_pool_too_small',
        message:
            'Level ${level.levelId} segment ${segment.segmentId} may request '
            '${segment.maxChunkCount} distinct ${tier.name} chunks from '
            'resolved ${pool.resolvedTier.name}/${segment.groupId}, but only '
            '${pool.chunks.length} active chunk(s) are eligible.',
      ),
    );
  }

  _ResolvedPool? _resolvePool({
    required ChunkPatternTier tier,
    String? groupId,
  }) {
    for (final candidateTier in fallbackOrderForTier(tier)) {
      final eligible =
          chunks
              .where((chunk) {
                return _tierFromDifficulty(chunk.difficulty) == candidateTier &&
                    (groupId == null || chunk.assemblyGroupId == groupId);
              })
              .toList(growable: false)
            ..sort(_compareChunks);
      if (eligible.isNotEmpty) {
        return _ResolvedPool(
          resolvedTier: candidateTier,
          groupId: groupId,
          chunks: eligible,
        );
      }
    }
    final key = '${level.levelId}|${tier.name}|${groupId ?? '*'}';
    if (issueKeys.add('empty|$key')) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_v2_scheduler_pool_empty',
          message:
              'Level ${level.levelId} has no active chunk in any fallback '
              'tier for requested ${tier.name}'
              '${groupId == null ? '' : ' and assembly group $groupId'}.',
        ),
      );
    }
    return null;
  }

  void _addPoolPairs(
    List<ChunkV2ReachableTransition> target, {
    required String transitionId,
    required String description,
    required _ResolvedPool? left,
    required _ResolvedPool? right,
    required bool distinctWithinRun,
  }) {
    if (left == null || right == null) return;
    final sameResolvedPool =
        left.resolvedTier == right.resolvedTier &&
        left.groupId == right.groupId;
    for (final leftChunk in left.chunks) {
      for (final rightChunk in right.chunks) {
        if (distinctWithinRun &&
            sameResolvedPool &&
            leftChunk.chunkKey == rightChunk.chunkKey) {
          continue;
        }
        target.add(
          ChunkV2ReachableTransition(
            levelId: level.levelId,
            transitionId: transitionId,
            description:
                '$description; resolved ${left.resolvedTier.name}'
                '${left.groupId == null ? '' : '/${left.groupId}'} -> '
                '${right.resolvedTier.name}'
                '${right.groupId == null ? '' : '/${right.groupId}'}',
            leftChunkKey: leftChunk.chunkKey,
            rightChunkKey: rightChunk.chunkKey,
          ),
        );
      }
    }
  }
}

@immutable
final class _ResolvedPool {
  const _ResolvedPool({
    required this.resolvedTier,
    required this.groupId,
    required this.chunks,
  });

  final ChunkPatternTier resolvedTier;
  final String? groupId;
  final List<ChunkV2FileData> chunks;
}

@immutable
final class _AssemblyState implements Comparable<_AssemblyState> {
  const _AssemblyState({
    required this.segmentIndex,
    required this.offset,
    required this.runLength,
  });

  final int segmentIndex;
  final int offset;
  final int runLength;

  _AssemblyState nextOffset() => _AssemblyState(
    segmentIndex: segmentIndex,
    offset: offset + 1,
    runLength: runLength,
  );

  @override
  int compareTo(_AssemblyState other) {
    var order = segmentIndex.compareTo(other.segmentIndex);
    if (order != 0) return order;
    order = offset.compareTo(other.offset);
    return order != 0 ? order : runLength.compareTo(other.runLength);
  }

  @override
  bool operator ==(Object other) =>
      other is _AssemblyState &&
      segmentIndex == other.segmentIndex &&
      offset == other.offset &&
      runLength == other.runLength;

  @override
  int get hashCode => Object.hash(segmentIndex, offset, runLength);
}

List<int> _boundedLengths(
  LevelAssemblySegmentDef segment, {
  required int remainingFiniteIndexes,
}) {
  final values = <int>[];
  final exactMaximum = segment.maxChunkCount < remainingFiniteIndexes + 1
      ? segment.maxChunkCount
      : remainingFiniteIndexes + 1;
  for (var value = segment.minChunkCount; value <= exactMaximum; value += 1) {
    values.add(value);
  }
  if (values.isEmpty) {
    values.add(segment.minChunkCount);
  }
  return values;
}

int _nextSegmentIndex(LevelAssemblyDef assembly, int currentIndex) {
  final lastIndex = assembly.segments.length - 1;
  if (currentIndex < lastIndex) return currentIndex + 1;
  return assembly.loopSegments ? 0 : lastIndex;
}

ChunkPatternTier _tierForIndex(LevelDef level, int index) {
  if (index < level.earlyPatternChunks) return ChunkPatternTier.early;
  final normalStart = level.earlyPatternChunks + level.easyPatternChunks;
  if (index < normalStart) return ChunkPatternTier.easy;
  final hardStart = normalStart + level.normalPatternChunks;
  return index < hardStart ? ChunkPatternTier.normal : ChunkPatternTier.hard;
}

int _hardStart(LevelDef level) =>
    level.earlyPatternChunks +
    level.easyPatternChunks +
    level.normalPatternChunks;

ChunkPatternTier? _tierFromDifficulty(String difficulty) =>
    switch (difficulty) {
      chunkDifficultyEarly => ChunkPatternTier.early,
      chunkDifficultyEasy => ChunkPatternTier.easy,
      chunkDifficultyNormal => ChunkPatternTier.normal,
      chunkDifficultyHard => ChunkPatternTier.hard,
      _ => null,
    };

List<ChunkV2BoundaryInterval> _mergeBoundaryIntervals(
  Iterable<ChunkV2BoundaryInterval> source,
) {
  final ordered = List<ChunkV2BoundaryInterval>.of(source)..sort();
  final merged = <ChunkV2BoundaryInterval>[];
  for (final interval in ordered) {
    if (merged.isEmpty) {
      merged.add(interval);
      continue;
    }
    final previous = merged.last;
    if (previous.collisionMode == interval.collisionMode &&
        interval.minYTicks <= previous.maxYTicks) {
      merged[merged.length - 1] = ChunkV2BoundaryInterval(
        collisionMode: previous.collisionMode,
        minYTicks: previous.minYTicks,
        maxYTicks: interval.maxYTicks > previous.maxYTicks
            ? interval.maxYTicks
            : previous.maxYTicks,
      );
    } else {
      merged.add(interval);
    }
  }
  return merged;
}

String _boundaryEdgeRecord(TerrainEdge edge) => <String>[
  edge.id.canonicalKey,
  '${edge.start.xTicks},${edge.start.yTicks}',
  '${edge.end.xTicks},${edge.end.yTicks}',
  '${edge.tangent.xTicks},${edge.tangent.yTicks}',
  '${edge.outwardNormal.xTicks},${edge.outwardNormal.yTicks}',
  edge.collisionMode.name,
  edge.surfaceKind ?? '',
  edge.materialKey ?? '',
].join('|');

bool _nullableStringListsEqual(List<String?> left, List<String?> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

List<ChunkV2ReachableTransition> _deduplicateTransitions(
  Iterable<ChunkV2ReachableTransition> source,
) {
  final byRecord = <String, ChunkV2ReachableTransition>{};
  for (final transition in source) {
    byRecord[transition.canonicalRecord] = transition;
  }
  final result = byRecord.values.toList()..sort(_compareTransitions);
  return result;
}

int _compareChunks(ChunkV2FileData left, ChunkV2FileData right) {
  var order = left.levelId.compareTo(right.levelId);
  if (order != 0) return order;
  order = left.difficulty.compareTo(right.difficulty);
  if (order != 0) return order;
  order = left.assemblyGroupId.compareTo(right.assemblyGroupId);
  return order != 0 ? order : left.chunkKey.compareTo(right.chunkKey);
}

int _compareTransitions(
  ChunkV2ReachableTransition left,
  ChunkV2ReachableTransition right,
) {
  var order = left.levelId.compareTo(right.levelId);
  if (order != 0) return order;
  order = left.transitionId.compareTo(right.transitionId);
  if (order != 0) return order;
  order = left.leftChunkKey.compareTo(right.leftChunkKey);
  return order != 0 ? order : left.rightChunkKey.compareTo(right.rightChunkKey);
}

int _compareValidationIssues(ValidationIssue left, ValidationIssue right) {
  var order = (left.sourcePath ?? '').compareTo(right.sourcePath ?? '');
  if (order != 0) return order;
  order = left.code.compareTo(right.code);
  return order != 0 ? order : left.message.compareTo(right.message);
}
