import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_staging_models.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  final workspace = EditorWorkspace(rootPath: _repoRootPath());

  test('checked-in prefab source loads the current polygon document', () async {
    const plugin = PrefabDomainPlugin();
    final document = await plugin.loadFromRepo(workspace);

    expect(document, isA<PrefabV3StagingDocument>());
    final pending = plugin.describePendingChanges(
      workspace,
      document: document,
    );
    expect(pending.hasChanges, isFalse);
    final issues = plugin.validate(document);
    expect(
      issues.where((issue) => issue.severity == ValidationSeverity.error),
      isEmpty,
    );
    expect(issues.map((issue) => issue.code).toSet(), <String>{
      'prefab_collision_shape_missing',
    });
  });

  test('checked-in chunk source loads the current polygon document', () async {
    final plugin = ChunkDomainPlugin();
    final document = await plugin.loadFromRepo(workspace);

    expect(document, isA<ChunkV2StagingDocument>());
    final pending = plugin.describePendingChanges(
      workspace,
      document: document,
    );
    expect(pending.hasChanges, isFalse);
    final issues = plugin.validate(document);
    expect(
      issues.where((issue) => issue.severity == ValidationSeverity.error),
      isEmpty,
    );
    expect(issues, isEmpty);
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
