import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_polygon_signature.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_seam_signature.dart';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:test/test.dart';

void main() {
  test(
    'accepts every compatible directed seam and canonicalizes chunk order',
    () {
      final a = _compiled('a', topY: 40);
      final b = _compiled('b', topY: 40);
      final manifest = _manifest(<TerrainAuthoringSeamTransition>[
        _transition(left: 'b', right: 'a'),
        _transition(left: 'a', right: 'b'),
      ]);

      final result = validatePolygonTerrainSeams(
        chunks: <PolygonTerrainCompiledChunk>[b, a],
        manifest: manifest,
      );

      expect(result.issues, isEmpty);
      expect(result.batch!.chunks.map((item) => item.chunk.chunkKey), <String>[
        'a',
        'b',
      ]);
      expect(result.batch!.seams, hasLength(2));
      expect(
        result.batch!.seams.every((seam) => seam.comparison.isCompatible),
        isTrue,
      );
      expect(result.batch!.seamSignature.digest, manifest.signature.digest);
    },
  );

  test('blocks exact physical seam mismatch with stable evidence', () {
    final result = validatePolygonTerrainSeams(
      chunks: <PolygonTerrainCompiledChunk>[
        _compiled('low', topY: 40),
        _compiled('high', topY: 48),
      ],
      manifest: _manifest(<TerrainAuthoringSeamTransition>[
        _transition(left: 'low', right: 'high'),
      ]),
    );

    expect(result.batch, isNull);
    expect(result.issues, hasLength(1));
    expect(result.issues.single.code, 'staged_reachable_seam_mismatch');
    expect(result.issues.single.message, contains('low>high'));
    expect(result.issues.single.message, contains('40960, 49152, 102400'));
    expect(result.issues.single.message, contains('right'));
    expect(result.issues.single.message, contains('left'));
    _expectIssueEnvelope(result.issues.single, ownerKey: 'high');
  });

  test('blocks missing chunks and wrong level ownership before comparison', () {
    final missing = validatePolygonTerrainSeams(
      chunks: <PolygonTerrainCompiledChunk>[_compiled('a', topY: 40)],
      manifest: _manifest(<TerrainAuthoringSeamTransition>[
        _transition(left: 'a', right: 'missing'),
      ]),
    );
    expect(missing.batch, isNull);
    expect(missing.issues.single.code, 'staged_seam_chunk_missing');
    expect(missing.issues.single.message, contains('missing'));
    _expectIssueEnvelope(missing.issues.single, ownerKey: 'missing');

    final wrongLevel = validatePolygonTerrainSeams(
      chunks: <PolygonTerrainCompiledChunk>[
        _compiled('a', topY: 40),
        _compiled('b', topY: 40, levelId: 'cave'),
      ],
      manifest: _manifest(<TerrainAuthoringSeamTransition>[
        _transition(left: 'a', right: 'b'),
      ]),
    );
    expect(wrongLevel.batch, isNull);
    expect(wrongLevel.issues.single.code, 'staged_seam_level_mismatch');
    expect(wrongLevel.issues.single.message, contains('belongs to cave'));
    _expectIssueEnvelope(wrongLevel.issues.single, ownerKey: 'b');
  });

  test('reports each missing seam owner in canonical owner order', () {
    final result = validatePolygonTerrainSeams(
      chunks: const <PolygonTerrainCompiledChunk>[],
      manifest: _manifest(<TerrainAuthoringSeamTransition>[
        _transition(left: 'z_missing', right: 'a_missing'),
      ]),
    );

    expect(result.batch, isNull);
    expect(
      result.issues.map((issue) => (issue.code, issue.ownerKey)),
      <(String, String)>[
        ('staged_seam_chunk_missing', 'a_missing'),
        ('staged_seam_chunk_missing', 'z_missing'),
      ],
    );
  });

  test('blocks duplicate and case-colliding compiled chunk identities', () {
    final a = _compiled('a', topY: 40);
    final duplicate = validatePolygonTerrainSeams(
      chunks: <PolygonTerrainCompiledChunk>[a, a],
      manifest: _manifest(const []),
    );
    expect(duplicate.batch, isNull);
    expect(duplicate.issues.single.code, 'staged_seam_chunk_duplicate');
    _expectIssueEnvelope(duplicate.issues.single, ownerKey: 'a');

    final collision = validatePolygonTerrainSeams(
      chunks: <PolygonTerrainCompiledChunk>[a, _compiled('A', topY: 40)],
      manifest: _manifest(const []),
    );
    expect(collision.batch, isNull);
    expect(collision.issues.single.code, 'staged_seam_chunk_case_collision');
    _expectIssueEnvelope(collision.issues.single, ownerKey: 'a');
  });
}

void _expectIssueEnvelope(
  PolygonTerrainSeamValidationIssue issue, {
  required String ownerKey,
}) {
  expect(issue.severity, TerrainAuthoringIssueSeverity.error);
  expect(issue.sourcePath, 'fixtures/reachable_seams.json');
  expect(issue.ownerKey, ownerKey);
  expect(issue.placementKey, isNull);
  expect(issue.shapeId, isNull);
  expect(issue.elementIndex, isNull);
}

PolygonTerrainSeamManifest _manifest(
  Iterable<TerrainAuthoringSeamTransition> transitions,
) => PolygonTerrainSeamManifest(
  signature: TerrainAuthoringSeamSignature(transitions),
  sourcePath: 'fixtures/reachable_seams.json',
);

TerrainAuthoringSeamTransition _transition({
  required String left,
  required String right,
}) => TerrainAuthoringSeamTransition(
  levelId: 'forest',
  transitionId: 'fixture:hard>hard',
  leftChunkKey: left,
  rightChunkKey: right,
);

PolygonTerrainCompiledChunk _compiled(
  String chunkKey, {
  required int topY,
  String levelId = 'forest',
}) {
  final chunk = PolygonTerrainChunkSource(
    chunkKey: chunkKey,
    id: chunkKey,
    revision: 1,
    status: 'active',
    levelId: levelId,
    tileSize: 16,
    width: 100,
    height: 100,
    difficulty: 'normal',
    assemblyGroupId: 'default',
    placements: const <PolygonTerrainPlacementSource>[],
    collisionShapes: <PolygonTerrainShapeSource>[
      PolygonTerrainShapeSource(
        shapeId: 'ground',
        vertices: <PolygonTerrainSourcePoint>[
          PolygonTerrainSourcePoint(xHalfPixels: 0, yHalfPixels: topY * 2),
          PolygonTerrainSourcePoint(xHalfPixels: 200, yHalfPixels: topY * 2),
          const PolygonTerrainSourcePoint(xHalfPixels: 200, yHalfPixels: 200),
          const PolygonTerrainSourcePoint(xHalfPixels: 0, yHalfPixels: 200),
        ],
        collisionMode: TerrainAuthoringPolygonMode.solid,
        surfaceKind: 'ground',
        materialKey: 'earth',
      ),
    ],
  );
  final result = compilePolygonTerrainChunk(
    chunk: chunk,
    prefabSources: PolygonTerrainPrefabSourceSet(
      const <PolygonTerrainPrefabSource>[],
    ),
    sourcePath: 'chunks/$levelId/$chunkKey.json',
  );
  expect(result.issues, isEmpty);
  return result.compiled!;
}
