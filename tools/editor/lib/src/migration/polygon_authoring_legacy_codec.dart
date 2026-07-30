import '../chunks/chunk_domain_models.dart';
import '../domain/strict_authoring_json.dart';
import '../domain/strict_authoring_metadata_codec.dart';
import '../prefabs/models/models.dart';
import '../prefabs/store/prefab_determinism.dart';
import '../workspace/workspace_file_io.dart';
import 'legacy_prefab_models.dart';

/// Strictly parsed legacy prefab input plus its explicit source schema.
final class LegacyPrefabMigrationDocument {
  const LegacyPrefabMigrationDocument({
    required this.sourceSchemaVersion,
    required this.sourceSha256,
    required this.slices,
    required this.prefabs,
  });

  final int sourceSchemaVersion;
  final String sourceSha256;
  final List<AtlasSliceDef> slices;
  final List<LegacyPrefabDef> prefabs;

  /// Adapts this prefab-only file to the aggregate migration planner input.
  LegacyPrefabData get prefabData => LegacyPrefabData(
    schemaVersion: sourceSchemaVersion,
    prefabSlices: slices,
    prefabs: prefabs,
  );
}

/// Strictly parsed legacy chunk input bound to its exact source text.
final class LegacyChunkMigrationDocument {
  const LegacyChunkMigrationDocument({
    required this.sourceSha256,
    required this.chunk,
  });

  final String sourceSha256;
  final LevelChunkDef chunk;
}

/// Read-only, fail-closed parser for source schemas consumed by cutover.
///
/// The normal editor stores intentionally support compatibility defaults. This
/// codec does not: only documented prefab-v1/v2 and chunk-v1 fields are
/// accepted, with exact JSON types and canonical v2/v1 ordering. Prefab-v1
/// lifecycle/key defaults are promoted explicitly after its source shape has
/// passed strict validation.
abstract final class PolygonAuthoringLegacyCodec {
  /// Parses one legacy prefab-v1 or prefab-v2 source file.
  static LegacyPrefabMigrationDocument decodePrefab(
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
    final schemaVersion = StrictAuthoringJson.integer(
      root['schemaVersion'],
      sourcePath: '$sourcePath.schemaVersion',
    );
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw FormatException(
        '$sourcePath.schemaVersion must be exactly 1 or 2.',
      );
    }
    final slices = StrictAuthoringJson.objectList(
      root['slices'],
      sourcePath: '$sourcePath.slices',
      parse: PolygonAuthoringMetadataCodec.decodeSlice,
    );
    StrictAuthoringJson.requireComparatorOrder(
      slices,
      PrefabDeterminism.compareSlicesByIdThenSourceRect,
      sourcePath: '$sourcePath.slices',
    );
    final prefabs = schemaVersion == 1
        ? _decodePrefabV1List(
            root['prefabs'],
            sourcePath: '$sourcePath.prefabs',
          )
        : StrictAuthoringJson.objectList(
            root['prefabs'],
            sourcePath: '$sourcePath.prefabs',
            parse: _decodePrefabV2,
          );
    if (schemaVersion == 2) {
      StrictAuthoringJson.requireComparatorOrder(
        prefabs,
        compareLegacyPrefabDefs,
        sourcePath: '$sourcePath.prefabs',
      );
      StrictAuthoringJson.requireUniqueStrings(
        prefabs.map((prefab) => prefab.prefabKey),
        sourcePath: '$sourcePath.prefabs.prefabKey',
        caseInsensitive: true,
      );
    }
    return LegacyPrefabMigrationDocument(
      sourceSchemaVersion: schemaVersion,
      sourceSha256: WorkspaceFileIo.sha256Digest(raw),
      slices: List<AtlasSliceDef>.unmodifiable(slices),
      prefabs: List<LegacyPrefabDef>.unmodifiable(prefabs),
    );
  }

  /// Parses one chunk-v1 source file without applying runtime authority.
  static LegacyChunkMigrationDocument decodeChunkV1(
    String raw, {
    String sourcePath = 'chunk.json',
  }) {
    final root = StrictAuthoringJson.decodeRoot(raw, sourcePath: sourcePath);
    StrictAuthoringJson.requireKeys(
      root,
      sourcePath: sourcePath,
      allowed: const <String>{
        'schemaVersion',
        'chunkKey',
        'id',
        'revision',
        'status',
        'levelId',
        'tileSize',
        'width',
        'height',
        'difficulty',
        'assemblyGroupId',
        'tags',
        'tileLayers',
        'prefabs',
        'markers',
        'groundProfile',
        'groundBandZIndex',
        'groundGaps',
      },
      required: const <String>{
        'schemaVersion',
        'chunkKey',
        'id',
        'revision',
        'status',
        'levelId',
        'tileSize',
        'width',
        'height',
        'difficulty',
        'assemblyGroupId',
        'tags',
        'tileLayers',
        'prefabs',
        'markers',
        'groundProfile',
        'groundGaps',
      },
    );
    StrictAuthoringJson.requireSchemaVersion(
      root['schemaVersion'],
      chunkSchemaVersion,
      sourcePath: '$sourcePath.schemaVersion',
    );
    final chunkKey = StrictAuthoringJson.nonEmptyString(
      root['chunkKey'],
      sourcePath: '$sourcePath.chunkKey',
    );
    if (!ChunkKey(chunkKey).isValid) {
      throw FormatException(
        '$sourcePath.chunkKey must contain lowercase letters, digits, and underscore.',
      );
    }
    final assemblyGroupId = StrictAuthoringJson.nonEmptyString(
      root['assemblyGroupId'],
      sourcePath: '$sourcePath.assemblyGroupId',
    );
    if (!stableChunkAssemblyGroupPattern.hasMatch(assemblyGroupId)) {
      throw FormatException(
        '$sourcePath.assemblyGroupId must match '
        '${stableChunkAssemblyGroupPattern.pattern}.',
      );
    }
    final tileLayers = StrictAuthoringJson.objectList(
      root['tileLayers'],
      sourcePath: '$sourcePath.tileLayers',
      parse: PolygonAuthoringMetadataCodec.decodeTileLayer,
    );
    StrictAuthoringJson.requireStrictStringOrder(
      tileLayers.map((layer) => layer.id),
      sourcePath: '$sourcePath.tileLayers',
    );
    final prefabs = StrictAuthoringJson.objectList(
      root['prefabs'],
      sourcePath: '$sourcePath.prefabs',
      parse: PolygonAuthoringMetadataCodec.decodePlacement,
    );
    StrictAuthoringJson.requireComparatorOrder(
      prefabs,
      comparePlacedPrefabsDeterministic,
      sourcePath: '$sourcePath.prefabs',
    );
    final markers = StrictAuthoringJson.objectList(
      root['markers'],
      sourcePath: '$sourcePath.markers',
      parse: PolygonAuthoringMetadataCodec.decodeMarker,
    );
    StrictAuthoringJson.requireComparatorOrder(
      markers,
      comparePlacedMarkersDeterministic,
      sourcePath: '$sourcePath.markers',
    );
    final groundProfile = _decodeGroundProfile(
      root['groundProfile'],
      sourcePath: '$sourcePath.groundProfile',
    );
    final groundGaps = StrictAuthoringJson.objectList(
      root['groundGaps'],
      sourcePath: '$sourcePath.groundGaps',
      parse: _decodeGroundGap,
    );
    StrictAuthoringJson.requireComparatorOrder(
      groundGaps,
      _compareGroundGaps,
      sourcePath: '$sourcePath.groundGaps',
    );
    StrictAuthoringJson.requireUniqueStrings(
      groundGaps.map((gap) => gap.gapId),
      sourcePath: '$sourcePath.groundGaps.gapId',
      caseInsensitive: true,
    );
    final chunk = LevelChunkDef(
      schemaVersion: chunkSchemaVersion,
      chunkKey: chunkKey,
      id: StrictAuthoringJson.nonEmptyString(
        root['id'],
        sourcePath: '$sourcePath.id',
      ),
      revision: StrictAuthoringJson.positiveInt(
        root['revision'],
        sourcePath: '$sourcePath.revision',
      ),
      status: StrictAuthoringJson.enumString(root['status'], const <String>{
        chunkStatusActive,
        chunkStatusDeprecated,
      }, sourcePath: '$sourcePath.status'),
      levelId: StrictAuthoringJson.nonEmptyString(
        root['levelId'],
        sourcePath: '$sourcePath.levelId',
      ),
      tileSize: StrictAuthoringJson.positiveInt(
        root['tileSize'],
        sourcePath: '$sourcePath.tileSize',
      ),
      width: StrictAuthoringJson.positiveInt(
        root['width'],
        sourcePath: '$sourcePath.width',
      ),
      height: StrictAuthoringJson.positiveInt(
        root['height'],
        sourcePath: '$sourcePath.height',
      ),
      difficulty:
          StrictAuthoringJson.enumString(root['difficulty'], const <String>{
            chunkDifficultyEarly,
            chunkDifficultyEasy,
            chunkDifficultyNormal,
            chunkDifficultyHard,
          }, sourcePath: '$sourcePath.difficulty'),
      assemblyGroupId: assemblyGroupId,
      tags: StrictAuthoringJson.canonicalTags(
        root['tags'],
        sourcePath: '$sourcePath.tags',
      ),
      tileLayers: List<TileLayerDef>.unmodifiable(tileLayers),
      prefabs: List<PlacedPrefabDef>.unmodifiable(prefabs),
      markers: List<PlacedMarkerDef>.unmodifiable(markers),
      groundProfile: groundProfile,
      groundBandZIndex: root.containsKey('groundBandZIndex')
          ? StrictAuthoringJson.integer(
              root['groundBandZIndex'],
              sourcePath: '$sourcePath.groundBandZIndex',
            )
          : 0,
      groundGaps: List<GroundGapDef>.unmodifiable(groundGaps),
    );
    return LegacyChunkMigrationDocument(
      sourceSha256: WorkspaceFileIo.sha256Digest(raw),
      chunk: chunk,
    );
  }
}

List<LegacyPrefabDef> _decodePrefabV1List(
  Object? raw, {
  required String sourcePath,
}) {
  final parsed = StrictAuthoringJson.objectList(
    raw,
    sourcePath: sourcePath,
    parse: _decodePrefabV1,
  );
  final usedKeys = <String>{};
  final promoted = <LegacyPrefabDef>[];
  for (final prefab in parsed) {
    final prefabKey = PrefabDeterminism.allocatePrefabKey(
      id: prefab.id,
      usedPrefabKeys: usedKeys,
    );
    usedKeys.add(prefabKey);
    promoted.add(prefab.copyWith(prefabKey: prefabKey));
  }
  return promoted;
}

LegacyPrefabDef _decodePrefabV1(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  StrictAuthoringJson.requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{
      'id',
      'sliceId',
      'anchorXPx',
      'anchorYPx',
      'colliders',
      'tags',
    },
    required: const <String>{
      'id',
      'sliceId',
      'anchorXPx',
      'anchorYPx',
      'colliders',
    },
  );
  return LegacyPrefabDef(
    id: StrictAuthoringJson.nonEmptyString(
      json['id'],
      sourcePath: '$sourcePath.id',
    ),
    revision: 1,
    status: PrefabStatus.active,
    kind: PrefabKind.obstacle,
    visualSource: PrefabVisualSource.atlasSlice(
      StrictAuthoringJson.nonEmptyString(
        json['sliceId'],
        sourcePath: '$sourcePath.sliceId',
      ),
    ),
    anchorXPx: StrictAuthoringJson.integer(
      json['anchorXPx'],
      sourcePath: '$sourcePath.anchorXPx',
    ),
    anchorYPx: StrictAuthoringJson.integer(
      json['anchorYPx'],
      sourcePath: '$sourcePath.anchorYPx',
    ),
    colliders: _decodeColliders(
      json['colliders'],
      sourcePath: '$sourcePath.colliders',
    ),
    tags: json.containsKey('tags')
        ? StrictAuthoringJson.canonicalTags(
            json['tags'],
            sourcePath: '$sourcePath.tags',
          )
        : const <String>[],
  );
}

LegacyPrefabDef _decodePrefabV2(
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
      'colliders',
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
      'colliders',
      'tags',
    },
  );
  final prefabKey = StrictAuthoringJson.nonEmptyString(
    json['prefabKey'],
    sourcePath: '$sourcePath.prefabKey',
  );
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(prefabKey)) {
    throw FormatException(
      '$sourcePath.prefabKey must contain lowercase letters, digits, and underscore.',
    );
  }
  return LegacyPrefabDef(
    prefabKey: prefabKey,
    id: StrictAuthoringJson.nonEmptyString(
      json['id'],
      sourcePath: '$sourcePath.id',
    ),
    revision: StrictAuthoringJson.positiveInt(
      json['revision'],
      sourcePath: '$sourcePath.revision',
    ),
    status: parsePrefabStatus(
      StrictAuthoringJson.enumString(json['status'], const <String>{
        'active',
        'deprecated',
      }, sourcePath: '$sourcePath.status'),
    ),
    kind: parsePrefabKind(
      StrictAuthoringJson.enumString(json['kind'], const <String>{
        'obstacle',
        'platform',
        'decoration',
      }, sourcePath: '$sourcePath.kind'),
    ),
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
    colliders: _decodeColliders(
      json['colliders'],
      sourcePath: '$sourcePath.colliders',
    ),
    tags: StrictAuthoringJson.canonicalTags(
      json['tags'],
      sourcePath: '$sourcePath.tags',
    ),
  );
}

List<PrefabColliderDef> _decodeColliders(
  Object? raw, {
  required String sourcePath,
}) {
  final colliders = StrictAuthoringJson.objectList(
    raw,
    sourcePath: sourcePath,
    parse: _decodeCollider,
  );
  StrictAuthoringJson.requireComparatorOrder(
    colliders,
    _compareColliders,
    sourcePath: sourcePath,
  );
  return List<PrefabColliderDef>.unmodifiable(colliders);
}

PrefabColliderDef _decodeCollider(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  StrictAuthoringJson.requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{'offsetX', 'offsetY', 'width', 'height'},
    required: const <String>{'offsetX', 'offsetY', 'width', 'height'},
  );
  return PrefabColliderDef(
    offsetX: StrictAuthoringJson.integer(
      json['offsetX'],
      sourcePath: '$sourcePath.offsetX',
    ),
    offsetY: StrictAuthoringJson.integer(
      json['offsetY'],
      sourcePath: '$sourcePath.offsetY',
    ),
    width: StrictAuthoringJson.positiveInt(
      json['width'],
      sourcePath: '$sourcePath.width',
    ),
    height: StrictAuthoringJson.positiveInt(
      json['height'],
      sourcePath: '$sourcePath.height',
    ),
  );
}

GroundProfileDef _decodeGroundProfile(
  Object? raw, {
  required String sourcePath,
}) {
  final json = StrictAuthoringJson.object(raw, sourcePath: sourcePath);
  StrictAuthoringJson.requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{'kind', 'topY'},
    required: const <String>{'kind', 'topY'},
  );
  return GroundProfileDef(
    kind: StrictAuthoringJson.enumString(json['kind'], const <String>{
      groundProfileKindFlat,
    }, sourcePath: '$sourcePath.kind'),
    topY: StrictAuthoringJson.integer(
      json['topY'],
      sourcePath: '$sourcePath.topY',
    ),
  );
}

GroundGapDef _decodeGroundGap(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  StrictAuthoringJson.requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{'gapId', 'type', 'x', 'width'},
    required: const <String>{'gapId', 'type', 'x', 'width'},
  );
  return GroundGapDef(
    gapId: StrictAuthoringJson.nonEmptyString(
      json['gapId'],
      sourcePath: '$sourcePath.gapId',
    ),
    type: StrictAuthoringJson.enumString(json['type'], const <String>{
      groundGapTypePit,
    }, sourcePath: '$sourcePath.type'),
    x: StrictAuthoringJson.integer(json['x'], sourcePath: '$sourcePath.x'),
    width: StrictAuthoringJson.positiveInt(
      json['width'],
      sourcePath: '$sourcePath.width',
    ),
  );
}

int _compareColliders(PrefabColliderDef left, PrefabColliderDef right) {
  var order = left.offsetY.compareTo(right.offsetY);
  if (order != 0) return order;
  order = left.offsetX.compareTo(right.offsetX);
  if (order != 0) return order;
  order = left.width.compareTo(right.width);
  if (order != 0) return order;
  return left.height.compareTo(right.height);
}

int _compareGroundGaps(GroundGapDef left, GroundGapDef right) {
  var order = left.x.compareTo(right.x);
  if (order != 0) return order;
  order = left.width.compareTo(right.width);
  if (order != 0) return order;
  return left.gapId.compareTo(right.gapId);
}
