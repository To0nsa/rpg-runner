import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test('resolve keeps paths inside workspace root', () {
    final workspace = EditorWorkspace(rootPath: '.');
    final resolved = workspace.resolve('assets/authoring/level');

    expect(workspace.containsPath(resolved), isTrue);
  });

  test('resolve rejects absolute paths', () {
    final workspace = EditorWorkspace(rootPath: '.');
    final absolutePath = p.absolute('assets/authoring/level');

    expect(
      () => workspace.resolve(absolutePath),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('resolve rejects root-escape traversals', () {
    final workspace = EditorWorkspace(rootPath: '.');

    expect(
      () => workspace.resolve('../outside.txt'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('toWorkspaceRelativePath enforces root boundary', () {
    final workspace = EditorWorkspace(rootPath: '.');
    final insidePath = workspace.resolve('assets/authoring/level');

    expect(workspace.toWorkspaceRelativePath(insidePath), isNotEmpty);
    expect(
      () => workspace.toWorkspaceRelativePath(p.absolute('..')),
      throwsA(isA<ArgumentError>()),
    );
  });
}
