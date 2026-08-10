/// Legacy schema version that predates explicit prefab status/kind/source
/// contracts and tile module revisions.
const int prefabSchemaVersionV1 = 1;

/// Rectangle-era prefab schema; still current for retained tile data.
const int prefabSchemaVersionV2 = 2;

/// Current polygon-collision prefab schema.
const int prefabSchemaVersionV3 = 3;

const int currentPrefabSchemaVersion = prefabSchemaVersionV3;
