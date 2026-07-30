import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test(
    'file data snapshots collections and canonical encode copies source',
    () {
      final slices = <AtlasSliceDef>[
        const AtlasSliceDef(
          id: 'slice_b',
          sourceImagePath: 'assets/images/b.png',
          x: 16,
          y: 0,
          width: 16,
          height: 16,
          tags: <String>['z', 'a', 'z'],
        ),
        const AtlasSliceDef(
          id: 'slice_a',
          sourceImagePath: 'assets/images/a.png',
          x: 0,
          y: 0,
          width: 16,
          height: 16,
        ),
      ];
      final prefabs = <PrefabV3Def>[
        _prefab(
          prefabKey: 'prefab_b',
          collisionShapes: <TerrainSourceShapeDef>[
            _shape('collision_002', xOffset: 20),
            _shape('collision_001'),
          ],
          tags: const <String>['rock', 'obstacle', 'rock'],
        ),
        _prefab(prefabKey: 'prefab_a'),
      ];
      final data = PrefabV3FileData(slices: slices, prefabs: prefabs);
      slices.clear();
      prefabs.clear();

      final encoded = PrefabV3FileCodec.encode(data);
      final decoded = PrefabV3FileCodec.decode(encoded);

      expect(decoded.slices.map((slice) => slice.id), <String>[
        'slice_a',
        'slice_b',
      ]);
      expect(decoded.slices.last.tags, <String>['a', 'z']);
      expect(decoded.prefabs.map((prefab) => prefab.id), <String>[
        'prefab_a',
        'prefab_b',
      ]);
      expect(
        decoded.prefabs.last.collisionShapes.map((shape) => shape.shapeId),
        <String>['collision_001', 'collision_002'],
      );
      expect(decoded.prefabs.last.tags, <String>['obstacle', 'rock']);
      expect(
        data.prefabs.first.collisionShapes.map((shape) => shape.shapeId),
        <String>['collision_002', 'collision_001'],
      );
      expect(data.prefabs.first.tags, <String>['rock', 'obstacle', 'rock']);
      expect(() => data.slices.clear(), throwsUnsupportedError);
      expect(() => data.prefabs.clear(), throwsUnsupportedError);
      expect(PrefabV3FileCodec.encode(decoded), encoded);
      expect(encoded, contains('"schemaVersion": 3'));
      expect(encoded, isNot(contains('"colliders"')));
    },
  );

  test('strict decode rejects legacy, unknown, and noncanonical source', () {
    final canonical =
        jsonDecode(
              PrefabV3FileCodec.encode(
                PrefabV3FileData(
                  slices: const <AtlasSliceDef>[],
                  prefabs: <PrefabV3Def>[_prefab(prefabKey: 'prefab_a')],
                ),
              ),
            )
            as Map<String, Object?>;

    expect(
      () => PrefabV3FileCodec.decode(
        _mutated(canonical, (root) => root['schemaVersion'] = 2),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => PrefabV3FileCodec.decode(
        _mutated(canonical, (root) {
          final prefab = _firstPrefab(root);
          prefab['colliders'] = <Object?>[];
        }),
      ),
      throwsA(_formatMessage(contains('unknown field colliders'))),
    );
    expect(
      () => PrefabV3FileCodec.decode(
        _mutated(canonical, (root) {
          final prefab = _firstPrefab(root);
          prefab['tags'] = <Object?>['z', 'a'];
        }),
      ),
      throwsA(_formatMessage(contains('strictly ordered'))),
    );
  });

  test('encode rejects duplicate stable identities deterministically', () {
    final data = PrefabV3FileData(
      slices: const <AtlasSliceDef>[],
      prefabs: <PrefabV3Def>[
        _prefab(prefabKey: 'same_key', id: 'a'),
        _prefab(prefabKey: 'SAME_KEY', id: 'b'),
      ],
    );

    expect(
      () => PrefabV3FileCodec.encode(data),
      throwsA(_formatMessage(contains('unique values'))),
    );
  });

  test('encode refuses models that cannot satisfy the strict v3 schema', () {
    final data = PrefabV3FileData(
      slices: const <AtlasSliceDef>[],
      prefabs: <PrefabV3Def>[
        _prefab(prefabKey: 'prefab_a').copyWith(status: PrefabStatus.unknown),
      ],
    );

    expect(
      () => PrefabV3FileCodec.encode(data),
      throwsA(_formatMessage(contains('must be one of'))),
    );
  });
}

PrefabV3Def _prefab({
  required String prefabKey,
  String? id,
  Iterable<TerrainSourceShapeDef>? collisionShapes,
  Iterable<String> tags = const <String>['obstacle'],
}) => PrefabV3Def(
  prefabKey: prefabKey,
  id: id ?? prefabKey,
  revision: 1,
  status: PrefabStatus.active,
  kind: PrefabKind.obstacle,
  visualSource: const PrefabVisualSource.atlasSlice('slice_a'),
  anchorXPx: 0,
  anchorYPx: 0,
  collisionShapes:
      collisionShapes ?? <TerrainSourceShapeDef>[_shape('collision_001')],
  tags: tags,
);

TerrainSourceShapeDef _shape(String shapeId, {int xOffset = 0}) =>
    TerrainSourceShapeDef(
      shapeId: shapeId,
      vertices: <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: xOffset, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: xOffset + 10, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: xOffset + 10, yHalfPixels: 10),
        TerrainSourceVertexDef(xHalfPixels: xOffset, yHalfPixels: 10),
      ],
    );

String _mutated(
  Map<String, Object?> canonical,
  void Function(Map<String, Object?> root) mutate,
) {
  final copied = jsonDecode(jsonEncode(canonical)) as Map<String, Object?>;
  mutate(copied);
  return jsonEncode(copied);
}

Map<String, Object?> _firstPrefab(Map<String, Object?> root) =>
    (root['prefabs']! as List<Object?>).first! as Map<String, Object?>;

Matcher _formatMessage(Matcher messageMatcher) => isA<FormatException>().having(
  (error) => error.message,
  'message',
  messageMatcher,
);
