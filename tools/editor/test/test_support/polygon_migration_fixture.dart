import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:runner_editor/src/migration/polygon_authoring_target_codec.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';

/// A fixed migration inventory, independent of the evolving gameplay catalog.
///
/// The three reviewed historical keys are intentional: the offline migration
/// fails closed when one is missing, even for collision-cleared source. An
/// ordinary platform and decoration exercise the remaining inventory kinds.
String polygonMigrationPrefabSource() {
  final source = <String, Object?>{
    'schemaVersion': 3,
    'slices': <Object?>[
      <String, Object?>{
        'id': 'fixture_slice',
        'sourceImagePath':
            'assets/images/level/atlases/migration_fixture/props.png',
        'x': 0,
        'y': 0,
        'width': 32,
        'height': 32,
        'tags': <String>[],
      },
    ],
    'prefabs': <Object?>[
      for (final (key, kind) in const <(String, String)>[
        ('dark_menhir_01', 'obstacle'),
        ('dark_menhir_03', 'obstacle'),
        ('fixture_decoration', 'decoration'),
        ('fixture_platform', 'platform'),
        ('ruin_stone_00', 'obstacle'),
      ])
        <String, Object?>{
          'prefabKey': key,
          'id': key,
          'revision': 1,
          'status': 'active',
          'kind': kind,
          'visualSource': <String, Object?>{
            'type': 'atlas_slice',
            'sliceId': 'fixture_slice',
          },
          'anchorXPx': 16,
          'anchorYPx': 16,
          'collisionShapes': <Object?>[],
          'tags': <String>[],
        },
    ],
  };
  return PolygonAuthoringTargetCodec.encodePrefabV3(
    PolygonAuthoringTargetCodec.decodePrefabV3(jsonEncode(source)),
  );
}

/// Two fixed current-schema chunks used for whole-generation migration tests.
Map<String, String> polygonMigrationChunkSources() => <String, String>{
  for (final key in const <String>['fixture_a', 'fixture_b'])
    'assets/authoring/level/chunks/$key.json':
        PolygonAuthoringTargetCodec.encodeChunkV2(
          PolygonAuthoringTargetCodec.decodeChunkV2(
            jsonEncode(<String, Object?>{
              'schemaVersion': 2,
              'chunkKey': key,
              'id': key,
              'revision': 1,
              'status': 'active',
              'levelId': 'field',
              'tileSize': 16,
              'width': 600,
              'height': 270,
              'difficulty': 'early',
              'assemblyGroupId': 'default',
              'tags': <String>[],
              'tileLayers': <Object?>[],
              'prefabs': <Object?>[],
              'markers': <Object?>[],
              'collisionShapes': <Object?>[],
            }),
          ),
        ),
};

/// Writes only the stable migration inventory into a disposable workspace.
Directory createPolygonMigrationFixture(String prefix) {
  final root = Directory.systemTemp.createTempSync(prefix);
  final sources = <String, String>{
    PrefabStore.prefabDefsPath: polygonMigrationPrefabSource(),
    ...polygonMigrationChunkSources(),
  };
  for (final source in sources.entries) {
    final file = File(p.join(root.path, source.key));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(source.value);
  }
  return root;
}
