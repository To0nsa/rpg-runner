import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generator dry-run validates chunk contract smoke input', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_smoke_',
    );
    try {
      _writePrefabAndTileDefs(fixtureRoot.path);
      _writeFile(
        fixtureRoot.path,
        'assets/authoring/level/chunks/field/chunk_ok.json',
        '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_ok",
  "id": "chunk_ok",
  "levelId": "field",
  "difficulty": "easy"
}
''',
      );

      final result = await _runDryRun(workingDirectory: fixtureRoot.path);
      expect(result.exitCode, 0, reason: result.stderr);
      expect(
        result.stdout,
        contains('Dry-run completed with no blocking issues.'),
      );
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test(
    'generator dry-run error output is deterministic for same invalid input',
    () async {
      final fixtureRoot = await Directory.systemTemp.createTemp(
        'chunk_generator_deterministic_',
      );
      try {
        _writePrefabAndTileDefs(fixtureRoot.path);
        _writeFile(
          fixtureRoot.path,
          'assets/authoring/level/chunks/field/chunk_bad.json',
          '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_bad",
  "levelId": "field",
  "difficulty": "easy"
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
    },
  );

  test('generator writes authored runtime dart output', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_write_',
    );
    try {
      _writePrefabAndTileDefs(fixtureRoot.path);
      _writeFile(
        fixtureRoot.path,
        'assets/authoring/level/chunks/field/chunk_ok.json',
        '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_ok",
  "id": "chunk_ok",
  "levelId": "field",
  "difficulty": "easy",
  "groundProfile": {"kind": "flat", "topY": 224},
  "prefabs": [
    {
      "prefabId": "grass",
      "prefabKey": "grass",
      "x": 80,
      "y": 80,
      "zIndex": 0,
      "snapToGrid": true
    }
  ],
  "markers": [
    {
      "markerId": "derf",
      "x": 64,
      "y": 32,
      "chancePercent": 80,
      "salt": 7,
      "placement": "ground"
    }
  ],
  "groundGaps": [{"gapId": "gap_1", "x": 160, "width": 32}]
}
''',
      );

      final result = await _runGenerate(workingDirectory: fixtureRoot.path);
      expect(result.exitCode, 0, reason: result.stderr);

      final outputFile = File(
        _joinPath(<String>[
          fixtureRoot.path,
          'packages',
          'runner_core',
          'lib',
          'track',
          'authored_chunk_patterns.dart',
        ]),
      );
      expect(outputFile.existsSync(), isTrue);
      final output = outputFile.readAsStringSync();
      expect(output, contains('fieldEasyPatterns'));
      expect(output, contains('authoredChunkPatternSourcesByLevel'));
      expect(output, contains('visualSprites: <ChunkVisualSpriteRel>['));
      expect(output, contains('chancePercent: 80'));
      expect(output, contains('EnemyId.derf'));
      expect(
        output,
        contains(
          'PlatformRel(x: 64.0, width: 16.0, aboveGroundTop: 160.0, thickness: 16.0)',
        ),
      );
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test(
    'generator rejects chunk whose levelId does not match owning folder',
    () async {
      final fixtureRoot = await Directory.systemTemp.createTemp(
        'chunk_generator_level_scope_',
      );
      try {
        _writePrefabAndTileDefs(fixtureRoot.path);
        _writeFile(
          fixtureRoot.path,
          'assets/authoring/level/chunks/field/chunk_bad.json',
          '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_bad",
  "id": "chunk_bad",
  "levelId": "forest",
  "difficulty": "easy"
}
''',
        );

        final result = await _runDryRun(workingDirectory: fixtureRoot.path);
        expect(result.exitCode, 1);
        expect(result.stderr, contains('level_id_path_mismatch'));
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );
}

Future<ProcessResult> _runDryRun({required String workingDirectory}) {
  final scriptPath = _joinPath(<String>[
    Directory.current.path,
    'tool',
    'generate_chunk_runtime_data.dart',
  ]);
  final dartExecutable = _resolveDartExecutable();
  return Process.run(dartExecutable, <String>[
    scriptPath,
    '--dry-run',
  ], workingDirectory: workingDirectory);
}

Future<ProcessResult> _runGenerate({required String workingDirectory}) {
  final scriptPath = _joinPath(<String>[
    Directory.current.path,
    'tool',
    'generate_chunk_runtime_data.dart',
  ]);
  final dartExecutable = _resolveDartExecutable();
  return Process.run(dartExecutable, <String>[
    scriptPath,
  ], workingDirectory: workingDirectory);
}

void _writePrefabAndTileDefs(String rootPath) {
  _writeFile(rootPath, 'assets/authoring/level/prefab_defs.json', '''
{
  "schemaVersion": 2,
  "slices": [
    {
      "id": "grass_slice",
      "sourceImagePath": "assets/images/level/tileset/TX Tileset Ground.png",
      "x": 0,
      "y": 0,
      "width": 32,
      "height": 32
    }
  ],
  "prefabs": [
    {
      "prefabKey": "grass",
      "id": "grass",
      "revision": 1,
      "status": "active",
      "kind": "platform",
      "visualSource": {"type": "atlas_slice", "sliceId": "grass_slice"},
      "anchorXPx": 16,
      "anchorYPx": 16,
      "colliders": [
        {"offsetX": 0, "offsetY": 0, "width": 17, "height": 17}
      ],
      "tags": []
    }
  ]
}
''');

  _writeFile(rootPath, 'assets/authoring/level/tile_defs.json', '''
{
  "schemaVersion": 2,
  "tileSlices": [],
  "platformModules": []
}
''');
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
  final absolutePath = _joinPath(<String>[
    rootPath,
    ...relativePath.split('/'),
  ]);
  final file = File(absolutePath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content.trimLeft());
}

String _joinPath(List<String> parts) {
  return parts.join(Platform.pathSeparator);
}
