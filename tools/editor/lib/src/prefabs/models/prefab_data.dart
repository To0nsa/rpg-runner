import 'package:flutter/foundation.dart';

import 'atlas/atlas_slice_def.dart';
import 'platform/tile_module_def.dart';
import 'prefab/prefab_def.dart';
import 'shared/prefab_schema.dart';

/// In-memory prefab authoring document payload.
///
/// This type is the semantic source used by UI/plugin logic before being
/// serialized into `prefab_defs.json` and `tile_defs.json`.
@immutable
class PrefabData {
  const PrefabData({
    this.schemaVersion = currentPrefabSchemaVersion,
    this.prefabSlices = const <AtlasSliceDef>[],
    this.tileSlices = const <AtlasSliceDef>[],
    this.prefabs = const <PrefabDef>[],
    this.platformModules = const <TileModuleDef>[],
  });

  final int schemaVersion;
  final List<AtlasSliceDef> prefabSlices;
  final List<AtlasSliceDef> tileSlices;
  final List<PrefabDef> prefabs;
  final List<TileModuleDef> platformModules;

  PrefabData copyWith({
    int? schemaVersion,
    List<AtlasSliceDef>? prefabSlices,
    List<AtlasSliceDef>? tileSlices,
    List<PrefabDef>? prefabs,
    List<TileModuleDef>? platformModules,
  }) {
    return PrefabData(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      prefabSlices: prefabSlices ?? this.prefabSlices,
      tileSlices: tileSlices ?? this.tileSlices,
      prefabs: prefabs ?? this.prefabs,
      platformModules: platformModules ?? this.platformModules,
    );
  }
}
