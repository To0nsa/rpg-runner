import '../chunks/chunk_v2_models.dart';
import '../parallax/parallax_domain_models.dart';
import '../prefabs/domain/prefab_domain_models.dart';
import '../terrain_materials/terrain_material_domain_models.dart';
import 'authoring_types.dart';

/// A repair route needs complete editable source, rather than a partially
/// decoded or migration-only document. Runtime/value/image findings remain
/// repairable; only source-loading failures prevent suspension of the origin.
bool isDependencyRepairSourceReadable(AuthoringDocument? document) =>
    switch (document) {
      // These normal documents exist only after strict current-schema decoding.
      ChunkV2Document() || PrefabV3Document() => true,
      ParallaxDefsDocument() =>
        document.baseline != null &&
            !document.loadIssues.any(
              (issue) => issue.blocks(AuthoringOperation.save),
            ),
      TerrainMaterialDocument() =>
        document.baseline != null &&
            !document.loadIssues.any(
              (issue) => issue.blocks(AuthoringOperation.save),
            ),
      _ => false,
    };
