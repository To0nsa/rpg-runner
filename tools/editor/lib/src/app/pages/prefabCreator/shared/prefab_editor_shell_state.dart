import '../../../../prefabs/models/models.dart';
import '../atlas_slicer/atlas_slicer_controller.dart';
import '../platform_modules/widgets/platform_module_scene_view.dart';

/// Mutable page-shell state projected over the prefab editor workflows.
///
/// This is intentionally narrow and page-scoped: it keeps route-level view
/// state in one place so coordinators can collaborate without a long list of
/// read/write closures.
class PrefabEditorShellState {
  PrefabData data = const PrefabData();
  List<String> atlasImagePaths = const <String>[];

  bool isLoading = false;
  bool isSaving = false;
  String? statusMessage;
  String? errorMessage;

  AtlasSlicerState atlasState = const AtlasSlicerState();
  String? selectedPrefabSliceId;
  String? selectedPrefabPlatformModuleId;
  String? selectedTileSliceId;
  String? selectedModuleId;
  PlatformModuleSceneTool selectedModuleSceneTool =
      PlatformModuleSceneTool.paint;
  int activeTabIndex = 0;

  bool get canReload => !isLoading && !isSaving;

  void setError(String message) {
    errorMessage = message;
    statusMessage = null;
  }
}
