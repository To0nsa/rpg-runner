import 'dart:io';

import 'package:flutter/foundation.dart';
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

  test('failed reload clears previously loaded session state', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'editor_session_controller_fail_',
    );
    final previousOnError = FlutterError.onError;
    final reportedErrors = <FlutterErrorDetails>[];
    addTearDown(() {
      FlutterError.onError = previousOnError;
      if (fixtureRoot.existsSync()) {
        fixtureRoot.deleteSync(recursive: true);
      }
    });
    FlutterError.onError = reportedErrors.add;

    final plugin = _RecordingPlugin();
    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[plugin],
      ),
      initialPluginId: plugin.id,
      initialWorkspacePath: fixtureRoot.path,
    );

    await controller.loadWorkspace();
    expect(controller.loadError, isNull);
    expect(controller.workspace, isNotNull);
    expect(controller.document, isNotNull);
    expect(controller.scene, isNotNull);

    controller.applyCommand(AuthoringCommand(kind: 'mutate'));
    expect(controller.canUndo, isTrue);

    plugin.failLoads = true;
    await controller.loadWorkspace();

    expect(reportedErrors, hasLength(1));
    expect(
      reportedErrors.single.exceptionAsString(),
      contains('forced load failure'),
    );
    expect(controller.loadError, contains('forced load failure'));
    expect(controller.workspace, isNull);
    expect(controller.document, isNull);
    expect(controller.scene, isNull);
    expect(controller.issues, isEmpty);
    expect(controller.pendingChanges.hasChanges, isFalse);
    expect(controller.pendingChangesError, isNull);
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isFalse);
    expect(controller.lastExportResult, isNull);
  });
}

class _RecordingPlugin implements AuthoringDomainPlugin {
  final List<String> exportWorkspaceRoots = <String>[];
  bool failLoads = false;

  @override
  String get id => 'recording';

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    if (command.kind == 'mutate' && document is _RecordingDocument) {
      return _RecordingDocument(revision: document.revision + 1);
    }
    return document;
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    final recordingDocument = document as _RecordingDocument;
    return _RecordingScene(revision: recordingDocument.revision);
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
    if (failLoads) {
      throw StateError('forced load failure');
    }
    return const _RecordingDocument();
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return const <ValidationIssue>[];
  }
}

class _RecordingDocument extends AuthoringDocument {
  const _RecordingDocument({this.revision = 0});

  final int revision;
}

class _RecordingScene extends EditableScene {
  const _RecordingScene({required this.revision});

  final int revision;
}
