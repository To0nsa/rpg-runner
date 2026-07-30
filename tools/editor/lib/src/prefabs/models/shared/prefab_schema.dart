/// Legacy schema version that predates explicit prefab status/kind/source
/// contracts and tile module revisions.
const int prefabSchemaVersionV1 = 1;

/// Current schema introduced by the prefab/tile split and richer metadata.
const int prefabSchemaVersionV2 = 2;

/// Polygon-collision prefab schema staged for the Phase 4 source cutover.
const int prefabSchemaVersionV3 = 3;

/// Rectangle-era writes remain authoritative until the single source cutover.
const int currentPrefabSchemaVersion = prefabSchemaVersionV2;
