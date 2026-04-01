import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generator dry-run validates chunk contract smoke input', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_smoke_',
    );
    try {
      _writeFile(
        fixtureRoot.path,
        'assets/authoring/level/chunks/chunk_ok.json',
        '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_ok",
  "id": "chunk_ok",
  "levelId": "field"
}
''',
      );

      final result = await _runDryRun(workingDirectory: fixtureRoot.path);
      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout, contains('Dry-run completed with no blocking issues.'));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('generator dry-run error output is deterministic for same invalid input', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_deterministic_',
    );
    try {
      _writeFile(
        fixtureRoot.path,
        'assets/authoring/level/chunks/chunk_bad.json',
        '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_bad",
  "levelId": "field"
}
''',
      );

      final first = await _runDryRun(workingDirectory: fixtureRoot.path);
      final second = await _runDryRun(workingDirectory: fixtureRoot.path);

      expect(first.exitCode, 1);
      expect(second.exitCode, 1);
      expect(second.stderr, first.stderr);
      expect(second.stdout, first.stdout);
      expect(first.stderr, contains('missing_id'));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });
}

Future<ProcessResult> _runDryRun({required String workingDirectory}) {
  final scriptPath = _joinPath(
    <String>[
      Directory.current.path,
      'tool',
      'generate_chunk_runtime_data.dart',
    ],
  );
  final dartExecutable = _resolveDartExecutable();
  return Process.run(
    dartExecutable,
    <String>[scriptPath, '--dry-run'],
    workingDirectory: workingDirectory,
  );
}

String _resolveDartExecutable() {
  final whereCommand = Platform.isWindows ? 'where' : 'which';
  final lookup = Process.runSync(whereCommand, <String>['flutter']);
  if (lookup.exitCode == 0) {
    final stdout = '${lookup.stdout}'.trim();
    if (stdout.isNotEmpty) {
      final flutterExecutable = stdout.split(RegExp(r'\r?\n')).first.trim();
      final flutterBinDir = File(flutterExecutable).parent.path;
      final dartExecutable = Platform.isWindows
          ? _joinPath(<String>[
              flutterBinDir,
              'cache',
              'dart-sdk',
              'bin',
              'dart.exe',
            ])
          : _joinPath(<String>[
              flutterBinDir,
              'cache',
              'dart-sdk',
              'bin',
              'dart',
            ]);
      if (File(dartExecutable).existsSync()) {
        return dartExecutable;
      }
    }
  }
  return 'dart';
}

void _writeFile(String rootPath, String relativePath, String content) {
  final absolutePath = _joinPath(<String>[rootPath, ...relativePath.split('/')]);
  final file = File(absolutePath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content.trimLeft());
}

String _joinPath(List<String> parts) {
  return parts.join(Platform.pathSeparator);
}
