import '../chunks/chunk_domain_models.dart';
import '../prefabs/models/models.dart';
import 'strict_migration_json.dart';

/// Strict parser for metadata retained unchanged across polygon schema cutover.
///
/// Keeping these parsers shared prevents the legacy reader and staged target
/// reader from disagreeing about fields that the migration only copies.
abstract final class PolygonAuthoringMetadataCodec {
  /// Parses one atlas slice without applying model defaults.
  static AtlasSliceDef decodeSlice(
    Map<String, Object?> json, {
    required String sourcePath,
  }) {
    StrictMigrationJson.requireKeys(
      json,
      sourcePath: sourcePath,
      allowed: const <String>{
        'id',
        'sourceImagePath',
        'x',
        'y',
        'width',
        'height',
        'tags',
      },
      required: const <String>{
        'id',
        'sourceImagePath',
        'x',
        'y',
        'width',
        'height',
      },
    );
    return AtlasSliceDef(
      id: StrictMigrationJson.nonEmptyString(
        json['id'],
        sourcePath: '$sourcePath.id',
      ),
      sourceImagePath: StrictMigrationJson.nonEmptyString(
        json['sourceImagePath'],
        sourcePath: '$sourcePath.sourceImagePath',
      ),
      x: StrictMigrationJson.integer(json['x'], sourcePath: '$sourcePath.x'),
      y: StrictMigrationJson.integer(json['y'], sourcePath: '$sourcePath.y'),
      width: StrictMigrationJson.positiveInt(
        json['width'],
        sourcePath: '$sourcePath.width',
      ),
      height: StrictMigrationJson.positiveInt(
        json['height'],
        sourcePath: '$sourcePath.height',
      ),
      tags: json.containsKey('tags')
          ? StrictMigrationJson.canonicalTags(
              json['tags'],
              sourcePath: '$sourcePath.tags',
            )
          : const <String>[],
    );
  }

  /// Parses one v2/v3 discriminated prefab visual source.
  static PrefabVisualSource decodeVisualSource(
    Object? raw, {
    required String sourcePath,
  }) {
    final json = StrictMigrationJson.object(raw, sourcePath: sourcePath);
    final type = StrictMigrationJson.enumString(json['type'], const <String>{
      'atlas_slice',
      'platform_module',
    }, sourcePath: '$sourcePath.type');
    if (type == 'atlas_slice') {
      StrictMigrationJson.requireKeys(
        json,
        sourcePath: sourcePath,
        allowed: const <String>{'type', 'sliceId'},
        required: const <String>{'type', 'sliceId'},
      );
      return PrefabVisualSource.atlasSlice(
        StrictMigrationJson.nonEmptyString(
          json['sliceId'],
          sourcePath: '$sourcePath.sliceId',
        ),
      );
    }
    StrictMigrationJson.requireKeys(
      json,
      sourcePath: sourcePath,
      allowed: const <String>{'type', 'moduleId'},
      required: const <String>{'type', 'moduleId'},
    );
    return PrefabVisualSource.platformModule(
      StrictMigrationJson.nonEmptyString(
        json['moduleId'],
        sourcePath: '$sourcePath.moduleId',
      ),
    );
  }

  /// Parses one chunk tile-layer record without applying defaults.
  static TileLayerDef decodeTileLayer(
    Map<String, Object?> json, {
    required String sourcePath,
  }) {
    StrictMigrationJson.requireKeys(
      json,
      sourcePath: sourcePath,
      allowed: const <String>{'id', 'kind', 'visible'},
      required: const <String>{'id', 'kind', 'visible'},
    );
    return TileLayerDef(
      id: StrictMigrationJson.nonEmptyString(
        json['id'],
        sourcePath: '$sourcePath.id',
      ),
      kind: StrictMigrationJson.nonEmptyString(
        json['kind'],
        sourcePath: '$sourcePath.kind',
      ),
      visible: StrictMigrationJson.boolean(
        json['visible'],
        sourcePath: '$sourcePath.visible',
      ),
    );
  }

  /// Parses one chunk prefab placement, including only documented optionals.
  static PlacedPrefabDef decodePlacement(
    Map<String, Object?> json, {
    required String sourcePath,
  }) {
    StrictMigrationJson.requireKeys(
      json,
      sourcePath: sourcePath,
      allowed: const <String>{
        'prefabId',
        'prefabKey',
        'x',
        'y',
        'zIndex',
        'snapToGrid',
        'scale',
        'flipX',
        'flipY',
      },
      required: const <String>{'prefabId', 'x', 'y', 'zIndex', 'snapToGrid'},
    );
    return PlacedPrefabDef(
      prefabId: StrictMigrationJson.nonEmptyString(
        json['prefabId'],
        sourcePath: '$sourcePath.prefabId',
      ),
      prefabKey: json.containsKey('prefabKey')
          ? StrictMigrationJson.nonEmptyString(
              json['prefabKey'],
              sourcePath: '$sourcePath.prefabKey',
            )
          : '',
      x: StrictMigrationJson.integer(json['x'], sourcePath: '$sourcePath.x'),
      y: StrictMigrationJson.integer(json['y'], sourcePath: '$sourcePath.y'),
      zIndex: StrictMigrationJson.integer(
        json['zIndex'],
        sourcePath: '$sourcePath.zIndex',
      ),
      snapToGrid: StrictMigrationJson.boolean(
        json['snapToGrid'],
        sourcePath: '$sourcePath.snapToGrid',
      ),
      scale: json.containsKey('scale')
          ? StrictMigrationJson.prefabScale(
              json['scale'],
              sourcePath: '$sourcePath.scale',
            )
          : defaultPrefabPlacementScale,
      flipX: json.containsKey('flipX')
          ? StrictMigrationJson.boolean(
              json['flipX'],
              sourcePath: '$sourcePath.flipX',
            )
          : false,
      flipY: json.containsKey('flipY')
          ? StrictMigrationJson.boolean(
              json['flipY'],
              sourcePath: '$sourcePath.flipY',
            )
          : false,
    );
  }

  /// Parses one chunk marker with the exact supported placement vocabulary.
  static PlacedMarkerDef decodeMarker(
    Map<String, Object?> json, {
    required String sourcePath,
  }) {
    StrictMigrationJson.requireKeys(
      json,
      sourcePath: sourcePath,
      allowed: const <String>{
        'markerId',
        'x',
        'y',
        'chancePercent',
        'salt',
        'placement',
      },
      required: const <String>{
        'markerId',
        'x',
        'y',
        'chancePercent',
        'salt',
        'placement',
      },
    );
    final chancePercent = StrictMigrationJson.integer(
      json['chancePercent'],
      sourcePath: '$sourcePath.chancePercent',
    );
    if (chancePercent < 0 || chancePercent > 100) {
      throw FormatException('$sourcePath.chancePercent must be from 0 to 100.');
    }
    return PlacedMarkerDef(
      markerId: StrictMigrationJson.nonEmptyString(
        json['markerId'],
        sourcePath: '$sourcePath.markerId',
      ),
      x: StrictMigrationJson.integer(json['x'], sourcePath: '$sourcePath.x'),
      y: StrictMigrationJson.integer(json['y'], sourcePath: '$sourcePath.y'),
      chancePercent: chancePercent,
      salt: StrictMigrationJson.integer(
        json['salt'],
        sourcePath: '$sourcePath.salt',
      ),
      placement:
          StrictMigrationJson.enumString(json['placement'], const <String>{
            markerPlacementGround,
            markerPlacementHighestSurfaceAtX,
            markerPlacementObstacleTop,
          }, sourcePath: '$sourcePath.placement'),
    );
  }
}
