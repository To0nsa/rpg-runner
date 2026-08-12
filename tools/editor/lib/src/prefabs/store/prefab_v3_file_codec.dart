import '../../domain/strict_authoring_json.dart';
import '../../domain/strict_authoring_metadata_codec.dart';
import '../../terrain_authoring/strict_terrain_source_codec.dart';
import '../../terrain_authoring/terrain_source_models.dart';
import '../models/models.dart';
import 'prefab_determinism.dart';

/// Strict normal-layer codec for one `prefab_defs.json` schema-v3 file.
///
/// It owns the single prefab-v3 structural interpretation used by both the
/// normal store and the read-only migration checker. It performs no filesystem
/// I/O; transactional stores own source writes.
abstract final class PrefabV3FileCodec {
  /// Parses canonical schema-v3 source without legacy defaults or coercion.
  static PrefabV3FileData decode(
    String raw, {
    String sourcePath = 'prefab_defs.json',
  }) {
    final root = StrictAuthoringJson.decodeRoot(raw, sourcePath: sourcePath);
    StrictAuthoringJson.requireKeys(
      root,
      sourcePath: sourcePath,
      allowed: const <String>{'schemaVersion', 'slices', 'prefabs'},
      required: const <String>{'schemaVersion', 'slices', 'prefabs'},
    );
    StrictAuthoringJson.requireSchemaVersion(
      root['schemaVersion'],
      prefabSchemaVersionV3,
      sourcePath: '$sourcePath.schemaVersion',
    );

    final slices = StrictAuthoringJson.objectList(
      root['slices'],
      sourcePath: '$sourcePath.slices',
      parse: PolygonAuthoringMetadataCodec.decodeSlice,
    );
    StrictAuthoringJson.requireStrictStringOrder(
      slices.map((slice) => slice.id),
      sourcePath: '$sourcePath.slices',
    );

    final prefabs = StrictAuthoringJson.objectList(
      root['prefabs'],
      sourcePath: '$sourcePath.prefabs',
      parse: _decodePrefab,
    );
    _requirePrefabIdentities(prefabs, sourcePath: '$sourcePath.prefabs');
    return PrefabV3FileData(slices: slices, prefabs: prefabs);
  }

  /// Emits canonical schema-v3 JSON with one final newline.
  ///
  /// The returned data is normalized on copies. Supplied records retain their
  /// authored ordering so validation can still diagnose them.
  static String encode(PrefabV3FileData data) {
    final slices = PrefabDeterminism.sortSlicesByIdThenSourceRect(
      data.slices.map(
        (slice) =>
            slice.copyWith(tags: PrefabDeterminism.normalizeTags(slice.tags)),
      ),
    );
    StrictAuthoringJson.requireStrictStringOrder(
      slices.map((slice) => slice.id),
      sourcePath: 'prefab_defs.json.slices',
    );

    final prefabs = PrefabDeterminism.sortPrefabV3ByIdThenKey(
      data.prefabs.map(
        (prefab) => prefab.copyWith(
          collisionShapes: canonicalTerrainSourceShapes(prefab.collisionShapes),
          tags: PrefabDeterminism.normalizeTags(prefab.tags),
        ),
      ),
    );
    _requirePrefabIdentities(prefabs, sourcePath: 'prefab_defs.json.prefabs');

    final encoded = StrictAuthoringJson.encode(<String, Object>{
      'schemaVersion': prefabSchemaVersionV3,
      'slices': slices.map((slice) => slice.toJson()).toList(growable: false),
      'prefabs': prefabs
          .map((prefab) => prefab.toJson())
          .toList(growable: false),
    });
    decode(encoded);
    return encoded;
  }
}

PrefabV3Def _decodePrefab(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  StrictAuthoringJson.requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{
      'prefabKey',
      'id',
      'revision',
      'status',
      'kind',
      'visualSource',
      'anchorXPx',
      'anchorYPx',
      'collisionShapes',
      'tags',
    },
    required: const <String>{
      'prefabKey',
      'id',
      'revision',
      'status',
      'kind',
      'visualSource',
      'anchorXPx',
      'anchorYPx',
      'collisionShapes',
      'tags',
    },
  );
  final status = StrictAuthoringJson.enumString(json['status'], const <String>{
    'active',
    'deprecated',
  }, sourcePath: '$sourcePath.status');
  final kind = StrictAuthoringJson.enumString(json['kind'], const <String>{
    'obstacle',
    'platform',
    'decoration',
  }, sourcePath: '$sourcePath.kind');
  return PrefabV3Def(
    prefabKey: StrictAuthoringJson.nonEmptyString(
      json['prefabKey'],
      sourcePath: '$sourcePath.prefabKey',
    ),
    id: StrictAuthoringJson.nonEmptyString(
      json['id'],
      sourcePath: '$sourcePath.id',
    ),
    revision: StrictAuthoringJson.positiveInt(
      json['revision'],
      sourcePath: '$sourcePath.revision',
    ),
    status: parsePrefabStatus(status),
    kind: parsePrefabKind(kind),
    visualSource: PolygonAuthoringMetadataCodec.decodeVisualSource(
      json['visualSource'],
      sourcePath: '$sourcePath.visualSource',
    ),
    anchorXPx: StrictAuthoringJson.integer(
      json['anchorXPx'],
      sourcePath: '$sourcePath.anchorXPx',
    ),
    anchorYPx: StrictAuthoringJson.integer(
      json['anchorYPx'],
      sourcePath: '$sourcePath.anchorYPx',
    ),
    collisionShapes: StrictTerrainSourceCodec.decodeShapes(
      json['collisionShapes'],
      sourcePath: '$sourcePath.collisionShapes',
    ),
    tags: StrictAuthoringJson.canonicalTags(
      json['tags'],
      sourcePath: '$sourcePath.tags',
    ),
  );
}

void _requirePrefabIdentities(
  List<PrefabV3Def> prefabs, {
  required String sourcePath,
}) {
  StrictAuthoringJson.requireComparatorOrder(
    prefabs,
    PrefabDeterminism.comparePrefabV3ByIdThenKey,
    sourcePath: sourcePath,
  );
  StrictAuthoringJson.requireUniqueStrings(
    prefabs.map((prefab) => prefab.prefabKey),
    sourcePath: '$sourcePath.prefabKey',
    caseInsensitive: true,
  );
}
