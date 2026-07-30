import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/migration/polygon_authoring_legacy_codec.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';

void main() {
  test('all repository prefab-v2 and chunk-v1 sources parse strictly', () {
    final root = _repoRootPath();
    final prefabPath = p.join(
      root,
      'assets',
      'authoring',
      'level',
      'prefab_defs.json',
    );
    final prefabDocument = PolygonAuthoringLegacyCodec.decodePrefab(
      File(prefabPath).readAsStringSync(),
      sourcePath: 'assets/authoring/level/prefab_defs.json',
    );
    final chunkDirectory = Directory(
      p.join(root, 'assets', 'authoring', 'level', 'chunks'),
    );
    final chunkFiles =
        chunkDirectory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => p.extension(file.path).toLowerCase() == '.json')
            .toList(growable: false)
          ..sort((left, right) => left.path.compareTo(right.path));
    final chunks = <String>[];
    var gapCount = 0;
    for (final file in chunkFiles) {
      final relativePath = p
          .relative(file.path, from: root)
          .replaceAll(r'\', '/');
      final document = PolygonAuthoringLegacyCodec.decodeChunkV1(
        file.readAsStringSync(),
        sourcePath: relativePath,
      );
      final chunk = document.chunk;
      expect(document.sourceSha256, hasLength(64));
      chunks.add(chunk.chunkKey);
      gapCount += chunk.groundGaps.length;
    }

    expect(prefabDocument.sourceSchemaVersion, 2);
    expect(prefabDocument.sourceSha256, hasLength(64));
    expect(prefabDocument.prefabs, hasLength(99));
    expect(
      prefabDocument.prefabData.prefabs,
      orderedEquals(prefabDocument.prefabs),
    );
    expect(chunks, hasLength(8));
    expect(chunks.toSet(), hasLength(8));
    expect(gapCount, 1);
  });

  test('prefab-v1 promotion is explicit and deterministic', () {
    final source = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'slices': <Object?>[
        <String, Object?>{
          'id': 'slice_a',
          'sourceImagePath': 'assets/images/a.png',
          'x': 0,
          'y': 0,
          'width': 16,
          'height': 16,
        },
      ],
      'prefabs': <Object?>[_v1Prefab(id: 'Crate A'), _v1Prefab(id: 'crate_a')],
    });

    final document = PolygonAuthoringLegacyCodec.decodePrefab(source);

    expect(document.sourceSchemaVersion, 1);
    expect(document.prefabs.map((prefab) => prefab.prefabKey), <String>[
      'crate_a',
      'crate_a_2',
    ]);
    expect(
      document.prefabs.every(
        (prefab) =>
            prefab.revision == 1 &&
            prefab.status == PrefabStatus.active &&
            prefab.kind == PrefabKind.obstacle &&
            prefab.visualSource.type == PrefabVisualSourceType.atlasSlice &&
            prefab.visualSource.sliceId == 'slice_a',
      ),
      isTrue,
    );
  });

  test(
    'legacy prefab parsing rejects unknown, coerced, and unordered data',
    () {
      final root = <String, Object?>{
        'schemaVersion': 2,
        'slices': <Object?>[],
        'prefabs': <Object?>[
          _v2Prefab(
            colliders: <Object?>[
              _collider(offsetX: 0, offsetY: 0),
              _collider(offsetX: 1, offsetY: 1),
            ],
          ),
        ],
      };

      expect(
        () => PolygonAuthoringLegacyCodec.decodePrefab(
          _mutated(root, (copy) {
            final prefab = _firstObject(copy, 'prefabs');
            prefab['collisionShapes'] = <Object?>[];
          }),
        ),
        throwsA(_formatMessage(contains('unknown field collisionShapes'))),
      );
      expect(
        () => PolygonAuthoringLegacyCodec.decodePrefab(
          _mutated(root, (copy) {
            final prefab = _firstObject(copy, 'prefabs');
            final colliders = prefab['colliders']! as List<Object?>;
            final collider = colliders.first! as Map<String, Object?>;
            collider['width'] = 16.0;
          }),
        ),
        throwsA(_formatMessage(contains('width must be an integer'))),
      );
      expect(
        () => PolygonAuthoringLegacyCodec.decodePrefab(
          _mutated(root, (copy) {
            final prefab = _firstObject(copy, 'prefabs');
            final colliders = prefab['colliders']! as List<Object?>;
            prefab['colliders'] = colliders.reversed.toList(growable: false);
          }),
        ),
        throwsA(_formatMessage(contains('canonical order'))),
      );
    },
  );

  test('legacy chunk parsing rejects drift-prone source changes', () {
    final source = _chunkFixtureSource();
    final root = jsonDecode(source) as Map<String, Object?>;

    expect(
      () => PolygonAuthoringLegacyCodec.decodeChunkV1(
        _mutated(root, (copy) => copy['collisionShapes'] = <Object?>[]),
      ),
      throwsA(_formatMessage(contains('unknown field collisionShapes'))),
    );
    expect(
      () => PolygonAuthoringLegacyCodec.decodeChunkV1(
        _mutated(root, (copy) => copy['width'] = 600.0),
      ),
      throwsA(_formatMessage(contains('width must be an integer'))),
    );
    expect(
      () => PolygonAuthoringLegacyCodec.decodeChunkV1(
        _mutated(root, (copy) {
          final prefabs = copy['prefabs']! as List<Object?>;
          copy['prefabs'] = prefabs.reversed.toList(growable: false);
        }),
      ),
      throwsA(_formatMessage(contains('canonical order'))),
    );
  });
}

Map<String, Object?> _v1Prefab({required String id}) => <String, Object?>{
  'id': id,
  'sliceId': 'slice_a',
  'anchorXPx': 8,
  'anchorYPx': 16,
  'colliders': <Object?>[_collider(offsetX: 0, offsetY: 0)],
};

Map<String, Object?> _v2Prefab({
  required List<Object?> colliders,
}) => <String, Object?>{
  'prefabKey': 'crate',
  'id': 'crate',
  'revision': 1,
  'status': 'active',
  'kind': 'obstacle',
  'visualSource': <String, Object?>{'type': 'atlas_slice', 'sliceId': 'crate'},
  'anchorXPx': 8,
  'anchorYPx': 16,
  'colliders': colliders,
  'tags': <Object?>['crate'],
};

Map<String, Object?> _collider({required int offsetX, required int offsetY}) =>
    <String, Object?>{
      'offsetX': offsetX,
      'offsetY': offsetY,
      'width': 16,
      'height': 16,
    };

String _chunkFixtureSource() => jsonEncode(<String, Object?>{
  'schemaVersion': 1,
  'chunkKey': 'forest_test',
  'id': 'forest_test',
  'revision': 1,
  'status': 'active',
  'levelId': 'forest',
  'tileSize': 16,
  'width': 600,
  'height': 270,
  'difficulty': 'early',
  'assemblyGroupId': 'default',
  'tags': <Object?>[],
  'tileLayers': <Object?>[],
  'prefabs': <Object?>[
    <String, Object?>{
      'prefabId': 'low',
      'prefabKey': 'low',
      'x': 10,
      'y': 10,
      'zIndex': 0,
      'snapToGrid': true,
    },
    <String, Object?>{
      'prefabId': 'high',
      'prefabKey': 'high',
      'x': 20,
      'y': 20,
      'zIndex': 1,
      'snapToGrid': false,
    },
  ],
  'markers': <Object?>[],
  'groundProfile': <String, Object?>{'kind': 'flat', 'topY': 224},
  'groundGaps': <Object?>[],
});

String _mutated(
  Map<String, Object?> source,
  void Function(Map<String, Object?> root) mutate,
) {
  final copy = jsonDecode(jsonEncode(source)) as Map<String, Object?>;
  mutate(copy);
  return jsonEncode(copy);
}

Map<String, Object?> _firstObject(Map<String, Object?> root, String field) =>
    (root[field]! as List<Object?>).first! as Map<String, Object?>;

Matcher _formatMessage(Matcher messageMatcher) => isA<FormatException>().having(
  (error) => error.message,
  'message',
  messageMatcher,
);

String _repoRootPath() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}
