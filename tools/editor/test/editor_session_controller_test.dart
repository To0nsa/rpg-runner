import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test(
    'workspace path changes invalidate loaded session and export uses reloaded path',
    () async {
      final fixtureRoot = await Directory.systemTemp.createTemp(
        'editor_session_controller_',
      );
      addTearDown(() {
        if (fixtureRoot.existsSync()) {
          fixtureRoot.deleteSync(recursive: true);
        }
      });

      final workspaceA = Directory('${fixtureRoot.path}/workspace_a')
        ..createSync(recursive: true);
      final workspaceB = Directory('${fixtureRoot.path}/workspace_b')
        ..createSync(recursive: true);

      final plugin = _RecordingPlugin();
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: <AuthoringDomainPlugin>[plugin],
        ),
        initialPluginId: plugin.id,
        initialWorkspacePath: workspaceA.path,
      );

      await controller.loadWorkspace();
      expect(controller.loadError, isNull);

      await controller.exportDirectWrite();
      expect(plugin.exportWorkspaceRoots, <String>[
        EditorWorkspace(rootPath: workspaceA.path).rootPath,
      ]);

      controller.setWorkspacePath(workspaceB.path);
      expect(controller.workspace, isNull);
      expect(controller.document, isNull);
      expect(controller.scene, isNull);

      await controller.exportDirectWrite();
      expect(plugin.exportWorkspaceRoots, <String>[
        EditorWorkspace(rootPath: workspaceA.path).rootPath,
      ]);

      await controller.loadWorkspace();
      expect(controller.loadError, isNull);
      await controller.exportDirectWrite();
      expect(plugin.exportWorkspaceRoots, <String>[
        EditorWorkspace(rootPath: workspaceA.path).rootPath,
        EditorWorkspace(rootPath: workspaceB.path).rootPath,
      ]);
    },
  );
}

class _RecordingPlugin implements AuthoringDomainPlugin {
  final List<String> exportWorkspaceRoots = <String>[];

  @override
  String get id => 'recording';

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    return document;
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    return const _RecordingScene();
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    return PendingChanges.empty;
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    exportWorkspaceRoots.add(workspace.rootPath);
    return ExportResult(applied: false);
  }

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return const _RecordingDocument();
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return const <ValidationIssue>[];
  }
}

class _RecordingDocument extends AuthoringDocument {
  const _RecordingDocument();
}

class _RecordingScene extends EditableScene {
  const _RecordingScene();
}
