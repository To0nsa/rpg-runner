import 'package:meta/meta.dart';

import 'atlas/atlas_slice_def.dart';
import 'prefab/prefab_v3_def.dart';

/// Immutable in-memory representation of one prefab-schema-v3 source file.
///
/// This record snapshots source order without normalizing it. Strict decoding
/// diagnoses noncanonical files, while the codec owns canonical serialization.
/// It is a read-only staging seam until `PrefabStore` cuts over from v2.
@immutable
final class PrefabV3FileData {
  PrefabV3FileData({
    required Iterable<AtlasSliceDef> slices,
    required Iterable<PrefabV3Def> prefabs,
  }) : slices = List<AtlasSliceDef>.unmodifiable(slices),
       prefabs = List<PrefabV3Def>.unmodifiable(prefabs);

  final List<AtlasSliceDef> slices;
  final List<PrefabV3Def> prefabs;

  PrefabV3FileData copyWith({
    Iterable<AtlasSliceDef>? slices,
    Iterable<PrefabV3Def>? prefabs,
  }) => PrefabV3FileData(
    slices: slices ?? this.slices,
    prefabs: prefabs ?? this.prefabs,
  );
}
