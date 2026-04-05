import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test('resolve returns normalized absolute paths inside workspace root', () {
    final workspace = EditorWorkspace(rootPath: '.');
    final resolved = workspace.resolve('assets/authoring/level');

    expect(resolved, p.normalize(p.absolute('assets/authoring/level')));
  });

  test('resolve treats empty and dot paths as the workspace root', () {
    final workspace = EditorWorkspace(rootPath: '.');

    expect(workspace.resolve(''), workspace.rootPath);
    expect(workspace.resolve('.'), workspace.rootPath);
  });

  test('resolve does not trim caller input', () {
    final workspace = EditorWorkspace(rootPath: '.');

    expect(
      workspace.resolve(' assets/authoring/level '),
      p.normalize(p.absolute(' assets/authoring/level ')),
    );
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
}
