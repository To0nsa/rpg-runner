import '../chunks/chunk_domain_models.dart';
import '../prefabs/models/models.dart';
import 'strict_authoring_json.dart';

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
    StrictAuthoringJson.requireKeys(
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
      id: StrictAuthoringJson.nonEmptyString(
        json['id'],
        sourcePath: '$sourcePath.id',
      ),
      sourceImagePath: StrictAuthoringJson.nonEmptyString(
        json['sourceImagePath'],
        sourcePath: '$sourcePath.sourceImagePath',
      ),
      x: StrictAuthoringJson.integer(json['x'], sourcePath: '$sourcePath.x'),
      y: StrictAuthoringJson.integer(json['y'], sourcePath: '$sourcePath.y'),
      width: StrictAuthoringJson.positiveInt(
        json['width'],
        sourcePath: '$sourcePath.width',
      ),
      height: StrictAuthoringJson.positiveInt(
        json['height'],
        sourcePath: '$sourcePath.height',
      ),
      tags: json.containsKey('tags')
          ? StrictAuthoringJson.canonicalTags(
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
    final json = StrictAuthoringJson.object(raw, sourcePath: sourcePath);
    final type = StrictAuthoringJson.enumString(json['type'], const <String>{
      'atlas_slice',
      'platform_module',
    }, sourcePath: '$sourcePath.type');
    if (type == 'atlas_slice') {
      StrictAuthoringJson.requireKeys(
        json,
        sourcePath: sourcePath,
        allowed: const <String>{'type', 'sliceId'},
        required: const <String>{'type', 'sliceId'},
      );
      return PrefabVisualSource.atlasSlice(
        StrictAuthoringJson.nonEmptyString(
          json['sliceId'],
          sourcePath: '$sourcePath.sliceId',
        ),
      );
    }
    StrictAuthoringJson.requireKeys(
      json,
      sourcePath: sourcePath,
      allowed: const <String>{'type', 'moduleId'},
      required: const <String>{'type', 'moduleId'},
    );
    return PrefabVisualSource.platformModule(
      StrictAuthoringJson.nonEmptyString(
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
    StrictAuthoringJson.requireKeys(
      json,
      sourcePath: sourcePath,
      allowed: const <String>{'id', 'kind', 'visible'},
      required: const <String>{'id', 'kind', 'visible'},
    );
    return TileLayerDef(
      id: StrictAuthoringJson.nonEmptyString(
        json['id'],
        sourcePath: '$sourcePath.id',
      ),
      kind: StrictAuthoringJson.nonEmptyString(
        json['kind'],
        sourcePath: '$sourcePath.kind',
      ),
      visible: StrictAuthoringJson.boolean(
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
    StrictAuthoringJson.requireKeys(
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
      prefabId: StrictAuthoringJson.nonEmptyString(
        json['prefabId'],
        sourcePath: '$sourcePath.prefabId',
      ),
      prefabKey: json.containsKey('prefabKey')
          ? StrictAuthoringJson.nonEmptyString(
              json['prefabKey'],
              sourcePath: '$sourcePath.prefabKey',
            )
          : '',
      x: StrictAuthoringJson.integer(json['x'], sourcePath: '$sourcePath.x'),
      y: StrictAuthoringJson.integer(json['y'], sourcePath: '$sourcePath.y'),
      zIndex: StrictAuthoringJson.integer(
        json['zIndex'],
        sourcePath: '$sourcePath.zIndex',
      ),
      snapToGrid: StrictAuthoringJson.boolean(
        json['snapToGrid'],
        sourcePath: '$sourcePath.snapToGrid',
      ),
      scale: json.containsKey('scale')
          ? StrictAuthoringJson.prefabScale(
              json['scale'],
              sourcePath: '$sourcePath.scale',
            )
          : defaultPrefabPlacementScale,
      flipX: json.containsKey('flipX')
          ? StrictAuthoringJson.boolean(
              json['flipX'],
              sourcePath: '$sourcePath.flipX',
            )
          : false,
      flipY: json.containsKey('flipY')
          ? StrictAuthoringJson.boolean(
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
    StrictAuthoringJson.requireKeys(
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
    final chancePercent = StrictAuthoringJson.integer(
      json['chancePercent'],
      sourcePath: '$sourcePath.chancePercent',
    );
    if (chancePercent < 0 || chancePercent > 100) {
      throw FormatException('$sourcePath.chancePercent must be from 0 to 100.');
    }
    return PlacedMarkerDef(
      markerId: StrictAuthoringJson.nonEmptyString(
        json['markerId'],
        sourcePath: '$sourcePath.markerId',
      ),
      x: StrictAuthoringJson.integer(json['x'], sourcePath: '$sourcePath.x'),
      y: StrictAuthoringJson.integer(json['y'], sourcePath: '$sourcePath.y'),
      chancePercent: chancePercent,
      salt: StrictAuthoringJson.integer(
        json['salt'],
        sourcePath: '$sourcePath.salt',
      ),
      placement:
          StrictAuthoringJson.enumString(json['placement'], const <String>{
            markerPlacementGround,
            markerPlacementHighestSurfaceAtX,
            markerPlacementObstacleTop,
          }, sourcePath: '$sourcePath.placement'),
    );
  }
}
