import 'package:meta/meta.dart';

import 'atlas/atlas_slice_def.dart';
import 'platform/tile_module_def.dart';

/// Immutable top-level payload for retained `tile_defs.json` schema v2.
///
/// Prefab collision source moves to prefab schema v3, while tile slices and
/// platform modules remain in their existing file. This record lets the v3
/// current loader consume that file without routing through rectangle-era
/// [PrefabData].
@immutable
final class PrefabTileFileData {
  PrefabTileFileData({
    required Iterable<AtlasSliceDef> tileSlices,
    required Iterable<TileModuleDef> platformModules,
  }) : tileSlices = List<AtlasSliceDef>.unmodifiable(tileSlices),
       platformModules = List<TileModuleDef>.unmodifiable(platformModules);

  final List<AtlasSliceDef> tileSlices;
  final List<TileModuleDef> platformModules;

  PrefabTileFileData copyWith({
    Iterable<AtlasSliceDef>? tileSlices,
    Iterable<TileModuleDef>? platformModules,
  }) => PrefabTileFileData(
    tileSlices: tileSlices ?? this.tileSlices,
    platformModules: platformModules ?? this.platformModules,
  );
}
