import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/migration/polygon_authoring_migration_check.dart';
import 'package:runner_editor/src/migration/polygon_authoring_migration_transaction.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/workspace/workspace_file_io.dart';

void main() {
  test('reviewed legacy batch installs one validated current generation', () {
    final fixture = _copyMigrationSources();
    try {
      final legacy = PolygonAuthoringMigrationCheck.fromRepository(
        fixture.path,
      );

      final result = PolygonAuthoringMigrationTransaction.apply(
        workspaceRoot: fixture.path,
        check: legacy,
      );

      expect(result.status, PolygonAuthoringMigrationWriteStatus.committed);
      expect(
        result.sourceStateBefore,
        PolygonAuthoringMigrationSourceState.legacy,
      );
      expect(result.files, hasLength(9));
      expect(result.files.where((file) => file.changed), hasLength(9));
      final current = PolygonAuthoringMigrationCheck.fromRepository(
        fixture.path,
      );
      expect(current.sourceState, PolygonAuthoringMigrationSourceState.current);
      expect(current.hasBlockers, isFalse);
      expect(
        current.targetFiles.where((target) => target.hasPendingChange),
        isEmpty,
      );
      expect(_transactionFiles(fixture), isEmpty);

      final report =
          jsonDecode(result.toCanonicalJson()) as Map<String, Object?>;
      expect(report['mode'], 'write');
      expect(report['status'], 'committed');
      expect(report['sourceStateBefore'], 'legacy');
      expect(report['sourceStateAfter'], 'current');
      expect(
        (report['summary']! as Map<String, Object?>)['changedFileCount'],
        9,
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('reapplying a fresh current check is a byte-identical no-op', () {
    final fixture = _copyMigrationSources();
    try {
      final legacy = PolygonAuthoringMigrationCheck.fromRepository(
        fixture.path,
      );
      PolygonAuthoringMigrationTransaction.apply(
        workspaceRoot: fixture.path,
        check: legacy,
      );
      final current = PolygonAuthoringMigrationCheck.fromRepository(
        fixture.path,
      );
      final before = _sourceDigests(fixture.path);

      final result = PolygonAuthoringMigrationTransaction.apply(
        workspaceRoot: fixture.path,
        check: current,
      );

      expect(result.status, PolygonAuthoringMigrationWriteStatus.noOp);
      expect(result.files.where((file) => file.changed), isEmpty);
      expect(_sourceDigests(fixture.path), before);
      expect(_transactionFiles(fixture), isEmpty);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('source drift rejects before staging or replacement', () {
    final fixture = _copyMigrationSources();
    try {
      final check = PolygonAuthoringMigrationCheck.fromRepository(fixture.path);
      final chunk = _chunkFiles(fixture.path).first;
      chunk.writeAsStringSync('${chunk.readAsStringSync()}\n');
      final drifted = _sourceDigests(fixture.path);

      PolygonAuthoringMigrationWriteException? failure;
      try {
        PolygonAuthoringMigrationTransaction.apply(
          workspaceRoot: fixture.path,
          check: check,
        );
      } on PolygonAuthoringMigrationWriteException catch (error) {
        failure = error;
      }

      expect(failure, isNotNull);
      expect(failure!.code, 'migration_source_drift');
      expect(failure.rollbackComplete, isNull);
      final report =
          jsonDecode(failure.toCanonicalJson()) as Map<String, Object?>;
      expect(report['status'], 'blocked');
      expect(report['sourcePaths'], isEmpty);
      final detail = report['failure']! as Map<String, Object?>;
      expect(detail['rollbackAttempted'], isFalse);
      expect(detail['rollbackComplete'], isFalse);
      expect(detail['outputsCommitted'], isFalse);
      expect(_sourceDigests(fixture.path), drifted);
      expect(_transactionFiles(fixture), isEmpty);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('rollback artifact is canonical and omits unstable cause text', () {
    final failure = PolygonAuthoringMigrationWriteException(
      code: 'migration_write_transaction_failed',
      message: 'The source transaction failed and attempted recovery.',
      cause: StateError('host-specific temporary path'),
      rollbackComplete: true,
      sourcePaths: const <String>['chunks/b.json', 'chunks/a.json'],
    );

    final report =
        jsonDecode(failure.toCanonicalJson()) as Map<String, Object?>;
    expect(report['status'], 'rolledBack');
    expect(report['sourcePaths'], <String>['chunks/a.json', 'chunks/b.json']);
    expect(failure.toCanonicalJson(), isNot(contains('host-specific')));
  });
}

Map<String, String> _sourceDigests(String rootPath) {
  final paths = <String>[
    PrefabStore.prefabDefsPath,
    for (final file in _chunkFiles(rootPath))
      p.relative(file.path, from: rootPath),
  ]..sort();
  return <String, String>{
    for (final relativePath in paths)
      relativePath: WorkspaceFileIo.sha256Digest(
        File(p.join(rootPath, relativePath)).readAsStringSync(),
      ),
  };
}

Directory _copyMigrationSources() {
  final sourceRoot = _repoRootPath();
  final targetRoot = Directory.systemTemp.createTempSync(
    'polygon_migration_transaction_',
  );
  final relativePaths = <String>[
    PrefabStore.prefabDefsPath,
    for (final file in _chunkFiles(sourceRoot))
      p.relative(file.path, from: sourceRoot),
  ];
  for (final relativePath in relativePaths) {
    final source = File(p.join(sourceRoot, relativePath));
    final target = File(p.join(targetRoot.path, relativePath))
      ..parent.createSync(recursive: true);
    source.copySync(target.path);
  }
  return targetRoot;
}

List<File> _chunkFiles(String rootPath) {
  final files =
      Directory(p.join(rootPath, 'assets', 'authoring', 'level', 'chunks'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => p.extension(file.path).toLowerCase() == '.json')
          .toList(growable: false)
        ..sort((left, right) => left.path.compareTo(right.path));
  return files;
}

List<FileSystemEntity> _transactionFiles(Directory root) => root
    .listSync(recursive: true)
    .where(
      (entity) =>
          entity.path.contains('.authoring-') &&
          (entity.path.endsWith('.tmp') || entity.path.endsWith('.bak')),
    )
    .toList(growable: false);

String _repoRootPath() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}
