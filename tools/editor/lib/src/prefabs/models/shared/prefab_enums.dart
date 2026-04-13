/// Gameplay-facing prefab role used by authoring validation and UI filtering.
enum PrefabKind { obstacle, platform, decoration, unknown }

/// Lifecycle status for prefabs authored in `prefab_defs.json`.
enum PrefabStatus { active, deprecated, unknown }

/// Lifecycle status for tile/platform modules authored in `tile_defs.json`.
enum TileModuleStatus { active, deprecated, unknown }

/// Discriminator for prefab visual source references.
enum PrefabVisualSourceType { atlasSlice, platformModule, unknown }

/// Parses persisted prefab kind strings.
///
/// Unknown values are preserved as [PrefabKind.unknown] so validation can
/// surface a precise blocking error instead of silently defaulting.
PrefabKind parsePrefabKind(String raw) {
  switch (raw.trim()) {
    case 'obstacle':
      return PrefabKind.obstacle;
    case 'platform':
      return PrefabKind.platform;
    case 'decoration':
      return PrefabKind.decoration;
    default:
      return PrefabKind.unknown;
  }
}

/// Parses persisted prefab status strings, preserving unsupported values as
/// [PrefabStatus.unknown] for explicit validation.
PrefabStatus parsePrefabStatus(String raw) {
  switch (raw.trim()) {
    case 'active':
      return PrefabStatus.active;
    case 'deprecated':
      return PrefabStatus.deprecated;
    default:
      return PrefabStatus.unknown;
  }
}

/// Parses persisted tile module status strings, preserving unsupported values
/// as [TileModuleStatus.unknown] for explicit validation.
TileModuleStatus parseTileModuleStatus(String raw) {
  switch (raw.trim()) {
    case 'active':
      return TileModuleStatus.active;
    case 'deprecated':
      return TileModuleStatus.deprecated;
    default:
      return TileModuleStatus.unknown;
  }
}

/// Parses persisted visual source type strings for prefab source references.
PrefabVisualSourceType parsePrefabVisualSourceType(String raw) {
  switch (raw.trim()) {
    case 'atlas_slice':
      return PrefabVisualSourceType.atlasSlice;
    case 'platform_module':
      return PrefabVisualSourceType.platformModule;
    default:
      return PrefabVisualSourceType.unknown;
  }
}

/// Stable JSON encoding for [PrefabKind].
extension PrefabKindJson on PrefabKind {
  String get jsonValue {
    switch (this) {
      case PrefabKind.obstacle:
        return 'obstacle';
      case PrefabKind.platform:
        return 'platform';
      case PrefabKind.decoration:
        return 'decoration';
      case PrefabKind.unknown:
        return 'unknown';
    }
  }
}

/// Stable JSON encoding for [PrefabStatus].
extension PrefabStatusJson on PrefabStatus {
  String get jsonValue {
    switch (this) {
      case PrefabStatus.active:
        return 'active';
      case PrefabStatus.deprecated:
        return 'deprecated';
      case PrefabStatus.unknown:
        return 'unknown';
    }
  }
}

/// Stable JSON encoding for [TileModuleStatus].
extension TileModuleStatusJson on TileModuleStatus {
  String get jsonValue {
    switch (this) {
      case TileModuleStatus.active:
        return 'active';
      case TileModuleStatus.deprecated:
        return 'deprecated';
      case TileModuleStatus.unknown:
        return 'unknown';
    }
  }
}

/// Stable JSON encoding for [PrefabVisualSourceType].
extension PrefabVisualSourceTypeJson on PrefabVisualSourceType {
  String get jsonValue {
    switch (this) {
      case PrefabVisualSourceType.atlasSlice:
        return 'atlas_slice';
      case PrefabVisualSourceType.platformModule:
        return 'platform_module';
      case PrefabVisualSourceType.unknown:
        return 'unknown';
    }
  }
}
