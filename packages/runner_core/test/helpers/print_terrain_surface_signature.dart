import 'dart:convert';
import 'dart:io';

import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/navigation/terrain_surface_extractor.dart';

import '../fixtures/slopes_golden_fixture.dart';

void main() {
  final set = const TerrainSurfaceExtractor().extract(
    const TerrainCompiler().compile(
      buildSlopesGoldenInputs(),
      geometryVersion: slopesGoldenGeometryVersion,
    ),
  );
  stdout.writeln(
    jsonEncode(<String, Object>{
      'signature': set.signature(),
      'ids': <String>[
        for (final surface in set.surfaces) surface.id.canonicalKey,
      ],
    }),
  );
}
