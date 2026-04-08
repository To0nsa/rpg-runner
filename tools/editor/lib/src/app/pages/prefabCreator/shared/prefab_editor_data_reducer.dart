import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_determinism.dart';

class PrefabEditorDataReducer {
  const PrefabEditorDataReducer();

  List<String> normalizedTags(List<String> tags) {
    return PrefabDeterminism.normalizeTags(tags);
  }

  bool didPrefabPayloadChange(PrefabDef previous, PrefabDef next) {
    if (previous.kind != next.kind) {
      return true;
    }
    if (previous.visualSource.type != next.visualSource.type) {
      return true;
    }
    if (previous.sourceRefId != next.sourceRefId) {
      return true;
    }
    if (previous.anchorXPx != next.anchorXPx ||
        previous.anchorYPx != next.anchorYPx) {
      return true;
    }
    if (previous.zIndex != next.zIndex ||
        previous.snapToGrid != next.snapToGrid) {
      return true;
    }
    if (previous.status != next.status) {
      return true;
    }
    if (!_stringListsEqual(previous.tags, next.tags)) {
      return true;
    }
    if (!_collidersEqual(previous.colliders, next.colliders)) {
      return true;
    }
    return false;
  }

  bool didModulePayloadChange(TileModuleDef previous, TileModuleDef next) {
    if (previous.tileSize != next.tileSize) {
      return true;
    }
    if (previous.status != next.status) {
      return true;
    }
    if (previous.cells.length != next.cells.length) {
      return true;
    }
    for (var i = 0; i < previous.cells.length; i += 1) {
      final a = previous.cells[i];
      final b = next.cells[i];
      if (a.sliceId != b.sliceId || a.gridX != b.gridX || a.gridY != b.gridY) {
        return true;
      }
    }
    return false;
  }

  List<PrefabDef> sortedPrefabsForUi(List<PrefabDef> prefabs) {
    return PrefabDeterminism.sortPrefabsByIdThenKey(prefabs);
  }

  List<TileModuleDef> sortedModulesForUi(List<TileModuleDef> modules) {
    return PrefabDeterminism.sortModulesByStatusIdRevision(modules);
  }

  String? preferredModuleIdForPicker(List<TileModuleDef> modules) {
    if (modules.isEmpty) {
      return null;
    }
    for (final module in modules) {
      if (module.status != TileModuleStatus.deprecated) {
        return module.id;
      }
    }
    return modules.first.id;
  }

  String allocatePrefabKeyForId(PrefabData data, String id) {
    final used = <String>{};
    for (final prefab in data.prefabs) {
      final key = prefab.prefabKey.trim();
      if (key.isEmpty) {
        continue;
      }
      used.add(key);
    }

    return PrefabDeterminism.allocatePrefabKey(id: id, usedPrefabKeys: used);
  }

  String allocateModuleIdForDuplicate(PrefabData data, String sourceId) {
    final used = data.platformModules
        .map((module) => module.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    return PrefabDeterminism.allocateDuplicateModuleId(
      sourceId: sourceId,
      usedModuleIds: used,
    );
  }

  String autoManagedModuleIdForPrefabKey(String prefabKey) {
    return 'vm_$prefabKey';
  }

  bool isAutoManagedModuleForPrefab({
    required String prefabKey,
    required String moduleId,
  }) {
    return moduleId == autoManagedModuleIdForPrefabKey(prefabKey);
  }

  PrefabDef? firstPlatformPrefabForModuleId(
    List<PrefabDef> prefabs,
    String moduleId,
  ) {
    PrefabDef? fallback;
    for (final prefab in prefabs) {
      if (prefab.kind != PrefabKind.platform ||
          !prefab.usesPlatformModule ||
          prefab.moduleId != moduleId) {
        continue;
      }
      if (prefab.status != PrefabStatus.deprecated) {
        return prefab;
      }
      fallback ??= prefab;
    }
    return fallback;
  }

  List<PrefabDef> rewritePrefabsForModuleRename({
    required List<PrefabDef> prefabs,
    required String fromModuleId,
    required String toModuleId,
  }) {
    final rewritten = prefabs
        .map((prefab) {
          if (!prefab.usesPlatformModule || prefab.moduleId != fromModuleId) {
            return prefab;
          }
          return prefab.copyWith(
            visualSource: PrefabVisualSource.platformModule(toModuleId),
            revision: prefab.revision + 1,
          );
        })
        .toList(growable: false);
    return sortedPrefabsForUi(rewritten);
  }

  bool _collidersEqual(List<PrefabColliderDef> a, List<PrefabColliderDef> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i += 1) {
      if (a[i].offsetX != b[i].offsetX ||
          a[i].offsetY != b[i].offsetY ||
          a[i].width != b[i].width ||
          a[i].height != b[i].height) {
        return false;
      }
    }
    return true;
  }

  bool _stringListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i += 1) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
