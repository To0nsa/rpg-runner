import 'prefab_models.dart';

/// Canonical normalization and ordering rules for prefab authoring data.
///
/// These helpers are shared by store/reducer paths so serialization stays
/// deterministic for the same semantic content.
class PrefabDeterminism {
  const PrefabDeterminism._();

  /// Trims, drops empty values, de-duplicates, and lexicographically sorts tags.
  static List<String> normalizeTags(List<String> tags) {
    final normalized =
        tags
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return normalized;
  }

  static List<PrefabDef> sortPrefabsByIdThenKey(Iterable<PrefabDef> prefabs) {
    final sorted = List<PrefabDef>.from(prefabs)
      ..sort(comparePrefabsByIdThenKey);
    return sorted;
  }

  /// Total-order comparator for prefabs.
  ///
  /// Starts with user-facing identity (`id`, `prefabKey`) and then falls
  /// through every remaining field so `List.sort` never sees distinct prefabs
  /// as equal.
  static int comparePrefabsByIdThenKey(PrefabDef a, PrefabDef b) {
    final idCompare = a.id.compareTo(b.id);
    if (idCompare != 0) {
      return idCompare;
    }
    final keyCompare = a.prefabKey.compareTo(b.prefabKey);
    if (keyCompare != 0) {
      return keyCompare;
    }

    final revisionCompare = a.revision.compareTo(b.revision);
    if (revisionCompare != 0) {
      return revisionCompare;
    }

    final statusCompare = a.status.index.compareTo(b.status.index);
    if (statusCompare != 0) {
      return statusCompare;
    }

    final kindCompare = a.kind.index.compareTo(b.kind.index);
    if (kindCompare != 0) {
      return kindCompare;
    }

    final sourceCompare = _comparePrefabVisualSource(a.visualSource, b.visualSource);
    if (sourceCompare != 0) {
      return sourceCompare;
    }

    final anchorXCompare = a.anchorXPx.compareTo(b.anchorXPx);
    if (anchorXCompare != 0) {
      return anchorXCompare;
    }

    final anchorYCompare = a.anchorYPx.compareTo(b.anchorYPx);
    if (anchorYCompare != 0) {
      return anchorYCompare;
    }

    final zIndexCompare = a.zIndex.compareTo(b.zIndex);
    if (zIndexCompare != 0) {
      return zIndexCompare;
    }

    final snapToGridCompare = _compareBool(a.snapToGrid, b.snapToGrid);
    if (snapToGridCompare != 0) {
      return snapToGridCompare;
    }

    final tagsCompare = _compareStringLists(a.tags, b.tags);
    if (tagsCompare != 0) {
      return tagsCompare;
    }

    return _compareColliderLists(a.colliders, b.colliders);
  }

  static List<TileModuleDef> sortModulesByStatusIdRevision(
    Iterable<TileModuleDef> modules,
  ) {
    final sorted = List<TileModuleDef>.from(modules)
      ..sort(compareModulesByStatusIdRevision);
    return sorted;
  }

  /// Total-order comparator for modules.
  ///
  /// Status rank keeps active modules first in canonical exports; subsequent
  /// tie-breakers prevent non-deterministic ordering among structurally
  /// different modules.
  static int compareModulesByStatusIdRevision(
    TileModuleDef a,
    TileModuleDef b,
  ) {
    final statusCompare = moduleStatusRank(
      a.status,
    ).compareTo(moduleStatusRank(b.status));
    if (statusCompare != 0) {
      return statusCompare;
    }
    final idCompare = a.id.compareTo(b.id);
    if (idCompare != 0) {
      return idCompare;
    }

    final revisionCompare = a.revision.compareTo(b.revision);
    if (revisionCompare != 0) {
      return revisionCompare;
    }

    final tileSizeCompare = a.tileSize.compareTo(b.tileSize);
    if (tileSizeCompare != 0) {
      return tileSizeCompare;
    }

    return _compareModuleCellLists(a.cells, b.cells);
  }

  /// Defines canonical status ordering for module export and UI defaults.
  static int moduleStatusRank(TileModuleStatus status) {
    switch (status) {
      case TileModuleStatus.active:
        return 0;
      case TileModuleStatus.deprecated:
        return 1;
      case TileModuleStatus.unknown:
        return 2;
    }
  }

  /// Migrates unsupported module status values to the writable default.
  static TileModuleStatus normalizeModuleStatus(TileModuleStatus status) {
    if (status == TileModuleStatus.unknown) {
      return TileModuleStatus.active;
    }
    return status;
  }

  /// Canonical collider ordering for deterministic serialization.
  static List<PrefabColliderDef> sortColliders(
    Iterable<PrefabColliderDef> colliders,
  ) {
    final sorted = List<PrefabColliderDef>.from(colliders)
      ..sort((a, b) {
        final offsetYCompare = a.offsetY.compareTo(b.offsetY);
        if (offsetYCompare != 0) {
          return offsetYCompare;
        }
        final offsetXCompare = a.offsetX.compareTo(b.offsetX);
        if (offsetXCompare != 0) {
          return offsetXCompare;
        }
        final widthCompare = a.width.compareTo(b.width);
        if (widthCompare != 0) {
          return widthCompare;
        }
        return a.height.compareTo(b.height);
      });
    return sorted;
  }

  /// Canonical cell ordering by grid position, then tile slice id.
  static List<TileModuleCellDef> sortModuleCellsByGridThenSlice(
    Iterable<TileModuleCellDef> cells,
  ) {
    final sorted = List<TileModuleCellDef>.from(cells)
      ..sort((a, b) {
        final yCompare = a.gridY.compareTo(b.gridY);
        if (yCompare != 0) {
          return yCompare;
        }
        final xCompare = a.gridX.compareTo(b.gridX);
        if (xCompare != 0) {
          return xCompare;
        }
        return a.sliceId.compareTo(b.sliceId);
      });
    return sorted;
  }

  /// Converts arbitrary text to a prefab-safe key slug.
  ///
  /// Output is lowercase ASCII with `_` separators and no leading/trailing `_`.
  static String slugToPrefabKey(String raw) {
    final lowered = raw.trim().toLowerCase();
    if (lowered.isEmpty) {
      return '';
    }
    final replaced = lowered.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final collapsed = replaced.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// Allocates a unique prefab key derived from [id].
  ///
  /// Collision checks are case-insensitive and trim-aware to avoid near-duplicate
  /// keys such as `Tree` and `tree` coexisting.
  static String allocatePrefabKey({
    required String id,
    required Set<String> usedPrefabKeys,
  }) {
    var base = slugToPrefabKey(id);
    if (base.isEmpty) {
      base = 'prefab';
    }
    final normalizedUsedKeys = usedPrefabKeys
        .map((key) => key.trim().toLowerCase())
        .where((key) => key.isNotEmpty)
        .toSet();
    var candidate = base;
    var suffix = 2;
    while (normalizedUsedKeys.contains(candidate)) {
      candidate = '${base}_$suffix';
      suffix += 1;
    }
    return candidate;
  }

  /// Allocates a duplicate-safe module id in `<source>_copy[_N]` form.
  static String allocateDuplicateModuleId({
    required String sourceId,
    required Set<String> usedModuleIds,
  }) {
    final base = sourceId.trim().isEmpty ? 'module' : sourceId.trim();
    var candidate = '${base}_copy';
    var suffix = 2;
    while (usedModuleIds.contains(candidate)) {
      candidate = '${base}_copy_$suffix';
      suffix += 1;
    }
    return candidate;
  }

  static int _comparePrefabVisualSource(
    PrefabVisualSource a,
    PrefabVisualSource b,
  ) {
    final typeCompare = a.type.index.compareTo(b.type.index);
    if (typeCompare != 0) {
      return typeCompare;
    }
    final sliceCompare = a.sliceId.compareTo(b.sliceId);
    if (sliceCompare != 0) {
      return sliceCompare;
    }
    return a.moduleId.compareTo(b.moduleId);
  }

  static int _compareBool(bool a, bool b) {
    if (a == b) {
      return 0;
    }
    return a ? 1 : -1;
  }

  static int _compareStringLists(List<String> a, List<String> b) {
    final lengthCompare = a.length.compareTo(b.length);
    if (lengthCompare != 0) {
      return lengthCompare;
    }

    for (var i = 0; i < a.length; i += 1) {
      final itemCompare = a[i].compareTo(b[i]);
      if (itemCompare != 0) {
        return itemCompare;
      }
    }
    return 0;
  }

  static int _compareColliderLists(
    List<PrefabColliderDef> a,
    List<PrefabColliderDef> b,
  ) {
    final lengthCompare = a.length.compareTo(b.length);
    if (lengthCompare != 0) {
      return lengthCompare;
    }

    for (var i = 0; i < a.length; i += 1) {
      final colliderCompare = _compareCollider(a[i], b[i]);
      if (colliderCompare != 0) {
        return colliderCompare;
      }
    }
    return 0;
  }

  static int _compareCollider(PrefabColliderDef a, PrefabColliderDef b) {
    final offsetYCompare = a.offsetY.compareTo(b.offsetY);
    if (offsetYCompare != 0) {
      return offsetYCompare;
    }
    final offsetXCompare = a.offsetX.compareTo(b.offsetX);
    if (offsetXCompare != 0) {
      return offsetXCompare;
    }
    final widthCompare = a.width.compareTo(b.width);
    if (widthCompare != 0) {
      return widthCompare;
    }
    return a.height.compareTo(b.height);
  }

  static int _compareModuleCellLists(
    List<TileModuleCellDef> a,
    List<TileModuleCellDef> b,
  ) {
    final lengthCompare = a.length.compareTo(b.length);
    if (lengthCompare != 0) {
      return lengthCompare;
    }

    for (var i = 0; i < a.length; i += 1) {
      final cellCompare = _compareModuleCell(a[i], b[i]);
      if (cellCompare != 0) {
        return cellCompare;
      }
    }
    return 0;
  }

  static int _compareModuleCell(TileModuleCellDef a, TileModuleCellDef b) {
    final yCompare = a.gridY.compareTo(b.gridY);
    if (yCompare != 0) {
      return yCompare;
    }
    final xCompare = a.gridX.compareTo(b.gridX);
    if (xCompare != 0) {
      return xCompare;
    }
    return a.sliceId.compareTo(b.sliceId);
  }
}
