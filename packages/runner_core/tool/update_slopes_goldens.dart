import 'dart:io';

import 'package:runner_core/collision/terrain/capsule_segment_kernel.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';

import '../test/fixtures/slopes_golden_fixture.dart';

void main(List<String> args) {
  if (!args.contains('--update')) {
    stderr.writeln(
      'Refusing to rewrite reviewed slopes goldens without --update.',
    );
    exitCode = 64;
    return;
  }

  const compiler = TerrainCompiler();
  final geometry = compiler.compile(
    buildSlopesGoldenInputs(),
    geometryVersion: slopesGoldenGeometryVersion,
  );
  final index = TerrainEdgeIndex(edges: geometry.edges);
  final kernel = CapsuleSegmentKernel();
  final values = <String, String>{
    'slopes_golden_source_v1.sha256': geometry.sourceSignature(),
    'slopes_golden_edges_v1.sha256': geometry.edgeSignature(
      indexMembershipRecords: index.canonicalMembershipRecords(),
    ),
    'slopes_golden_contacts_v1.sha256': kernel.contactOrderSignature(
      buildSlopesGoldenContactHits(geometry),
    ),
  };

  final directory = Directory('test/fixtures/goldens')
    ..createSync(recursive: true);
  for (final entry in values.entries) {
    final file = File('${directory.path}/${entry.key}');
    file.writeAsStringSync('${entry.value}\n');
    stdout.writeln('${entry.key}: ${entry.value}');
  }
}
