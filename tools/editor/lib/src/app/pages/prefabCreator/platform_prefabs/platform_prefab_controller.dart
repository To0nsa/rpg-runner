import 'package:flutter/foundation.dart';

import '../../../../prefabs/models/models.dart';
import '../shared/prefab_editor_data_reducer.dart';
import '../shared/prefab_editor_mutations.dart';
import '../shared/prefab_editor_prefab_controller.dart';

/// Platform-prefab-specific domain rules that sit between generic prefab
/// editing and module-backed prefab output.
class PlatformPrefabController {
  const PlatformPrefabController({
    PrefabEditorMutations mutations = const PrefabEditorMutations(),
  }) : _mutations = mutations;

  final PrefabEditorMutations _mutations;

  PrefabEditorDecision<PrefabVisualSource> resolveVisualSource({
    required bool autoManagePlatformModule,
    required String? selectedPlatformModuleId,
    String? moduleIdOverride,
  }) {
    final moduleId = moduleIdOverride ?? selectedPlatformModuleId;
    if (moduleId == null || moduleId.isEmpty) {
      return PrefabEditorDecision.error(
        autoManagePlatformModule
            ? 'Initialize backing module before saving platform prefab.'
            : 'Select a platform module for platform prefab source.',
      );
    }
    return PrefabEditorDecision.success(
      PrefabVisualSource.platformModule(moduleId),
    );
  }

  PrefabEditorDecision<PlatformAutoManagedModuleResult>
  ensureAutoManagedPlatformModule({
    required PrefabData data,
    required String prefabKey,
    required String rawTileSize,
    required PrefabEditorDataReducer reducer,
  }) {
    final tileSize = int.tryParse(rawTileSize.trim());
    if (tileSize == null || tileSize <= 0) {
      return const PrefabEditorDecision.error(
        'Platform tile size must be a positive integer.',
      );
    }

    final moduleId = reducer.autoManagedModuleIdForPrefabKey(prefabKey);
    TileModuleDef? previous;
    for (final module in data.platformModules) {
      if (module.id == moduleId) {
        previous = module;
        break;
      }
    }
    final nextModule = _buildAutoManagedModule(
      previous: previous,
      moduleId: moduleId,
      tileSize: tileSize,
    );
    if (previous == null ||
        reducer.didModulePayloadChange(previous, nextModule)) {
      return PrefabEditorDecision.success(
        PlatformAutoManagedModuleResult(
          data: _mutations.upsertModule(data: data, module: nextModule),
          module: nextModule,
        ),
      );
    }

    return PrefabEditorDecision.success(
      PlatformAutoManagedModuleResult(data: data, module: previous),
    );
  }

  TileModuleDef _buildAutoManagedModule({
    required TileModuleDef? previous,
    required String moduleId,
    required int tileSize,
  }) {
    if (previous == null) {
      return TileModuleDef(
        id: moduleId,
        revision: 1,
        status: TileModuleStatus.active,
        tileSize: tileSize,
        cells: const <TileModuleCellDef>[],
      );
    }

    var next = previous;
    if (previous.status != TileModuleStatus.active) {
      next = next.copyWith(
        status: TileModuleStatus.active,
        revision: next.revision + 1,
      );
    }
    if (next.tileSize != tileSize) {
      next = next.copyWith(tileSize: tileSize, revision: next.revision + 1);
    }
    return next;
  }
}

@immutable
class PlatformAutoManagedModuleResult {
  const PlatformAutoManagedModuleResult({
    required this.data,
    required this.module,
  });

  final PrefabData data;
  final TileModuleDef module;
}
