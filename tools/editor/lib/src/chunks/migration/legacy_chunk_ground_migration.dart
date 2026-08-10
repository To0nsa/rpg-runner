import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';

import '../../terrain_authoring/terrain_source_core_adapter.dart';
import '../../terrain_authoring/terrain_source_models.dart';
import 'legacy_chunk_models.dart';

/// One stable blocking finding from legacy flat-ground conversion.
final class LegacyChunkGroundMigrationIssue
    implements Comparable<LegacyChunkGroundMigrationIssue> {
  const LegacyChunkGroundMigrationIssue({
    required this.sourcePath,
    required this.code,
    required this.message,
    this.elementIndex = 0,
  });

  final String sourcePath;
  final int elementIndex;
  final String code;
  final String message;

  @override
  int compareTo(LegacyChunkGroundMigrationIssue other) {
    var order = sourcePath.compareTo(other.sourcePath);
    if (order != 0) return order;
    order = elementIndex.compareTo(other.elementIndex);
    if (order != 0) return order;
    return code.compareTo(other.code);
  }
}

/// Immutable read-only plan for one legacy chunk's ground polygons.
final class LegacyChunkGroundMigrationResult {
  LegacyChunkGroundMigrationResult({
    required Iterable<TerrainSourceShapeDef> shapes,
    required Iterable<LegacyChunkGroundMigrationIssue> issues,
    required this.occupiedAreaHalfPixelSquared,
  }) : shapes = List<TerrainSourceShapeDef>.unmodifiable(shapes),
       issues = List<LegacyChunkGroundMigrationIssue>.unmodifiable(
         List<LegacyChunkGroundMigrationIssue>.of(issues)..sort(),
       );

  final List<TerrainSourceShapeDef> shapes;
  final List<LegacyChunkGroundMigrationIssue> issues;

  /// Exact area covered by the planned ground polygons.
  final BigInt occupiedAreaHalfPixelSquared;

  bool get canMigrate => issues.isEmpty;
}

/// Converts legacy flat ground and pit gaps into finite solid polygons.
///
/// This is a pure migration primitive. A gap becomes missing solid coverage;
/// it never becomes a special polygon or runtime collider.
abstract final class LegacyChunkGroundMigration {
  static LegacyChunkGroundMigrationResult plan({
    required LevelChunkDef chunk,
    required String sourcePath,
  }) {
    final issues = <LegacyChunkGroundMigrationIssue>[];
    if (chunk.groundProfile.kind != groundProfileKindFlat) {
      issues.add(
        LegacyChunkGroundMigrationIssue(
          sourcePath: sourcePath,
          code: 'legacy_ground_profile_kind',
          message:
              'Only legacy flat ground profiles can migrate automatically.',
        ),
      );
    }
    if (chunk.width <= 0 || chunk.height <= 0) {
      issues.add(
        LegacyChunkGroundMigrationIssue(
          sourcePath: sourcePath,
          code: 'legacy_chunk_dimensions',
          message: 'Legacy chunk width and height must be positive.',
        ),
      );
    }
    final topY = chunk.groundProfile.topY;
    if (topY < 0 || topY >= chunk.height) {
      issues.add(
        LegacyChunkGroundMigrationIssue(
          sourcePath: sourcePath,
          code: 'legacy_ground_top_bounds',
          message: 'Legacy ground top must lie inside the chunk height.',
        ),
      );
    }
    if (!_coordinatesFitCore(chunk.width, chunk.height, topY)) {
      issues.add(
        LegacyChunkGroundMigrationIssue(
          sourcePath: sourcePath,
          code: 'legacy_ground_coordinate_range',
          message: 'Legacy ground exceeds Core source-coordinate limits.',
        ),
      );
    }

    final gaps = List<GroundGapDef>.of(chunk.groundGaps)..sort(_compareGaps);
    final gapIds = <String>{};
    var previousEnd = 0;
    for (var index = 0; index < gaps.length; index += 1) {
      final gap = gaps[index];
      if (gap.gapId.isEmpty || !gapIds.add(gap.gapId)) {
        issues.add(
          LegacyChunkGroundMigrationIssue(
            sourcePath: sourcePath,
            elementIndex: index,
            code: gap.gapId.isEmpty
                ? 'legacy_ground_gap_id'
                : 'legacy_ground_gap_duplicate_id',
            message: gap.gapId.isEmpty
                ? 'Legacy ground gaps require a stable non-empty ID.'
                : 'Legacy ground gap IDs must be unique.',
          ),
        );
      }
      if (gap.type != groundGapTypePit) {
        issues.add(
          LegacyChunkGroundMigrationIssue(
            sourcePath: sourcePath,
            elementIndex: index,
            code: 'legacy_ground_gap_type',
            message: 'Only legacy pit gaps can migrate automatically.',
          ),
        );
      }
      final end = BigInt.from(gap.x) + BigInt.from(gap.width);
      final isInsideChunk =
          gap.width > 0 && gap.x >= 0 && end <= BigInt.from(chunk.width);
      if (!isInsideChunk) {
        issues.add(
          LegacyChunkGroundMigrationIssue(
            sourcePath: sourcePath,
            elementIndex: index,
            code: 'legacy_ground_gap_bounds',
            message:
                'Legacy ground gaps must have positive width inside the chunk.',
          ),
        );
      } else {
        if (gap.x < previousEnd) {
          issues.add(
            LegacyChunkGroundMigrationIssue(
              sourcePath: sourcePath,
              elementIndex: index,
              code: 'legacy_ground_gap_overlap',
              message: 'Legacy ground gaps must not overlap.',
            ),
          );
        }
        if (end > BigInt.from(previousEnd)) previousEnd = end.toInt();
      }
    }
    if (issues.isNotEmpty) {
      return LegacyChunkGroundMigrationResult(
        shapes: const <TerrainSourceShapeDef>[],
        issues: issues,
        occupiedAreaHalfPixelSquared: BigInt.zero,
      );
    }

    final solidSpans = <(int, int)>[];
    var cursor = 0;
    for (final gap in gaps) {
      if (cursor < gap.x) solidSpans.add((cursor, gap.x));
      cursor = gap.x + gap.width;
    }
    if (cursor < chunk.width) solidSpans.add((cursor, chunk.width));
    if (solidSpans.length > TerrainGeometryLimits.maxShapesPerChunk) {
      return LegacyChunkGroundMigrationResult(
        shapes: const <TerrainSourceShapeDef>[],
        issues: <LegacyChunkGroundMigrationIssue>[
          LegacyChunkGroundMigrationIssue(
            sourcePath: sourcePath,
            code: 'legacy_ground_shape_limit',
            message:
                'Legacy ground produces ${solidSpans.length} shapes; the '
                'per-chunk limit is ${TerrainGeometryLimits.maxShapesPerChunk}.',
          ),
        ],
        occupiedAreaHalfPixelSquared: BigInt.zero,
      );
    }

    final shapes = <TerrainSourceShapeDef>[];
    var plannedDoubledArea = BigInt.zero;
    for (var index = 0; index < solidSpans.length; index += 1) {
      final span = solidSpans[index];
      final candidate = TerrainSourceShapeDef(
        shapeId: 'ground_${(index + 1).toString().padLeft(3, '0')}',
        vertices: <TerrainSourceVertexDef>[
          _vertex(span.$1, topY),
          _vertex(span.$2, topY),
          _vertex(span.$2, chunk.height),
          _vertex(span.$1, chunk.height),
        ],
      );
      final review = TerrainSourceCoreAdapter.review(
        shape: candidate,
        sourcePath: sourcePath,
        chunkIndex: 0,
        chunkKey: chunk.chunkKey,
        requireCanonical: false,
      );
      if (review.hasBlockingDiagnostics || review.canonicalVertices == null) {
        for (final diagnostic in review.diagnostics) {
          issues.add(
            LegacyChunkGroundMigrationIssue(
              sourcePath: sourcePath,
              elementIndex: diagnostic.elementIndex,
              code: 'legacy_core_${diagnostic.code}',
              message: diagnostic.message,
            ),
          );
        }
      } else {
        shapes.add(
          TerrainSourceCoreAdapter.applyCanonicalVertices(candidate, review),
        );
        plannedDoubledArea += review.signedDoubledArea.abs();
      }
    }

    final occupiedArea =
        BigInt.from(chunk.height - topY) *
        BigInt.from(
          solidSpans.fold<int>(0, (sum, span) => sum + span.$2 - span.$1),
        ) *
        BigInt.from(4);
    if (issues.isEmpty && plannedDoubledArea ~/ BigInt.two != occupiedArea) {
      issues.add(
        LegacyChunkGroundMigrationIssue(
          sourcePath: sourcePath,
          code: 'legacy_ground_area_mismatch',
          message: 'Ground migration did not preserve exact occupied area.',
        ),
      );
    }
    return LegacyChunkGroundMigrationResult(
      shapes: issues.isEmpty
          ? canonicalTerrainSourceShapes(shapes)
          : const <TerrainSourceShapeDef>[],
      issues: issues,
      occupiedAreaHalfPixelSquared: occupiedArea,
    );
  }
}

TerrainSourceVertexDef _vertex(int xPixels, int yPixels) =>
    TerrainSourceVertexDef(xHalfPixels: xPixels * 2, yHalfPixels: yPixels * 2);

bool _coordinatesFitCore(int width, int height, int topY) {
  final limit = BigInt.from(terrainMaxAbsSourceTicks);
  return <int>[0, width, topY, height].every(
    (coordinate) => (BigInt.from(coordinate) * BigInt.two).abs() <= limit,
  );
}

int _compareGaps(GroundGapDef left, GroundGapDef right) {
  var order = left.x.compareTo(right.x);
  if (order != 0) return order;
  order = left.width.compareTo(right.width);
  if (order != 0) return order;
  return left.gapId.compareTo(right.gapId);
}
