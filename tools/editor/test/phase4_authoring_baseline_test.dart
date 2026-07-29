import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  final workspace = EditorWorkspace(rootPath: _repoRootPath());

  test('current prefab source loads as a canonical no-op', () async {
    const plugin = PrefabDomainPlugin();
    final document = await plugin.loadFromRepo(workspace);

    final pending = plugin.describePendingChanges(
      workspace,
      document: document,
    );
    final result = await plugin.exportToRepo(workspace, document: document);

    expect(pending.hasChanges, isFalse);
    expect(result.applied, isFalse);
    expect(result.artifacts, hasLength(1));
    expect(result.artifacts.single.content, contains('changedFiles: 0'));
    expect(
      result.artifacts.single.content,
      contains('No prefab/tile edits detected.'),
    );
  });

  test('current chunk source loads as a canonical no-op', () async {
    final plugin = ChunkDomainPlugin();
    final document = await plugin.loadFromRepo(workspace);

    final pending = plugin.describePendingChanges(
      workspace,
      document: document,
    );
    final result = await plugin.exportToRepo(workspace, document: document);

    expect(pending.hasChanges, isFalse);
    expect(result.applied, isFalse);
    expect(result.artifacts, hasLength(1));
    expect(result.artifacts.single.content, contains('changedChunks: 0'));
    expect(
      result.artifacts.single.content,
      contains('No chunk edits detected.'),
    );
  });
}

String _repoRootPath() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}
