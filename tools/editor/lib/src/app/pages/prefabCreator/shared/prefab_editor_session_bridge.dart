import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../session/editor_session_controller.dart';

class PrefabEditorSessionException implements Exception {
  const PrefabEditorSessionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Narrow controller-facing bridge for prefab editor committed session state.
///
/// The page still owns UI projection and local drafts, but controller mutation
/// and `PrefabScene` retrieval are centralized here so page files do not need
/// to know the session command protocol directly.
class PrefabEditorSessionBridge {
  const PrefabEditorSessionBridge();

  PrefabScene? currentPrefabScene(EditorSessionController controller) {
    final scene = controller.scene;
    return scene is PrefabScene ? scene : null;
  }

  PrefabScene requireCurrentPrefabScene(
    EditorSessionController controller, {
    String missingMessage = 'Prefab scene is not loaded. Reload and try again.',
  }) {
    final scene = currentPrefabScene(controller);
    if (scene == null) {
      throw PrefabEditorSessionException(missingMessage);
    }
    return scene;
  }

  PrefabScene applyPrefabDataChange({
    required EditorSessionController controller,
    required PrefabData nextData,
  }) {
    if (controller.document == null || currentPrefabScene(controller) == null) {
      throw const PrefabEditorSessionException(
        'Reload prefab data before applying edits.',
      );
    }

    controller.applyCommand(
      AuthoringCommand(
        kind: PrefabDomainPlugin.replacePrefabDataCommandKind,
        payload: <String, Object?>{'data': nextData},
      ),
    );
    return requireCurrentPrefabScene(controller);
  }

  PrefabScene? undoCommittedEdit(EditorSessionController controller) {
    if (!controller.canUndo) {
      return null;
    }
    controller.undo();
    return requireCurrentPrefabScene(controller);
  }

  PrefabScene? redoCommittedEdit(EditorSessionController controller) {
    if (!controller.canRedo) {
      return null;
    }
    controller.redo();
    return requireCurrentPrefabScene(controller);
  }
}
