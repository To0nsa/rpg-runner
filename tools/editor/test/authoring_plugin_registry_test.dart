import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test('duplicate plugin ids fail fast during registry construction', () {
    expect(
      () => AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          const _FakePlugin(id: 'prefabs'),
          const _FakePlugin(id: 'prefabs'),
        ],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Duplicate authoring plugin id "prefabs"'),
        ),
      ),
    );
  });
}

class _FakePlugin implements AuthoringDomainPlugin {
  const _FakePlugin({required this.id});

  @override
  final String id;

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    return document;
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    return const _FakeScene();
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
    return ExportResult(applied: false);
  }

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return const _FakeDocument();
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return const <ValidationIssue>[];
  }
}

class _FakeDocument extends AuthoringDocument {
  const _FakeDocument();
}

class _FakeScene extends EditableScene {
  const _FakeScene();
}
