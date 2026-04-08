import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_store.dart';
import 'prefab_editor_data_reducer.dart';
import 'prefab_editor_workspace_io.dart';

class PrefabEditorLoadedDataProjection {
  const PrefabEditorLoadedDataProjection({
    required this.data,
    required this.atlasImagePaths,
    required this.selectedAtlasPath,
    required this.selectedPrefabSliceId,
    required this.selectedTileSliceId,
    required this.selectedModuleId,
    required this.defaultPlatformModuleId,
    required this.defaultPlatformTileSize,
  });

  final PrefabData data;
  final List<String> atlasImagePaths;
  final String? selectedAtlasPath;
  final String? selectedPrefabSliceId;
  final String? selectedTileSliceId;
  final String? selectedModuleId;
  final String? defaultPlatformModuleId;
  final int defaultPlatformTileSize;
}

class PrefabEditorSceneProjection {
  const PrefabEditorSceneProjection({
    required this.data,
    required this.atlasImagePaths,
    required this.selectedAtlasPath,
    required this.selectedPrefabSliceId,
    required this.selectedTileSliceId,
    required this.selectedModuleId,
    required this.selectedPrefabPlatformModuleId,
  });

  final PrefabData data;
  final List<String> atlasImagePaths;
  final String? selectedAtlasPath;
  final String? selectedPrefabSliceId;
  final String? selectedTileSliceId;
  final String? selectedModuleId;
  final String? selectedPrefabPlatformModuleId;
}

/// Projects plugin-owned prefab scenes into page selection/default state.
///
/// This keeps deterministic picker/defaulting rules in one place so reload and
/// controller-scene sync do not each carry their own module/slice resolution.
class PrefabEditorSceneProjectionHelper {
  const PrefabEditorSceneProjectionHelper({
    PrefabEditorDataReducer reducer = const PrefabEditorDataReducer(),
    PrefabStore prefabStore = const PrefabStore(),
  }) : _reducer = reducer,
       _prefabStore = prefabStore;

  final PrefabEditorDataReducer _reducer;
  final PrefabStore _prefabStore;

  PrefabEditorLoadedDataProjection projectLoadedData({
    required PrefabData data,
    required List<String> atlasImagePaths,
    required String? selectedAtlasPath,
  }) {
    final defaultPlatformModuleId = _reducer.preferredModuleIdForPicker(
      data.platformModules,
    );
    var defaultPlatformTileSize = 16;
    if (defaultPlatformModuleId != null) {
      for (final module in data.platformModules) {
        if (module.id == defaultPlatformModuleId) {
          defaultPlatformTileSize = module.tileSize;
          break;
        }
      }
    }

    return PrefabEditorLoadedDataProjection(
      data: data,
      atlasImagePaths: atlasImagePaths,
      selectedAtlasPath: selectedAtlasPath,
      selectedPrefabSliceId: _resolveAtlasSliceSelection(
        currentSelection: null,
        slices: data.prefabSlices,
      ),
      selectedTileSliceId: _resolveAtlasSliceSelection(
        currentSelection: null,
        slices: data.tileSlices,
      ),
      selectedModuleId: defaultPlatformModuleId,
      defaultPlatformModuleId: defaultPlatformModuleId,
      defaultPlatformTileSize: defaultPlatformTileSize,
    );
  }

  PrefabEditorSceneProjection projectScene({
    required PrefabScene scene,
    required String? currentAtlasSelection,
    required String? currentPrefabSliceSelection,
    required String? currentTileSliceSelection,
    required String? currentModuleSelection,
    required String? currentPrefabPlatformModuleSelection,
  }) {
    final data = scene.data;
    final preferredModuleId = _reducer.preferredModuleIdForPicker(
      data.platformModules,
    );

    return PrefabEditorSceneProjection(
      data: data,
      atlasImagePaths: scene.atlasImagePaths,
      selectedAtlasPath: PrefabEditorWorkspaceIo.resolveSelectedAtlas(
        previousSelection: currentAtlasSelection,
        available: scene.atlasImagePaths,
      ),
      selectedPrefabSliceId: _resolveAtlasSliceSelection(
        currentSelection: currentPrefabSliceSelection,
        slices: data.prefabSlices,
      ),
      selectedTileSliceId: _resolveAtlasSliceSelection(
        currentSelection: currentTileSliceSelection,
        slices: data.tileSlices,
      ),
      selectedModuleId: _resolveModuleSelection(
        currentSelection: currentModuleSelection,
        fallbackSelection: preferredModuleId,
        modules: data.platformModules,
      ),
      selectedPrefabPlatformModuleId: _resolveModuleSelection(
        currentSelection: currentPrefabPlatformModuleSelection,
        fallbackSelection: preferredModuleId,
        modules: data.platformModules,
      ),
    );
  }

  bool hasSerializedDataChanges({
    required PrefabData currentData,
    required PrefabScene baselineScene,
  }) {
    final current = _prefabStore.serializeCanonicalFiles(currentData);
    final baseline = _prefabStore.serializeCanonicalFiles(baselineScene.data);
    return current.prefabContents != baseline.prefabContents ||
        current.tileContents != baseline.tileContents;
  }

  String? _resolveAtlasSliceSelection({
    required String? currentSelection,
    required List<AtlasSliceDef> slices,
  }) {
    if (currentSelection != null &&
        slices.any((slice) => slice.id == currentSelection)) {
      return currentSelection;
    }
    if (slices.isEmpty) {
      return null;
    }
    return slices.first.id;
  }

  String? _resolveModuleSelection({
    required String? currentSelection,
    required String? fallbackSelection,
    required List<TileModuleDef> modules,
  }) {
    if (currentSelection != null &&
        modules.any((module) => module.id == currentSelection)) {
      return currentSelection;
    }
    return fallbackSelection;
  }
}
