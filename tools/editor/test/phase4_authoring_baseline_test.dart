import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/terrain_authoring/polygon_authoring_migration_required.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  final workspace = EditorWorkspace(rootPath: _repoRootPath());

  test('checked-in legacy prefab source requires polygon migration', () async {
    const plugin = PrefabDomainPlugin();
    final document = await plugin.loadFromRepo(workspace);

    expect(document, isA<PolygonAuthoringMigrationRequiredDocument>());
    expect(
      (document as PolygonAuthoringMigrationRequiredDocument).domain,
      PolygonAuthoringMigrationDomain.prefabs,
    );
    expect(document.reason, PolygonAuthoringMigrationReason.legacySource);
    final pending = plugin.describePendingChanges(
      workspace,
      document: document,
    );
    expect(pending.hasChanges, isFalse);
    expect(
      plugin.validate(document).single,
      isA<ValidationIssue>()
          .having(
            (issue) => issue.code,
            'code',
            'polygon_authoring_migration_required',
          )
          .having(
            (issue) => issue.severity,
            'severity',
            ValidationSeverity.error,
          ),
    );
    await expectLater(
      plugin.exportToRepo(workspace, document: document),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('polygon_authoring_migration_required'),
        ),
      ),
    );
  });

  test('checked-in legacy chunk source requires polygon migration', () async {
    final plugin = ChunkDomainPlugin();
    final document = await plugin.loadFromRepo(workspace);

    expect(document, isA<PolygonAuthoringMigrationRequiredDocument>());
    expect(
      (document as PolygonAuthoringMigrationRequiredDocument).domain,
      PolygonAuthoringMigrationDomain.chunks,
    );
    expect(document.reason, PolygonAuthoringMigrationReason.legacySource);
    final pending = plugin.describePendingChanges(
      workspace,
      document: document,
    );
    expect(pending.hasChanges, isFalse);
    expect(
      plugin.validate(document).single,
      isA<ValidationIssue>()
          .having(
            (issue) => issue.code,
            'code',
            'polygon_authoring_migration_required',
          )
          .having(
            (issue) => issue.severity,
            'severity',
            ValidationSeverity.error,
          ),
    );
    await expectLater(
      plugin.exportToRepo(workspace, document: document),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('polygon_authoring_migration_required'),
        ),
      ),
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
