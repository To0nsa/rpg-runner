import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/prefabs/store/prefab_tile_file_codec.dart';

void main() {
  test('current repository tile source strictly round-trips byte for byte', () {
    final source = File(
      p.normalize(
        p.join(Directory.current.path, '..', '..', PrefabStore.tileDefsPath),
      ),
    ).readAsStringSync();

    final decoded = PrefabTileFileCodec.decode(source);

    expect(decoded.tileSlices, isNotEmpty);
    expect(decoded.platformModules, isNotEmpty);
    expect(PrefabTileFileCodec.encode(decoded), source);
  });

  test('codec canonicalizes copied module cells and tags only on encode', () {
    final source = _data(
      tags: const <String>['z', 'a', 'a'],
      cells: const <TileModuleCellDef>[
        TileModuleCellDef(sliceId: 'slice_b', gridX: 1, gridY: 0),
        TileModuleCellDef(sliceId: 'slice_a', gridX: 0, gridY: 0),
      ],
    );

    final encoded = PrefabTileFileCodec.encode(source);
    final decoded = PrefabTileFileCodec.decode(encoded);

    expect(source.tileSlices.first.tags, const <String>['z', 'a', 'a']);
    expect(source.platformModules.single.cells.first.sliceId, 'slice_b');
    expect(decoded.tileSlices.first.tags, const <String>['a', 'z']);
    expect(
      decoded.platformModules.single.cells.map((cell) => cell.sliceId),
      const <String>['slice_a', 'slice_b'],
    );
    expect(PrefabTileFileCodec.encode(decoded), encoded);
  });

  test('strict decode rejects unknown, mistyped, and noncanonical source', () {
    final canonical =
        jsonDecode(PrefabTileFileCodec.encode(_data())) as Map<String, Object?>;

    final unknown = Map<String, Object?>.from(canonical)..['unknown'] = true;
    expect(
      () => PrefabTileFileCodec.decode(jsonEncode(unknown)),
      throwsFormatException,
    );

    final mistyped = _deepCopy(canonical);
    final modules = mistyped['platformModules']! as List<Object?>;
    (modules.single as Map<String, Object?>)['tileSize'] = 16.5;
    expect(
      () => PrefabTileFileCodec.decode(jsonEncode(mistyped)),
      throwsFormatException,
    );

    final noncanonical = _deepCopy(canonical);
    final cells =
        ((noncanonical['platformModules']! as List<Object?>).single
                as Map<String, Object?>)['cells']!
            as List<Object?>;
    cells.add(<String, Object?>{'sliceId': 'slice_b', 'gridX': 1, 'gridY': -1});
    expect(
      () => PrefabTileFileCodec.decode(jsonEncode(noncanonical)),
      throwsFormatException,
    );
  });

  test('duplicate module identities and grid positions fail closed', () {
    final duplicatePosition = _data(
      cells: const <TileModuleCellDef>[
        TileModuleCellDef(sliceId: 'slice_a', gridX: 0, gridY: 0),
        TileModuleCellDef(sliceId: 'slice_b', gridX: 0, gridY: 0),
      ],
    );
    expect(
      () => PrefabTileFileCodec.encode(duplicatePosition),
      throwsFormatException,
    );

    final module = duplicatePosition.platformModules.single.copyWith(
      cells: const <TileModuleCellDef>[
        TileModuleCellDef(sliceId: 'slice_a', gridX: 0, gridY: 0),
      ],
    );
    final duplicateModule = duplicatePosition.copyWith(
      platformModules: <TileModuleDef>[
        module,
        module.copyWith(id: module.id.toUpperCase()),
      ],
    );
    expect(
      () => PrefabTileFileCodec.encode(duplicateModule),
      throwsFormatException,
    );
  });
}

PrefabTileFileData _data({
  List<String> tags = const <String>[],
  List<TileModuleCellDef> cells = const <TileModuleCellDef>[
    TileModuleCellDef(sliceId: 'slice_a', gridX: 0, gridY: 0),
  ],
}) => PrefabTileFileData(
  tileSlices: <AtlasSliceDef>[
    AtlasSliceDef(
      id: 'slice_a',
      sourceImagePath: 'assets/images/a.png',
      x: 0,
      y: 0,
      width: 16,
      height: 16,
      tags: tags,
    ),
    const AtlasSliceDef(
      id: 'slice_b',
      sourceImagePath: 'assets/images/a.png',
      x: 16,
      y: 0,
      width: 16,
      height: 16,
    ),
  ],
  platformModules: <TileModuleDef>[
    TileModuleDef(
      id: 'module_a',
      revision: 1,
      status: TileModuleStatus.active,
      tileSize: 16,
      cells: cells,
    ),
  ],
);

Map<String, Object?> _deepCopy(Map<String, Object?> source) =>
    jsonDecode(jsonEncode(source)) as Map<String, Object?>;
