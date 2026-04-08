/// Legacy schema version that predates explicit prefab status/kind/source
/// contracts and tile module revisions.
const int prefabSchemaVersionV1 = 1;

/// Current schema introduced by the prefab/tile split and richer metadata.
const int prefabSchemaVersionV2 = 2;

/// Writes always target this version; older versions are migrated on load.
const int currentPrefabSchemaVersion = prefabSchemaVersionV2;
