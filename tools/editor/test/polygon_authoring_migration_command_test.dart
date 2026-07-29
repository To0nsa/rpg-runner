import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/migration/polygon_authoring_migration_command.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/workspace/workspace_file_io.dart';

void main() {
  test('no mode defaults to a successful read-only check', () {
    final root = _repoRootPath();
    final before = _sourceDigests(root);
    final output = StringBuffer();
    final errors = StringBuffer();

    final result = PolygonAuthoringMigrationCommand.run(
      const <String>[],
      defaultWorkspaceRoot: root,
      output: output,
      errorOutput: errors,
    );

    expect(result, PolygonAuthoringMigrationCommand.successExitCode);
    expect(errors.toString(), isEmpty);
    expect(output.toString(), contains('9 validated target file(s)'));
    expect(output.toString(), contains('No authored source was written.'));
    expect(_sourceDigests(root), before);
  });

  test('explicit check writes only the requested external report', () {
    final fixture = _copyMigrationSources();
    try {
      final before = _sourceDigests(fixture.path);
      final output = StringBuffer();
      final errors = StringBuffer();

      final result = PolygonAuthoringMigrationCommand.run(
        const <String>['--check', '--report=.tmp/migration-check.json'],
        defaultWorkspaceRoot: fixture.path,
        output: output,
        errorOutput: errors,
      );

      final reportFile = File(
        p.join(fixture.path, '.tmp', 'migration-check.json'),
      );
      expect(result, PolygonAuthoringMigrationCommand.successExitCode);
      expect(errors.toString(), isEmpty);
      expect(reportFile.existsSync(), isTrue);
      final report =
          jsonDecode(reportFile.readAsStringSync()) as Map<String, Object?>;
      expect(report['mode'], 'check');
      expect(report['status'], 'ready');
      expect((report['targetFiles']! as List<Object?>), hasLength(9));
      expect(output.toString(), contains('.tmp${p.separator}migration-check'));
      expect(_sourceDigests(fixture.path), before);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('unknown and write modes are usage errors with no side effects', () {
    final fixture = _copyMigrationSources();
    try {
      final before = _sourceDigests(fixture.path);
      for (final arguments in <List<String>>[
        <String>['--unknown'],
        <String>['--write'],
        <String>['--check', '--check'],
      ]) {
        final errors = StringBuffer();
        final result = PolygonAuthoringMigrationCommand.run(
          arguments,
          defaultWorkspaceRoot: fixture.path,
          output: StringBuffer(),
          errorOutput: errors,
        );
        expect(
          result,
          PolygonAuthoringMigrationCommand.usageExitCode,
          reason: arguments.join(' '),
        );
        expect(errors.toString(), contains('Usage:'));
      }
      expect(_sourceDigests(fixture.path), before);
      expect(Directory(p.join(fixture.path, '.tmp')).existsSync(), isFalse);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('report path cannot target authored source', () {
    final fixture = _copyMigrationSources();
    try {
      final before = _sourceDigests(fixture.path);
      final errors = StringBuffer();

      final result = PolygonAuthoringMigrationCommand.run(
        const <String>['--report=assets/authoring/level/migration-check.json'],
        defaultWorkspaceRoot: fixture.path,
        output: StringBuffer(),
        errorOutput: errors,
      );

      expect(result, PolygonAuthoringMigrationCommand.usageExitCode);
      expect(errors.toString(), contains('inside authored source'));
      expect(_sourceDigests(fixture.path), before);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('blocking target validation returns one and records blocker report', () {
    final fixture = _copyMigrationSources();
    try {
      final prefabFile = File(p.join(fixture.path, PrefabStore.prefabDefsPath));
      final root =
          jsonDecode(prefabFile.readAsStringSync()) as Map<String, Object?>;
      final slices = root['slices']! as List<Object?>;
      final first = slices.first! as Map<String, Object?>;
      final duplicate = jsonDecode(jsonEncode(first)) as Map<String, Object?>;
      duplicate['x'] = (duplicate['x']! as int) + 1;
      slices.insert(1, duplicate);
      prefabFile.writeAsStringSync(_canonicalJson(root));
      final before = _sourceDigests(fixture.path);
      final errors = StringBuffer();

      final result = PolygonAuthoringMigrationCommand.run(
        const <String>['--report=.tmp/blocked.json'],
        defaultWorkspaceRoot: fixture.path,
        output: StringBuffer(),
        errorOutput: errors,
      );

      final report =
          jsonDecode(
                File(
                  p.join(fixture.path, '.tmp', 'blocked.json'),
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(result, PolygonAuthoringMigrationCommand.blockedExitCode);
      expect(errors.toString(), contains('migration_prefab_target_invalid'));
      expect(report['status'], 'blocked');
      expect((report['blockers']! as List<Object?>), hasLength(1));
      expect(_sourceDigests(fixture.path), before);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('malformed source returns one without emitting a partial report', () {
    final fixture = _copyMigrationSources();
    try {
      final chunkFile = _chunkFiles(fixture.path).first;
      chunkFile.writeAsStringSync('{"schemaVersion": 1,');
      final errors = StringBuffer();

      final result = PolygonAuthoringMigrationCommand.run(
        const <String>['--report=.tmp/partial.json'],
        defaultWorkspaceRoot: fixture.path,
        output: StringBuffer(),
        errorOutput: errors,
      );

      expect(result, PolygonAuthoringMigrationCommand.blockedExitCode);
      expect(errors.toString(), contains('migration_chunk_source_invalid'));
      expect(
        File(p.join(fixture.path, '.tmp', 'partial.json')).existsSync(),
        isFalse,
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
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
    'polygon_migration_command_',
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

String _canonicalJson(Map<String, Object?> json) =>
    '${const JsonEncoder.withIndent('  ').convert(json)}\n';

String _repoRootPath() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}
