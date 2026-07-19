import 'dart:io';

import 'package:runner_core/collision/terrain/capsule_segment_kernel.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:test/test.dart';

import '../../fixtures/slopes_golden_fixture.dart';

void main() {
  test('capsule contact-order signature matches reviewed golden', () {
    const compiler = TerrainCompiler();
    final geometry = compiler.compile(
      buildSlopesGoldenInputs(),
      geometryVersion: slopesGoldenGeometryVersion,
    );
    final kernel = CapsuleSegmentKernel();
    final signature = kernel.contactOrderSignature(
      buildSlopesGoldenContactHits(geometry),
    );

    expect(
      signature,
      File(
        'test/fixtures/goldens/slopes_golden_contacts_v1.sha256',
      ).readAsStringSync().trim(),
    );
  });

  test('contact-order signature is independent of input hit order', () {
    const compiler = TerrainCompiler();
    final geometry = compiler.compile(
      buildSlopesGoldenInputs().reversed,
      geometryVersion: slopesGoldenGeometryVersion,
    );
    final hits = buildSlopesGoldenContactHits(geometry);
    final kernel = CapsuleSegmentKernel();

    expect(
      kernel.contactOrderSignature(hits.reversed),
      kernel.contactOrderSignature(hits),
    );
  });
}
