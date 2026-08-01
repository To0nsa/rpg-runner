import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test(
    'file data snapshots author order and copyWith preserves the source',
    () {
      final tags = <String>['zeta', 'alpha'];
      final layers = <TileLayerDef>[
        const TileLayerDef(id: 'foreground'),
        const TileLayerDef(id: 'background'),
      ];
      final shapes = <TerrainSourceShapeDef>[
        _shape('collision_002', xOffset: 40),
        _shape('collision_001'),
      ];
      final data = _data(
        tags: tags,
        tileLayers: layers,
        collisionShapes: shapes,
      );

      tags.clear();
      layers.clear();
      shapes.clear();
      final copy = data.copyWith(revision: 8);

      expect(data.tags, <String>['zeta', 'alpha']);
      expect(data.tileLayers.map((layer) => layer.id), <String>[
        'foreground',
        'background',
      ]);
      expect(data.collisionShapes.map((shape) => shape.shapeId), <String>[
        'collision_002',
        'collision_001',
      ]);
      expect(copy.revision, 8);
      expect(data.revision, 4);
      expect(() => data.tags.add('mutate'), throwsUnsupportedError);
    },
  );

  test('canonical encode copies order and strictly round-trips metadata', () {
    final data = _data(
      tags: const <String>[' forest ', 'test', 'forest'],
      tileLayers: const <TileLayerDef>[
        TileLayerDef(id: 'foreground', kind: 'visual', visible: true),
        TileLayerDef(id: 'background', kind: 'visual', visible: true),
      ],
      prefabs: const <PlacedPrefabDef>[
        PlacedPrefabDef(
          prefabId: 'rock_b',
          prefabKey: 'rock_b',
          x: 200,
          y: 224,
          zIndex: 2,
          snapToGrid: false,
        ),
        PlacedPrefabDef(
          prefabId: 'rock_a',
          prefabKey: 'rock_a',
          x: 100,
          y: 224,
          zIndex: 1,
          snapToGrid: false,
          scale: 0.8,
          flipX: true,
        ),
      ],
      markers: const <PlacedMarkerDef>[
        PlacedMarkerDef(markerId: 'second', x: 300, y: 224, salt: 7),
        PlacedMarkerDef(markerId: 'first', x: 100, y: 224, salt: 3),
      ],
      collisionShapes: <TerrainSourceShapeDef>[
        _shape('collision_002', xOffset: 40),
        _shape('collision_001'),
      ],
    );

    final source = ChunkV2FileCodec.encode(data);
    final decoded = ChunkV2FileCodec.decode(source);

    expect(ChunkV2FileCodec.encode(decoded), source);
    expect(source, contains('"schemaVersion": 2'));
    expect(source, contains('"groundBandZIndex": -2'));
    expect(source, isNot(contains('"groundProfile"')));
    expect(source, isNot(contains('"groundGaps"')));
    expect(decoded.tags, <String>['forest', 'test']);
    expect(decoded.tileLayers.map((layer) => layer.id), <String>[
      'background',
      'foreground',
    ]);
    expect(decoded.prefabs.map((prefab) => prefab.prefabKey), <String>[
      'rock_a',
      'rock_b',
    ]);
    expect(decoded.markers.map((marker) => marker.markerId), <String>[
      'first',
      'second',
    ]);
    expect(decoded.collisionShapes.map((shape) => shape.shapeId), <String>[
      'collision_001',
      'collision_002',
    ]);
    expect(decoded.prefabs.first.scale, 0.8);

    expect(data.tags, <String>[' forest ', 'test', 'forest']);
    expect(data.tileLayers.first.id, 'foreground');
    expect(data.prefabs.first.prefabKey, 'rock_b');
    expect(data.markers.first.markerId, 'second');
    expect(data.collisionShapes.first.shapeId, 'collision_002');
  });

  test('strict decode rejects legacy, malformed, and noncanonical source', () {
    final canonical =
        jsonDecode(ChunkV2FileCodec.encode(_data())) as Map<String, Object?>;

    expect(
      () => ChunkV2FileCodec.decode(
        _mutated(canonical, (root) => root['schemaVersion'] = 1),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ChunkV2FileCodec.decode(
        _mutated(canonical, (root) {
          root['groundProfile'] = <String, Object?>{
            'kind': 'flat',
            'topY': 224,
          };
        }),
      ),
      throwsA(_formatMessage(contains('unknown field groundProfile'))),
    );
    expect(
      () => ChunkV2FileCodec.decode(
        _mutated(canonical, (root) => root['width'] = 600.0),
      ),
      throwsA(_formatMessage(contains('width must be an integer'))),
    );
    expect(
      () => ChunkV2FileCodec.decode(
        _mutated(canonical, (root) {
          final placement = _firstObject(root, 'prefabs');
          placement['scale'] = 0.35;
        }),
      ),
      throwsA(_formatMessage(contains('0.3-3.0 scale in 0.1 steps'))),
    );
    expect(
      () => ChunkV2FileCodec.decode(
        _mutated(canonical, (root) {
          final shape = _firstObject(root, 'collisionShapes');
          final vertices = shape['vertices']! as List<Object?>;
          final vertex = vertices.first! as Map<String, Object?>;
          vertex['x'] = 0.25;
        }),
      ),
      throwsA(_formatMessage(contains('divisible exactly by 0.5'))),
    );
  });

  test('encode rejects invalid model values and duplicate canonical IDs', () {
    expect(
      () => ChunkV2FileCodec.encode(_data().copyWith(status: 'retired')),
      throwsA(_formatMessage(contains('status must be one of'))),
    );
    expect(
      () => ChunkV2FileCodec.encode(
        _data(
          tileLayers: const <TileLayerDef>[
            TileLayerDef(id: 'visual'),
            TileLayerDef(id: 'visual'),
          ],
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

ChunkV2FileData _data({
  Iterable<String> tags = const <String>['forest'],
  Iterable<TileLayerDef> tileLayers = const <TileLayerDef>[
    TileLayerDef(id: 'background', kind: 'visual', visible: true),
  ],
  Iterable<PlacedPrefabDef> prefabs = const <PlacedPrefabDef>[
    PlacedPrefabDef(
      prefabId: 'rock',
      prefabKey: 'rock',
      x: 100,
      y: 224,
      zIndex: 1,
      snapToGrid: false,
      scale: 0.8,
      flipX: true,
    ),
  ],
  Iterable<PlacedMarkerDef> markers = const <PlacedMarkerDef>[
    PlacedMarkerDef(markerId: 'grojib', x: 300, y: 224, salt: 7),
  ],
  Iterable<TerrainSourceShapeDef>? collisionShapes,
}) => ChunkV2FileData(
  chunkKey: 'forest_test',
  id: 'forest_test',
  revision: 4,
  status: chunkStatusActive,
  levelId: 'forest',
  tileSize: 16,
  width: 600,
  height: 270,
  difficulty: chunkDifficultyEarly,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: tags,
  tileLayers: tileLayers,
  prefabs: prefabs,
  markers: markers,
  groundBandZIndex: -2,
  collisionShapes: collisionShapes ?? <TerrainSourceShapeDef>[_shape('ground')],
);

TerrainSourceShapeDef _shape(String shapeId, {int xOffset = 0}) =>
    TerrainSourceShapeDef(
      shapeId: shapeId,
      vertices: <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: xOffset, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: xOffset + 20, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: xOffset + 20, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: xOffset, yHalfPixels: 20),
      ],
    );

String _mutated(
  Map<String, Object?> canonical,
  void Function(Map<String, Object?> root) mutate,
) {
  final copy = jsonDecode(jsonEncode(canonical)) as Map<String, Object?>;
  mutate(copy);
  return '${const JsonEncoder.withIndent('  ').convert(copy)}\n';
}

Map<String, Object?> _firstObject(Map<String, Object?> root, String field) =>
    (root[field]! as List<Object?>).first! as Map<String, Object?>;

Matcher _formatMessage(Matcher matcher) =>
    isA<FormatException>().having((error) => error.message, 'message', matcher);
