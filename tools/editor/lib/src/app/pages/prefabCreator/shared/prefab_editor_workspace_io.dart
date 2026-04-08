import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/atlas/workspace_scoped_size_cache.dart';
import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/validation/prefab_validation.dart';
import '../../../../session/editor_session_controller.dart';

class PrefabEditorWorkspaceLoadResult {
  const PrefabEditorWorkspaceLoadResult({
    required this.scene,
    required this.atlasImagePaths,
    required this.selectedAtlasPath,
  });

  final PrefabScene scene;
  final List<String> atlasImagePaths;
  final String? selectedAtlasPath;
}

class PrefabEditorValidationException implements Exception {
  const PrefabEditorValidationException(this.errors);

  final List<String> errors;
}

/// Repository/workspace I/O for prefab authoring data.
///
/// This owns workspace reload/save mechanics plus atlas image discovery and
/// size caching so page state code stays focused on UI/session projection.
class PrefabEditorWorkspaceIo {
  const PrefabEditorWorkspaceIo();

  Future<PrefabEditorWorkspaceLoadResult> load({
    required EditorSessionController controller,
    required WorkspaceScopedSizeCache atlasImageSizes,
    required String workspacePath,
    required String? previousAtlasSelection,
    required String levelAssetsPath,
  }) async {
    atlasImageSizes.ensureWorkspace(workspacePath);

    await controller.loadWorkspace();
    final loadError = controller.loadError;
    if (loadError != null) {
      throw StateError(loadError);
    }

    final scene = controller.scene;
    if (scene is! PrefabScene) {
      throw StateError(
        'Prefab scene is not loaded. Active plugin must be "${PrefabDomainPlugin.pluginId}".',
      );
    }

    final atlasPaths = scene.atlasImagePaths.isEmpty
        ? _discoverAtlasImages(
            workspacePath: workspacePath,
            levelAssetsPath: levelAssetsPath,
          )
        : scene.atlasImagePaths;
    final selectedAtlasPath = resolveSelectedAtlas(
      previousSelection: previousAtlasSelection,
      available: atlasPaths,
    );

    for (final entry in scene.atlasImageSizes.entries) {
      atlasImageSizes[entry.key] = entry.value;
    }
    for (final atlasPath in atlasPaths) {
      await _ensureAtlasSizeLoaded(
        workspacePath: workspacePath,
        atlasRelativePath: atlasPath,
        atlasImageSizes: atlasImageSizes,
      );
    }

    return PrefabEditorWorkspaceLoadResult(
      scene: scene,
      atlasImagePaths: atlasPaths,
      selectedAtlasPath: selectedAtlasPath,
    );
  }

  Future<void> save({
    required EditorSessionController controller,
    required WorkspaceScopedSizeCache atlasImageSizes,
    required PrefabData data,
    required String workspacePath,
  }) async {
    atlasImageSizes.ensureWorkspace(workspacePath);

    if (controller.document == null || controller.workspace == null) {
      await controller.loadWorkspace();
    }
    final loadError = controller.loadError;
    if (loadError != null) {
      throw StateError(loadError);
    }

    await _ensureSliceAtlasSizesLoaded(
      workspacePath: workspacePath,
      data: data,
      atlasImageSizes: atlasImageSizes,
    );

    final validationErrors = validateBeforeSave(
      data: data,
      atlasImageSizes: atlasImageSizes,
    );
    if (validationErrors.isNotEmpty) {
      throw PrefabEditorValidationException(validationErrors);
    }

    controller.applyCommand(
      AuthoringCommand(
        kind: PrefabDomainPlugin.replacePrefabDataCommandKind,
        payload: <String, Object?>{'data': data},
      ),
    );
    await controller.exportDirectWrite();

    final exportError = controller.exportError;
    if (exportError != null) {
      throw StateError(exportError);
    }
  }

  List<String> validateBeforeSave({
    required PrefabData data,
    required WorkspaceScopedSizeCache atlasImageSizes,
  }) {
    final issues = validatePrefabDataIssues(
      data: data,
      atlasImageSizes: atlasImageSizes.snapshot(),
    );
    return issues
        .map((issue) => '[${issue.code}] ${issue.message}')
        .toList(growable: false);
  }

  static String? resolveSelectedAtlas({
    required String? previousSelection,
    required List<String> available,
  }) {
    if (previousSelection != null && available.contains(previousSelection)) {
      return previousSelection;
    }
    if (available.isEmpty) {
      return null;
    }
    return available.first;
  }

  Future<void> _ensureSliceAtlasSizesLoaded({
    required String workspacePath,
    required PrefabData data,
    required WorkspaceScopedSizeCache atlasImageSizes,
  }) async {
    final sourcePaths = <String>{};
    for (final slice in data.prefabSlices) {
      final sourcePath = slice.sourceImagePath.trim();
      if (sourcePath.isNotEmpty) {
        sourcePaths.add(sourcePath);
      }
    }
    for (final slice in data.tileSlices) {
      final sourcePath = slice.sourceImagePath.trim();
      if (sourcePath.isNotEmpty) {
        sourcePaths.add(sourcePath);
      }
    }
    for (final sourcePath in sourcePaths) {
      await _ensureAtlasSizeLoaded(
        workspacePath: workspacePath,
        atlasRelativePath: sourcePath,
        atlasImageSizes: atlasImageSizes,
      );
    }
  }

  List<String> _discoverAtlasImages({
    required String workspacePath,
    required String levelAssetsPath,
  }) {
    final levelAssets = Directory(p.join(workspacePath, levelAssetsPath));
    if (!levelAssets.existsSync()) {
      return const <String>[];
    }

    final pngPaths = <String>[];
    for (final entity in levelAssets.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.png') {
        continue;
      }
      final relative = p.normalize(
        p.relative(entity.path, from: workspacePath),
      );
      pngPaths.add(relative.replaceAll('\\', '/'));
    }
    pngPaths.sort();
    return pngPaths;
  }

  Future<void> _ensureAtlasSizeLoaded({
    required String workspacePath,
    required String atlasRelativePath,
    required WorkspaceScopedSizeCache atlasImageSizes,
  }) async {
    atlasImageSizes.ensureWorkspace(workspacePath);
    if (atlasImageSizes.containsKey(atlasRelativePath)) {
      return;
    }

    final absolute = p.normalize(p.join(workspacePath, atlasRelativePath));
    final file = File(absolute);
    if (!file.existsSync()) {
      return;
    }

    final bytes = await file.readAsBytes();
    final image = await _decodeImage(bytes);
    atlasImageSizes[atlasRelativePath] = ui.Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    image.dispose();
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }
}
