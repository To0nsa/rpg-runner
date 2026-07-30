import '../../domain/strict_authoring_json.dart';
import '../../domain/strict_authoring_metadata_codec.dart';
import '../models/models.dart';
import 'prefab_determinism.dart';

/// Strict codec for the retained `tile_defs.json` schema-v2 contract.
///
/// It is used by prefab-v3 staging so that malformed tile/module source cannot
/// be silently normalized by the rectangle-era compatibility store. It owns no
/// filesystem I/O and does not enable repository writes.
abstract final class PrefabTileFileCodec {
  static PrefabTileFileData decode(
    String raw, {
    String sourcePath = 'tile_defs.json',
  }) {
    final root = StrictAuthoringJson.decodeRoot(raw, sourcePath: sourcePath);
    StrictAuthoringJson.requireKeys(
      root,
      sourcePath: sourcePath,
      allowed: const <String>{'schemaVersion', 'tileSlices', 'platformModules'},
      required: const <String>{
        'schemaVersion',
        'tileSlices',
        'platformModules',
      },
    );
    StrictAuthoringJson.requireSchemaVersion(
      root['schemaVersion'],
      prefabSchemaVersionV2,
      sourcePath: '$sourcePath.schemaVersion',
    );

    final tileSlices = StrictAuthoringJson.objectList(
      root['tileSlices'],
      sourcePath: '$sourcePath.tileSlices',
      parse: PolygonAuthoringMetadataCodec.decodeSlice,
    );
    StrictAuthoringJson.requireComparatorOrder(
      tileSlices,
      PrefabDeterminism.compareSlicesByIdThenSourceRect,
      sourcePath: '$sourcePath.tileSlices',
    );
    StrictAuthoringJson.requireUniqueStrings(
      tileSlices.map((slice) => slice.id),
      sourcePath: '$sourcePath.tileSlices.id',
      caseInsensitive: true,
    );

    final modules = StrictAuthoringJson.objectList(
      root['platformModules'],
      sourcePath: '$sourcePath.platformModules',
      parse: _decodeModule,
    );
    StrictAuthoringJson.requireComparatorOrder(
      modules,
      PrefabDeterminism.compareModulesByStatusIdRevision,
      sourcePath: '$sourcePath.platformModules',
    );
    StrictAuthoringJson.requireUniqueStrings(
      modules.map((module) => module.id),
      sourcePath: '$sourcePath.platformModules.id',
      caseInsensitive: true,
    );
    return PrefabTileFileData(tileSlices: tileSlices, platformModules: modules);
  }

  static String encode(PrefabTileFileData data) {
    final tileSlices = PrefabDeterminism.sortSlicesByIdThenSourceRect(
      data.tileSlices.map(
        (slice) =>
            slice.copyWith(tags: PrefabDeterminism.normalizeTags(slice.tags)),
      ),
    );
    final modules = PrefabDeterminism.sortModulesByStatusIdRevision(
      data.platformModules.map(
        (module) => module.copyWith(
          cells: PrefabDeterminism.sortModuleCellsByGridPosition(module.cells),
        ),
      ),
    );
    final encoded = StrictAuthoringJson.encode(<String, Object>{
      'schemaVersion': prefabSchemaVersionV2,
      'tileSlices': tileSlices
          .map((slice) => slice.toJson())
          .toList(growable: false),
      'platformModules': modules
          .map((module) => module.toJson())
          .toList(growable: false),
    });
    decode(encoded);
    return encoded;
  }
}

TileModuleDef _decodeModule(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  StrictAuthoringJson.requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{'id', 'revision', 'status', 'tileSize', 'cells'},
    required: const <String>{'id', 'revision', 'status', 'tileSize', 'cells'},
  );
  final status = StrictAuthoringJson.enumString(json['status'], const <String>{
    'active',
    'deprecated',
  }, sourcePath: '$sourcePath.status');
  final cells = StrictAuthoringJson.objectList(
    json['cells'],
    sourcePath: '$sourcePath.cells',
    parse: _decodeCell,
  );
  StrictAuthoringJson.requireComparatorOrder(
    cells,
    PrefabDeterminism.compareModuleCellsByGridPosition,
    sourcePath: '$sourcePath.cells',
  );
  final occupied = <(int, int)>{};
  for (final cell in cells) {
    if (!occupied.add((cell.gridX, cell.gridY))) {
      throw FormatException(
        '$sourcePath.cells must contain unique grid positions.',
      );
    }
  }
  return TileModuleDef(
    id: StrictAuthoringJson.nonEmptyString(
      json['id'],
      sourcePath: '$sourcePath.id',
    ),
    revision: StrictAuthoringJson.positiveInt(
      json['revision'],
      sourcePath: '$sourcePath.revision',
    ),
    status: parseTileModuleStatus(status),
    tileSize: StrictAuthoringJson.positiveInt(
      json['tileSize'],
      sourcePath: '$sourcePath.tileSize',
    ),
    cells: cells,
  );
}

TileModuleCellDef _decodeCell(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  StrictAuthoringJson.requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{'sliceId', 'gridX', 'gridY'},
    required: const <String>{'sliceId', 'gridX', 'gridY'},
  );
  return TileModuleCellDef(
    sliceId: StrictAuthoringJson.nonEmptyString(
      json['sliceId'],
      sourcePath: '$sourcePath.sliceId',
    ),
    gridX: StrictAuthoringJson.integer(
      json['gridX'],
      sourcePath: '$sourcePath.gridX',
    ),
    gridY: StrictAuthoringJson.integer(
      json['gridY'],
      sourcePath: '$sourcePath.gridY',
    ),
  );
}
