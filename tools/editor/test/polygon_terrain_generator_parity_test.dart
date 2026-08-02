import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_expansion.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';

const String _fixtureDirectory = 'test/fixtures/polygon_terrain_generator';
const String _chunkSourcePath = 'chunks/forest/fixture_chunk.json';

void main() {
  test('editor compile matches staged generator fixture signatures', () {
    final prefabs = PrefabV3FileCodec.decode(
      _fixture('prefab_defs.json'),
      sourcePath: 'prefab_defs.json',
    );
    final chunk = ChunkV2FileCodec.decode(
      _fixture('chunk.json'),
      sourcePath: _chunkSourcePath,
    );
    final golden = jsonDecode(_fixture('golden.json')) as Map<String, Object?>;

    final result = expandChunkV2Collision(
      chunk: chunk,
      prefabs: prefabs.prefabs,
      sourcePath: _chunkSourcePath,
    );

    expect(result.issues, isEmpty);
    final expansion = result.expansion!;
    expect(
      expansion.geometry.polygons,
      hasLength(golden['polygonCount']! as int),
    );
    expect(expansion.geometry.edges, hasLength(golden['edgeCount']! as int));
    expect(expansion.geometry.sourceSignature(), golden['sourceSignature']);
    expect(expansion.geometry.edgeSignature(), golden['edgeSignature']);
    expect(_placementSignature(expansion), golden['placementSignature']);
  });
}

String _placementSignature(ChunkV2CollisionExpansion expansion) {
  final shapes =
      List<ChunkV2ExpandedPrefabShape>.of(expansion.expandedPrefabShapes)
        ..sort((left, right) {
          final placement = left.placementKey.compareTo(right.placementKey);
          return placement != 0
              ? placement
              : left.shapeId.compareTo(right.shapeId);
        });
  final records = <String>[
    for (final shape in shapes)
      _canonicalRecord(<String>[
        'authoring-placement-v1',
        shape.chunkKey,
        shape.placementKey,
        shape.prefabKey,
        shape.prefabId,
        shape.prefabRevision.toString(),
        shape.shapeId,
        shape.placementX.toString(),
        shape.placementY.toString(),
        shape.scaleTenths.toString(),
        shape.flipX ? '1' : '0',
        shape.flipY ? '1' : '0',
      ]),
  ];
  return sha256.convert(utf8.encode(records.join('\n'))).toString();
}

String _canonicalRecord(List<String> fields) =>
    fields.map((field) => '${utf8.encode(field).length}:$field').join('|');

String _fixture(String name) {
  final rootRelative = File('$_fixtureDirectory/$name');
  if (rootRelative.existsSync()) return rootRelative.readAsStringSync();
  final editorRelative = File('../../$_fixtureDirectory/$name');
  if (editorRelative.existsSync()) return editorRelative.readAsStringSync();
  throw StateError('Missing polygon generator fixture $name.');
}
