import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/migration/polygon_authoring_migration_check.dart';
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

  test('current repository succeeds with zero pending source files', () {
    final fixture = _copyMigrationSources();
    try {
      final before = _sourceDigests(fixture.path);
      final output = StringBuffer();
      final errors = StringBuffer();

      final result = PolygonAuthoringMigrationCommand.run(
        const <String>['--check'],
        defaultWorkspaceRoot: fixture.path,
        output: output,
        errorOutput: errors,
      );

      expect(result, PolygonAuthoringMigrationCommand.successExitCode);
      expect(errors.toString(), isEmpty);
      expect(output.toString(), contains('ready (current)'));
      expect(
        output.toString(),
        contains('0 source file(s) have a pending representation migration.'),
      );
      expect(_sourceDigests(fixture.path), before);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('write commits all sources and repeated write is a reported no-op', () {
    final fixture = _copyMigrationSources();
    try {
      _demoteFixtureToLegacy(fixture.path);
      final output = StringBuffer();
      final errors = StringBuffer();
      final first = PolygonAuthoringMigrationCommand.run(
        const <String>['--write', '--report=.tmp/migration-write.json'],
        defaultWorkspaceRoot: fixture.path,
        output: output,
        errorOutput: errors,
      );

      expect(first, PolygonAuthoringMigrationCommand.successExitCode);
      expect(errors.toString(), isEmpty);
      expect(output.toString(), contains('write committed'));
      final reportFile = File(
        p.join(fixture.path, '.tmp', 'migration-write.json'),
      );
      final committed =
          jsonDecode(reportFile.readAsStringSync()) as Map<String, Object?>;
      expect(committed['mode'], 'write');
      expect(committed['status'], 'committed');
      expect(
        (committed['summary']! as Map<String, Object?>)['changedFileCount'],
        9,
      );
      final current = PolygonAuthoringMigrationCheck.fromRepository(
        fixture.path,
      );
      expect(current.sourceState, PolygonAuthoringMigrationSourceState.current);
      expect(
        current.targetFiles.every((target) => !target.hasPendingChange),
        isTrue,
      );
      final afterFirst = _sourceDigests(fixture.path);

      final secondOutput = StringBuffer();
      final second = PolygonAuthoringMigrationCommand.run(
        const <String>['--write', '--report=.tmp/migration-write.json'],
        defaultWorkspaceRoot: fixture.path,
        output: secondOutput,
        errorOutput: StringBuffer(),
      );
      final noOp =
          jsonDecode(reportFile.readAsStringSync()) as Map<String, Object?>;
      expect(second, PolygonAuthoringMigrationCommand.successExitCode);
      expect(secondOutput.toString(), contains('write noOp'));
      expect(noOp['status'], 'noOp');
      expect((noOp['summary']! as Map<String, Object?>)['changedFileCount'], 0);
      expect(_sourceDigests(fixture.path), afterFirst);
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
      _demoteFixtureToLegacy(fixture.path);
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

  test('mixed schema generation returns one without a partial report', () {
    final fixture = _copyMigrationSources();
    try {
      _demoteFixtureToLegacy(fixture.path);
      final legacy = PolygonAuthoringMigrationCheck.fromRepository(
        fixture.path,
      );
      final prefabTarget = legacy.targetFiles.singleWhere(
        (target) => target.sourceKind == 'prefabs',
      );
      File(
        p.join(fixture.path, p.normalize(prefabTarget.sourcePath)),
      ).writeAsStringSync(prefabTarget.canonicalContents);
      final before = _sourceDigests(fixture.path);
      final errors = StringBuffer();

      final result = PolygonAuthoringMigrationCommand.run(
        const <String>['--report=.tmp/mixed.json'],
        defaultWorkspaceRoot: fixture.path,
        output: StringBuffer(),
        errorOutput: errors,
      );

      expect(result, PolygonAuthoringMigrationCommand.blockedExitCode);
      expect(errors.toString(), contains('migration_mixed_schema_generation'));
      expect(
        File(p.join(fixture.path, '.tmp', 'mixed.json')).existsSync(),
        isFalse,
      );
      expect(_sourceDigests(fixture.path), before);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('noncanonical current source returns one without a partial report', () {
    final fixture = _copyMigrationSources();
    try {
      final chunkFile = _chunkFiles(fixture.path).first;
      chunkFile.writeAsStringSync('${chunkFile.readAsStringSync()}\n');
      final before = _sourceDigests(fixture.path);
      final errors = StringBuffer();

      final result = PolygonAuthoringMigrationCommand.run(
        const <String>['--report=.tmp/noncanonical.json'],
        defaultWorkspaceRoot: fixture.path,
        output: StringBuffer(),
        errorOutput: errors,
      );

      expect(result, PolygonAuthoringMigrationCommand.blockedExitCode);
      expect(
        errors.toString(),
        contains('migration_current_source_noncanonical'),
      );
      expect(
        File(p.join(fixture.path, '.tmp', 'noncanonical.json')).existsSync(),
        isFalse,
      );
      expect(_sourceDigests(fixture.path), before);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('malformed current source returns one without a partial report', () {
    final fixture = _copyMigrationSources();
    try {
      final chunkFile = _chunkFiles(fixture.path).first;
      final root =
          jsonDecode(chunkFile.readAsStringSync()) as Map<String, Object?>;
      root.remove('width');
      chunkFile.writeAsStringSync(_canonicalJson(root));
      final before = _sourceDigests(fixture.path);
      final errors = StringBuffer();

      final result = PolygonAuthoringMigrationCommand.run(
        const <String>['--report=.tmp/malformed-current.json'],
        defaultWorkspaceRoot: fixture.path,
        output: StringBuffer(),
        errorOutput: errors,
      );

      expect(result, PolygonAuthoringMigrationCommand.blockedExitCode);
      expect(errors.toString(), contains('migration_chunk_source_invalid'));
      expect(
        File(
          p.join(fixture.path, '.tmp', 'malformed-current.json'),
        ).existsSync(),
        isFalse,
      );
      expect(_sourceDigests(fixture.path), before);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test(
    'standalone Dart entrypoint stays free of Flutter runtime imports',
    () async {
      final result = await Process.run(
        _standaloneDartExecutable(),
        const <String>['run', 'tool/migrate_polygon_authoring.dart', '--help'],
        workingDirectory: p.join(_repoRootPath(), 'tools', 'editor'),
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stderr, isEmpty);
      expect(result.stdout, contains('--write requires an external --report'));
    },
  );

  test('two standalone Dart checks reproduce migration report signature', () {
    final fixture = _copyMigrationSources();
    try {
      final before = _sourceDigests(fixture.path);
      final reports = <String>[];
      for (final name in const <String>['first', 'second']) {
        final result = Process.runSync(
          _standaloneDartExecutable(),
          <String>[
            'run',
            'tool/migrate_polygon_authoring.dart',
            '--check',
            '--repo-root=${fixture.path}',
            '--report=.tmp/$name.json',
          ],
          workingDirectory: p.join(_repoRootPath(), 'tools', 'editor'),
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stderr, isEmpty);
        reports.add(
          File(p.join(fixture.path, '.tmp', '$name.json')).readAsStringSync(),
        );
      }

      expect(reports[1], reports[0]);
      final record = _lengthPrefixedRecord(<String>[
        polygonAuthoringMigrationSignatureFormat,
        reports.first,
      ]);
      expect(
        WorkspaceFileIo.sha256Digest(record),
        '300459920601cd4a32adb67ca99610d06c237a50edc38a05ee50c60b6caf2982',
      );
      expect(_sourceDigests(fixture.path), before);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });
}

String _standaloneDartExecutable() {
  final resolved = File(Platform.resolvedExecutable);
  if (p.basenameWithoutExtension(resolved.path) == 'dart') {
    return resolved.path;
  }
  var directory = resolved.parent;
  while (true) {
    final candidate = File(
      p.join(
        directory.path,
        'dart-sdk',
        'bin',
        Platform.isWindows ? 'dart.exe' : 'dart',
      ),
    );
    if (candidate.existsSync()) return candidate.path;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError(
    'Could not locate the standalone Dart executable from '
    '${Platform.resolvedExecutable}.',
  );
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

void _demoteFixtureToLegacy(String rootPath) {
  final prefabFile = File(p.join(rootPath, PrefabStore.prefabDefsPath));
  final prefabRoot =
      jsonDecode(prefabFile.readAsStringSync()) as Map<String, Object?>;
  prefabRoot['schemaVersion'] = 2;
  for (final rawPrefab in prefabRoot['prefabs']! as List<Object?>) {
    final prefab = rawPrefab! as Map<String, Object?>;
    final legacy = <String, Object?>{};
    for (final entry in prefab.entries) {
      if (entry.key == 'collisionShapes') {
        legacy['colliders'] = <Object?>[];
      } else {
        legacy[entry.key] = entry.value;
      }
    }
    prefab
      ..clear()
      ..addAll(legacy);
  }
  prefabFile.writeAsStringSync(_canonicalJson(prefabRoot));

  for (final chunkFile in _chunkFiles(rootPath)) {
    final root =
        jsonDecode(chunkFile.readAsStringSync()) as Map<String, Object?>;
    root['schemaVersion'] = 1;
    final legacy = <String, Object?>{};
    for (final entry in root.entries) {
      if (entry.key == 'collisionShapes') {
        legacy['groundProfile'] = <String, Object?>{
          'kind': 'flat',
          'topY': 224,
        };
        legacy['groundGaps'] = <Object?>[
          <String, Object?>{
            'gapId': 'collision_cleared',
            'type': 'pit',
            'x': 0,
            'width': 600,
          },
        ];
      } else {
        legacy[entry.key] = entry.value;
      }
    }
    chunkFile.writeAsStringSync(_canonicalJson(legacy));
  }
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

String _lengthPrefixedRecord(List<String> fields) =>
    fields.map((field) => '${utf8.encode(field).length}:$field').join('|');

String _repoRootPath() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}
