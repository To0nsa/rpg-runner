import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';

import '../integration_test/support/polygon_interaction_benchmark_fixture.dart';

void main() {
  test('profile fixture freezes representative geometry and signatures', () {
    final fixture = PolygonInteractionBenchmarkFixture.build();
    final validationIssues = ChunkDomainPlugin().validate(fixture.document);

    expect(
      fixture.mainChunk.collisionShapes,
      hasLength(PolygonInteractionBenchmarkFixture.directShapeCount),
    );
    expect(
      fixture.mainChunk.collisionShapes.first.vertices,
      hasLength(PolygonInteractionBenchmarkFixture.selectedShapeVertexCount),
    );
    expect(
      fixture.mainChunk.prefabs,
      hasLength(PolygonInteractionBenchmarkFixture.placedPrefabCount),
    );
    expect(fixture.mainExpansion.expandedPrefabShapes, hasLength(43));
    expect(
      fixture.mainExpansion.geometry.edges,
      hasLength(PolygonInteractionBenchmarkFixture.compiledEdgeCount),
    );
    expect(fixture.mainExpansion.geometry.diagnostics, isEmpty);
    expect(
      validationIssues,
      isEmpty,
      reason: validationIssues
          .map((issue) => '${issue.code}: ${issue.message}')
          .join('\n'),
    );
    expect(fixture.seamAnalysis.transitions, isNotEmpty);
    expect(
      fixture.seamAnalysis.issues,
      isEmpty,
      reason: fixture.seamAnalysis.issues
          .map((issue) => '${issue.code}: ${issue.message}')
          .join('\n'),
    );
    expect(
      <String, String>{
        'authoring': fixture.authoringPolygonSignature,
        'source': fixture.sourceSignature,
        'edges': fixture.edgeSignature,
        'seams': fixture.seamSignature,
      },
      <String, String>{
        'authoring':
            '11957741e47d33abb3e6680699b51c5f95c8584ffd7994dc2d176828371a2ae0',
        'source':
            '9c7a7088e5e26a0dee3a3e71484ab92d0ca0f0ea2a25380f407c5e5da6155725',
        'edges':
            'dfcdc19342298c0d465fdee9a030e9a7f22894224278d460a4b9fc7e64427271',
        'seams':
            'fa7a0aa0c31a1678a4d82afb5f88957f7b8e520c608d4ceffbdd514dc3c16355',
      },
    );
  });
}
