import 'dart:io';

import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:test/test.dart';

import '../../fixtures/slopes_golden_fixture.dart';

void main() {
  const compiler = TerrainCompiler();

  test('slopes_golden_v1 compiles with deterministic seams and features', () {
    final geometry = compiler.compile(
      buildSlopesGoldenInputs(),
      geometryVersion: slopesGoldenGeometryVersion,
    );
    final index = TerrainEdgeIndex(edges: geometry.edges);

    expect(geometry.polygons, hasLength(13));
    expect(geometry.edges, isNotEmpty);
    expect(
      geometry.edges.map((edge) => edge.id).toList(),
      orderedEquals(
        (geometry.edges.toList()
              ..sort((left, right) => left.id.compareTo(right.id)))
            .map((edge) => edge.id),
      ),
    );

    final inclusive = geometry.edges.singleWhere(
      (edge) =>
          edge.dxTicks.abs() == 56 * terrainPhysicsTicksPerWorldUnit &&
          edge.dyTicks.abs() == 97 * terrainPhysicsTicksPerWorldUnit,
    );
    final overLimit = geometry.edges.singleWhere(
      (edge) =>
          edge.dxTicks.abs() == 55 * terrainPhysicsTicksPerWorldUnit &&
          edge.dyTicks.abs() == 97 * terrainPhysicsTicksPerWorldUnit,
    );
    expect(-inclusive.outwardNormal.yTicks, terrainDirectionScale ~/ 2);
    expect(
      -overLimit.outwardNormal.yTicks,
      lessThan(terrainDirectionScale ~/ 2),
    );

    _expectContinuousTopSeam(geometry.edges, 512, 320);
    _expectContinuousTopSeam(geometry.edges, 1536, 288);
    _expectPitLedge(geometry.edges, 768);
    _expectPitLedge(geometry.edges, 800);

    final oneWayEdges = geometry.edges
        .where((edge) => edge.collisionMode.name == 'oneWay')
        .toList();
    expect(oneWayEdges, hasLength(2));
    expect(oneWayEdges.every((edge) => edge.outwardNormal.yTicks < 0), isTrue);
    expect(
      geometry.edges
          .where((edge) => edge.id.shapeId == 'ceiling_solid')
          .any((edge) => edge.outwardNormal.yTicks > 0),
      isTrue,
    );
    expect(
      geometry.edges
          .where((edge) => edge.id.shapeId == 'narrow_peak')
          .every(
            (edge) =>
                edge.startJoin != TerrainVertexJoin.exposed &&
                edge.endJoin != TerrainVertexJoin.exposed,
          ),
      isTrue,
    );

    expect(geometry.sourceSignature(), matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(
      geometry.sourceSignature(),
      _golden('slopes_golden_source_v1.sha256'),
    );
    expect(
      geometry.edgeSignature(
        indexMembershipRecords: index.canonicalMembershipRecords(),
      ),
      _golden('slopes_golden_edges_v1.sha256'),
    );
  });

  test('input allocation/order cannot affect source or edge signatures', () {
    final forward = compiler.compile(
      buildSlopesGoldenInputs(),
      geometryVersion: slopesGoldenGeometryVersion,
    );
    final reverse = compiler.compile(
      buildSlopesGoldenInputs().reversed,
      geometryVersion: slopesGoldenGeometryVersion,
    );
    final forwardIndex = TerrainEdgeIndex(edges: forward.edges);
    final reverseIndex = TerrainEdgeIndex(edges: reverse.edges.reversed);

    expect(reverse.sourceSignature(), forward.sourceSignature());
    expect(
      reverse.edgeSignature(
        indexMembershipRecords: reverseIndex.canonicalMembershipRecords(),
      ),
      forward.edgeSignature(
        indexMembershipRecords: forwardIndex.canonicalMembershipRecords(),
      ),
    );
  });
}

String _golden(String name) =>
    File('test/fixtures/goldens/$name').readAsStringSync().trim();

void _expectContinuousTopSeam(
  List<TerrainEdge> edges,
  double worldX,
  double worldY,
) {
  final point = TerrainPoint.fromWorld(worldX, worldY);
  final incoming = edges.where((edge) => edge.end == point).toList();
  final outgoing = edges.where((edge) => edge.start == point).toList();
  expect(
    incoming.any(
      (edge) =>
          edge.nextId != null &&
          outgoing.any((candidate) => candidate.id == edge.nextId),
    ),
    isTrue,
    reason: 'incoming seam at $worldX,$worldY',
  );
  expect(
    outgoing.any(
      (edge) =>
          edge.previousId != null &&
          incoming.any((candidate) => candidate.id == edge.previousId),
    ),
    isTrue,
    reason: 'outgoing seam at $worldX,$worldY',
  );
}

void _expectPitLedge(List<TerrainEdge> edges, double worldX) {
  final xTicks = physicsCoordinateToTicks(worldX);
  expect(
    edges.any(
      (edge) =>
          edge.start.xTicks == xTicks &&
          edge.end.xTicks == xTicks &&
          edge.start.yTicks != edge.end.yTicks,
    ),
    isTrue,
    reason: 'pit ledge at x=$worldX',
  );
}
