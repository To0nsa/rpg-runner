@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/level_definition_generation.dart' as level_source;

void main() {
  test(
    'machine reports exact included/excluded source and content freshness',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'build_machine_report_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      _writeValidSmokeFixture(root.path);
      Future<Map<String, dynamic>> run({bool dryRun = false}) async {
        final result = await Process.run(_resolveDartExecutable(), [
          File('tool/generate_chunk_runtime_data.dart').absolute.path,
          '--machine-readable',
          if (dryRun) '--dry-run',
        ], workingDirectory: root.path);
        final records = const LineSplitter()
            .convert(result.stdout as String)
            .map((line) => jsonDecode(line) as Map<String, dynamic>)
            .toList();
        expect(
          records.every((record) => record['protocolVersion'] == 1),
          isTrue,
        );
        final report = records.singleWhere(
          (record) => record['type'] == 'result',
        );
        expect(report['inputFingerprint'], matches(RegExp(r'^[a-f0-9]{64}$')));
        return report;
      }

      final generated = await run();
      expect(generated['outcome'], 'built');
      expect(generated['outputsCommitted'], isTrue);
      final levels = (generated['levels'] as List).cast<Map<String, dynamic>>();
      expect(
        levels.singleWhere((l) => l['levelId'] == 'field')['includeInBuild'],
        isTrue,
      );
      expect(
        levels.singleWhere((l) => l['levelId'] == 'forest')['includeInBuild'],
        isFalse,
      );
      final current = await run(dryRun: true);
      expect(current['outcome'], 'current');
      expect(current['inputFingerprint'], generated['inputFingerprint']);
      final output = File(
        '${root.path}/${(generated['outputs'] as List).first}',
      );
      output.writeAsStringSync('modified generated output');
      final drift = await run(dryRun: true);
      expect(drift['outcome'], 'drift');
      expect(drift['outputsCommitted'], isFalse);
      expect(drift['changes'], isNotEmpty);
      _updateLevelSource(root.path, (level) => level['includeInBuild'] = true);
      final invalid = await run();
      expect(invalid['outcome'], 'invalid');
      expect(
        (invalid['issues'] as List)
            .where(
              (issue) => issue['code'] == 'included_level_has_no_active_chunks',
            )
            .single['levelId'],
        'forest',
      );
      expect(output.readAsStringSync(), 'modified generated output');
    },
  );

  test(
    'machine cancellation finishes without publishing any generated output',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'build_machine_cancel_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      _writeValidSmokeFixture(root.path);
      final process = await Process.start(_resolveDartExecutable(), [
        File('tool/generate_chunk_runtime_data.dart').absolute.path,
        '--machine-readable',
      ], workingDirectory: root.path);
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      process.stdin.writeln('cancel');
      await process.stdin.close();
      expect(await process.exitCode, 1);
      await errors;
      final records = const LineSplitter()
          .convert(await output)
          .map((line) => jsonDecode(line) as Map<String, dynamic>);
      final report = records.singleWhere(
        (record) => record['type'] == 'result',
      );
      expect(report['outcome'], 'cancelled');
      expect(report['outputsCommitted'], isFalse);
      expect(
        Directory('${root.path}/packages/runner_core/lib').existsSync(),
        isFalse,
      );
    },
  );

  test(
    'source additions during generation cancel before output replacement',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'build_machine_drift_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      _writeValidSmokeFixture(root.path);
      final process = await Process.start(_resolveDartExecutable(), [
        File('tool/generate_chunk_runtime_data.dart').absolute.path,
        '--machine-readable',
      ], workingDirectory: root.path);
      var edited = false;
      final reports = <Map<String, dynamic>>[];
      final readOutput = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
            final report = jsonDecode(line) as Map<String, dynamic>;
            reports.add(report);
            if (report['phase'] == 'validating') {
              _writeFile(
                root.path,
                'assets/authoring/level/concurrent_source.json',
                '{}',
              );
              edited = true;
            }
          });
      final errors = process.stderr.transform(utf8.decoder).join();
      expect(await process.exitCode, 1);
      await readOutput;
      await errors;
      expect(edited, isTrue);
      final report = reports.singleWhere(
        (record) => record['type'] == 'result',
      );
      expect(report['outcome'], 'stale');
      expect(report['outputsCommitted'], isFalse);
      expect(
        Directory('${root.path}/packages/runner_core/lib').existsSync(),
        isFalse,
      );
    },
  );

  test(
    'excluded Field keeps enum metadata while Forest supplies runtime defaults',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'level_inclusion_defaults_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      _writeValidSmokeFixture(root.path);
      _updateLevelSource(root.path, (level) {
        level['includeInBuild'] = level['levelId'] == 'forest';
      });
      _writeCurrentChunkFixture(
        root.path,
        'assets/authoring/level/chunks/forest/ready.json',
        '{"chunkKey":"forest_ready","id":"forest_ready","levelId":"forest","difficulty":"early"}',
      );

      final generated = await _runGenerate(workingDirectory: root.path);

      expect(generated.exitCode, 0, reason: generated.stderr);
      final registry = File(
        _joinPath(<String>[
          root.path,
          'packages/runner_core/lib/levels/level_registry.dart',
        ]),
      ).readAsStringSync();
      expect(registry, contains('defaultLevelId = LevelId.forest'));
      expect(
        registry,
        contains(
          'case LevelId.field:\n        throw LevelUnavailableException(id);',
        ),
      );
      final enums = File(
        _joinPath(<String>[
          root.path,
          'packages/runner_core/lib/levels/level_id.dart',
        ]),
      ).readAsStringSync();
      expect(enums, contains('enum LevelId { forest, field }'));
      final metadata = File(
        _joinPath(<String>[
          root.path,
          'lib/ui/levels/generated_level_ui_metadata.dart',
        ]),
      ).readAsStringSync();
      expect(metadata, contains('LevelId.field: GeneratedLevelUiMetadata'));
      expect(
        metadata,
        contains(
          'generatedSelectableLevelIds = <LevelId>[\n  LevelId.forest,\n]',
        ),
      );
      for (final output in <String>[
        'authored_chunk_patterns.dart',
        'staged_authored_terrain.dart',
      ]) {
        final content = File(
          _joinPath(<String>[
            root.path,
            'packages/runner_core/lib/track',
            output,
          ]),
        ).readAsStringSync();
        expect(content, contains('forest_ready'));
        expect(content, isNot(contains('chunk_ok')));
      }
      final probe = await _runCompiledRegistryProbe(root.path, '''
  if (LevelRegistry.defaultLevelId != LevelId.forest) throw StateError('wrong default');
  if (LevelRegistry.isAvailable(LevelId.field)) throw StateError('excluded available');
  try {
    LevelRegistry.byId(LevelId.field);
    throw StateError('excluded definition constructed');
  } on LevelUnavailableException catch (error) {
    if (error.levelId != LevelId.field) throw StateError('identity substituted');
  }
  if (LevelRegistry.byId(LevelId.forest).identity.requireRegisteredId() != LevelId.forest) {
    throw StateError('included identity changed');
  }
''');
      expect(probe.exitCode, 0, reason: probe.stderr);
    },
  );

  test('excluded incomplete design resumes with the same rules and blocks inclusion until ready', () async {
    final root = await Directory.systemTemp.createTemp(
      'level_inclusion_resume_',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    _writeValidSmokeFixture(root.path);
    _updateLevelSource(root.path, (level) {
      if (level['levelId'] == 'forest') {
        level['assembly'] = <String, Object?>{
          'loopSegments': true,
          'segments': <Object?>[
            <String, Object?>{
              'segmentId': 'opening',
              'groupId': 'default',
              'minChunkCount': 2,
              'maxChunkCount': 2,
              'requireDistinctChunks': true,
            },
          ],
        };
      }
    });
    final source = File(
      _joinPath(<String>[root.path, 'assets/authoring/level/level_defs.json']),
    );
    final excludedSource = source.readAsStringSync();
    expect((await _runGenerate(workingDirectory: root.path)).exitCode, 0);
    _updateLevelSource(root.path, (level) {
      level['includeInBuild'] = true;
    });
    final failed = await _runGenerate(workingDirectory: root.path);
    expect(failed.exitCode, 1);
    expect(failed.stderr, contains('included_level_has_no_active_chunks'));
    expect(
      source.readAsStringSync(),
      excludedSource.replaceFirst(
        '"includeInBuild": false',
        '"includeInBuild": true',
      ),
    );
    for (var index = 1; index <= 2; index++) {
      _writeCurrentChunkFixture(
        root.path,
        'assets/authoring/level/chunks/forest/ready_$index.json',
        '{"chunkKey":"ready_$index","id":"ready_$index","levelId":"forest","difficulty":"early"}',
      );
    }
    final ready = await _runGenerate(workingDirectory: root.path);
    expect(ready.exitCode, 0, reason: ready.stderr);
    expect(
      source.readAsStringSync(),
      excludedSource.replaceFirst(
        '"includeInBuild": false',
        '"includeInBuild": true',
      ),
    );
    _updateLevelSource(root.path, (level) {
      if (level['levelId'] == 'forest') level['status'] = 'deprecated';
    });
    final deprecated = await _runGenerate(workingDirectory: root.path);
    expect(deprecated.exitCode, 0, reason: deprecated.stderr);
    final probe = await _runCompiledRegistryProbe(root.path, '''
  if (!LevelRegistry.isAvailable(LevelId.forest)) throw StateError('deprecated unavailable');
  if (LevelRegistry.byId(LevelId.forest).identity.requireRegisteredId() != LevelId.forest) {
    throw StateError('deprecated identity changed');
  }
  if (LevelRegistry.defaultLevelId != LevelId.field) throw StateError('deprecated default');
''');
    expect(probe.exitCode, 0, reason: probe.stderr);
  });

  test(
    'all excluded and included-empty levels cannot replace generated outputs',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'level_inclusion_rejection_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      _writeValidSmokeFixture(root.path);
      expect((await _runGenerate(workingDirectory: root.path)).exitCode, 0);
      final registry = File(
        _joinPath(<String>[
          root.path,
          'packages/runner_core/lib/levels/level_registry.dart',
        ]),
      );
      final before = registry.readAsStringSync();
      _updateLevelSource(root.path, (level) {
        level['includeInBuild'] = false;
      });
      final excluded = await _runGenerate(workingDirectory: root.path);
      expect(excluded.exitCode, 1);
      expect(excluded.stderr, contains('no_included_active_level'));
      expect(registry.readAsStringSync(), before);
      _updateLevelSource(root.path, (level) {
        level['includeInBuild'] = level['levelId'] == 'forest';
      });
      final empty = await _runGenerate(workingDirectory: root.path);
      expect(empty.exitCode, 1);
      expect(empty.stderr, contains('included_level_has_no_active_chunks'));
      expect(registry.readAsStringSync(), before);
    },
  );

  test(
    'excluded structural corruption and deprecated chunk capacity stay strict',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'level_inclusion_structure_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      _writeValidSmokeFixture(root.path);
      _writeCurrentChunkFixture(
        root.path,
        'assets/authoring/level/chunks/forest/bad.json',
        '{"chunkKey":"bad","id":"bad","levelId":"forest","difficulty":"early","unknown":true}',
      );
      final corrupt = await _runGenerate(workingDirectory: root.path);
      expect(corrupt.exitCode, 1);
      expect(corrupt.stderr, contains('chunk_source_invalid'));
      expect(corrupt.stderr, contains('forest/bad.json'));
      _writeCurrentChunkFixture(
        root.path,
        'assets/authoring/level/chunks/forest/bad.json',
        '{"chunkKey":"bad","id":"bad","levelId":"forest","difficulty":"early","status":"deprecated"}',
      );
      final excluded = await _runGenerate(workingDirectory: root.path);
      expect(excluded.exitCode, 0, reason: excluded.stderr);
      _updateLevelSource(root.path, (level) {
        level['includeInBuild'] = true;
      });
      final included = await _runGenerate(workingDirectory: root.path);
      expect(included.exitCode, 1);
      expect(included.stderr, contains('included_level_has_no_active_chunks'));
    },
  );

  test('generator dry-run validates chunk contract smoke input', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_smoke_',
    );
    try {
      _writeValidSmokeFixture(fixtureRoot.path);
      final generated = await _runGenerate(workingDirectory: fixtureRoot.path);
      expect(generated.exitCode, 0, reason: generated.stderr);

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

  test('generator rejects invalid parallax theme identities', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_invalid_theme_id_',
    );
    try {
      _writeValidSmokeFixture(fixtureRoot.path);
      final path = _joinPath(<String>[
        fixtureRoot.path,
        'assets',
        'authoring',
        'level',
        'parallax_defs.json',
      ]);
      final file = File(path);
      file.writeAsStringSync(
        file.readAsStringSync().replaceFirst(
          '"parallaxThemeId": "field"',
          '"parallaxThemeId": "Field"',
        ),
      );

      final result = await _runGenerate(workingDirectory: fixtureRoot.path);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('invalid_parallax_theme_id'));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('generator rejects colliding generated parallax symbols', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_theme_symbol_collision_',
    );
    try {
      _writeValidSmokeFixture(fixtureRoot.path);
      _writeParallaxDefsWithGeneratedSymbolCollision(fixtureRoot.path);

      final result = await _runGenerate(workingDirectory: fixtureRoot.path);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('duplicate_generated_theme_symbol'));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('stale generated level registry cannot block regeneration', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_stale_registry_input_',
    );
    try {
      _writeValidSmokeFixture(fixtureRoot.path);
      _writeFile(
        fixtureRoot.path,
        'packages/runner_core/lib/levels/level_registry.dart',
        "const stale = 'missing_generated_theme';\n",
      );

      final result = await _runGenerate(workingDirectory: fixtureRoot.path);

      expect(result.exitCode, 0, reason: result.stderr);
      final generatedRegistry = File(
        _joinPath(<String>[
          fixtureRoot.path,
          'packages',
          'runner_core',
          'lib',
          'levels',
          'level_registry.dart',
        ]),
      ).readAsStringSync();
      expect(generatedRegistry, isNot(contains('missing_generated_theme')));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('authored level theme references remain generation authority', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_authored_theme_reference_',
    );
    try {
      _writeValidSmokeFixture(fixtureRoot.path);
      final path = _joinPath(<String>[
        fixtureRoot.path,
        'assets',
        'authoring',
        'level',
        'parallax_defs.json',
      ]);
      final file = File(path);
      final raw = file.readAsStringSync();
      final forestStart = raw.indexOf(
        '    {\n      "parallaxThemeId": "forest"',
      );
      expect(forestStart, greaterThan(0));
      file.writeAsStringSync('${raw.substring(0, forestStart - 2)}\n  ]\n}\n');

      final result = await _runGenerate(workingDirectory: fixtureRoot.path);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('missing_level_parallax_theme'));
      expect(result.stderr, contains('forest'));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test(
    'generator preserves visuals while collision authoring is cleared',
    () async {
      final fixtureRoot = await Directory.systemTemp.createTemp(
        'chunk_generator_collision_cleared_',
      );
      try {
        _writePrefabAndTileDefs(fixtureRoot.path);
        _writeLevelDefs(fixtureRoot.path);
        _writeParallaxDefs(fixtureRoot.path);
        _writeCurrentChunkFixture(
          fixtureRoot.path,
          'assets/authoring/level/chunks/field/chunk_cleared.json',
          '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_cleared",
  "id": "chunk_cleared",
  "levelId": "field",
  "difficulty": "easy",
  "prefabs": [
    {
      "prefabId": "grass",
      "prefabKey": "grass",
      "x": 160,
      "y": 160,
      "zIndex": 0,
      "snapToGrid": true
    }
  ],
  "groundProfile": {"kind": "flat", "topY": 224},
  "groundGaps": [
    {"gapId": "collision_cleared", "type": "pit", "x": 0, "width": 600}
  ]
}
''',
        );

        final result = await _runGenerate(workingDirectory: fixtureRoot.path);
        expect(result.exitCode, 0, reason: result.stderr);
        final output = File(
          _joinPath(<String>[
            fixtureRoot.path,
            'packages',
            'runner_core',
            'lib',
            'track',
            'authored_chunk_patterns.dart',
          ]),
        ).readAsStringSync();

        expect(output, contains("chunkKey: 'chunk_cleared'"));
        expect(output, isNot(contains('GapRel(')));
        expect(output, isNot(contains('SolidRel(')));
        expect(output, contains('visualSprites: <ChunkVisualSpriteRel>['));
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test(
    'generator dry-run reports every missing output without writing',
    () async {
      final fixtureRoot = await Directory.systemTemp.createTemp(
        'chunk_generator_missing_outputs_',
      );
      try {
        _writeValidSmokeFixture(fixtureRoot.path);

        final result = await _runDryRun(workingDirectory: fixtureRoot.path);

        expect(result.exitCode, 1);
        expect(
          'generated_output_missing'.allMatches(result.stderr as String),
          hasLength(7),
        );
        expect(
          result.stderr,
          contains('Generated output drift found in 7 file(s).'),
        );
        expect(
          File(
            _joinPath(<String>[
              fixtureRoot.path,
              'packages',
              'runner_core',
              'lib',
              'track',
              'authored_chunk_patterns.dart',
            ]),
          ).existsSync(),
          isFalse,
        );
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test('generator dry-run reports exact stale committed output', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_stale_output_',
    );
    try {
      _writeValidSmokeFixture(fixtureRoot.path);
      final generated = await _runGenerate(workingDirectory: fixtureRoot.path);
      expect(generated.exitCode, 0, reason: generated.stderr);
      final stalePath = _joinPath(<String>[
        fixtureRoot.path,
        'packages',
        'runner_core',
        'lib',
        'track',
        'authored_chunk_patterns.dart',
      ]);
      File(stalePath).writeAsStringSync('// stale\n');

      final result = await _runDryRun(workingDirectory: fixtureRoot.path);

      expect(result.exitCode, 1);
      expect(
        'generated_output_stale'.allMatches(result.stderr as String),
        hasLength(1),
      );
      expect(result.stderr, contains('authored_chunk_patterns.dart'));
      expect(
        result.stderr,
        contains('Generated output drift found in 1 file(s).'),
      );
      expect(File(stalePath).readAsStringSync(), '// stale\n');
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('generator dry-run reports unexpected owned output', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_unexpected_output_',
    );
    try {
      _writeValidSmokeFixture(fixtureRoot.path);
      final generated = await _runGenerate(workingDirectory: fixtureRoot.path);
      expect(generated.exitCode, 0, reason: generated.stderr);
      const orphanRelativePath = 'lib/game/themes/orphan_generated.dart';
      _writeFile(fixtureRoot.path, orphanRelativePath, '''
/// GENERATED FILE. DO NOT EDIT BY HAND.
/// Generated by tool/generate_chunk_runtime_data.dart from a removed output.
''');

      final result = await _runDryRun(workingDirectory: fixtureRoot.path);

      expect(result.exitCode, 1);
      expect(
        'generated_output_unexpected'.allMatches(result.stderr as String),
        hasLength(1),
      );
      expect(result.stderr, contains(orphanRelativePath));
      expect(
        result.stderr,
        contains('Generated output drift found in 1 file(s).'),
      );
      expect(
        File(
          _joinPath(<String>[
            fixtureRoot.path,
            ...orphanRelativePath.split('/'),
          ]),
        ).existsSync(),
        isTrue,
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
        _writeLevelDefs(fixtureRoot.path);
        _writeParallaxDefs(fixtureRoot.path);
        _writeCurrentChunkFixture(
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
        expect(first.stderr, contains('chunk_source_invalid'));
        expect(first.stderr, contains('is missing field id'));
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test('generator rejects prefab scale outside supported range', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_scale_range_',
    );
    try {
      _writePrefabAndTileDefs(fixtureRoot.path);
      _writeLevelDefs(fixtureRoot.path);
      _writeParallaxDefs(fixtureRoot.path);
      _writeCurrentChunkFixture(
        fixtureRoot.path,
        'assets/authoring/level/chunks/field/chunk_bad_scale_range.json',
        '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_bad_scale_range",
  "id": "chunk_bad_scale_range",
  "levelId": "field",
  "difficulty": "easy",
  "prefabs": [
    {
      "prefabId": "grass",
      "prefabKey": "grass",
      "x": 80,
      "y": 80,
      "zIndex": 0,
      "snapToGrid": true,
      "scale": 0.2
    }
  ]
}
''',
      );

      final result = await _runDryRun(workingDirectory: fixtureRoot.path);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('chunk_source_invalid'));
      expect(result.stderr, contains('accepted 0.3-3.0 scale in 0.1 steps'));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('generator rejects prefab scale values off 0.1 step', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_scale_step_',
    );
    try {
      _writePrefabAndTileDefs(fixtureRoot.path);
      _writeLevelDefs(fixtureRoot.path);
      _writeParallaxDefs(fixtureRoot.path);
      _writeCurrentChunkFixture(
        fixtureRoot.path,
        'assets/authoring/level/chunks/field/chunk_bad_scale_step.json',
        '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_bad_scale_step",
  "id": "chunk_bad_scale_step",
  "levelId": "field",
  "difficulty": "easy",
  "prefabs": [
    {
      "prefabId": "grass",
      "prefabKey": "grass",
      "x": 80,
      "y": 80,
      "zIndex": 0,
      "snapToGrid": true,
      "scale": 1.25
    }
  ]
}
''',
      );

      final result = await _runDryRun(workingDirectory: fixtureRoot.path);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('chunk_source_invalid'));
      expect(result.stderr, contains('accepted 0.3-3.0 scale in 0.1 steps'));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('generator writes authored runtime dart output', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_write_',
    );
    try {
      _writePrefabAndTileDefs(fixtureRoot.path);
      _writeLevelDefs(fixtureRoot.path);
      _writeParallaxDefs(fixtureRoot.path);
      _writeCurrentChunkFixture(
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
      "snapToGrid": true,
      "scale": 1.5
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
      expect(result.stdout, contains('Validated 2 level definition(s).'));

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
      expect(output, isNot(contains('SolidRel(')));
      expect(output, contains('visualSprites: <ChunkVisualSpriteRel>['));
      expect(output, contains('x: 56.0'));
      expect(output, contains('width: 48.0'));
      expect(output, contains('chancePercent: 80'));
      expect(output, contains('EnemyId.derf'));
      expect(output, isNot(contains('PlatformRel(')));
      expect(output, isNot(contains('ObstacleRel(')));
      expect(output, isNot(contains('GapRel(')));

      final stagedOutputFile = File(
        _joinPath(<String>[
          fixtureRoot.path,
          'packages',
          'runner_core',
          'lib',
          'track',
          'staged_authored_terrain.dart',
        ]),
      );
      expect(stagedOutputFile.existsSync(), isTrue);
      final stagedOutput = stagedOutputFile.readAsStringSync();
      expect(stagedOutput, contains('StagedTerrainArtifactData('));
      expect(stagedOutput, contains('authoringSeamSignatureFormat'));
      expect(stagedOutput, contains('chunkKey: "chunk_ok"'));

      final terrainMaterialsOutputFile = File(
        _joinPath(<String>[
          fixtureRoot.path,
          'lib',
          'game',
          'themes',
          'authored_terrain_materials.dart',
        ]),
      );
      expect(terrainMaterialsOutputFile.existsSync(), isTrue);
      expect(
        terrainMaterialsOutputFile.readAsStringSync(),
        contains("'grass_dirt'"),
      );

      final levelIdOutputFile = File(
        _joinPath(<String>[
          fixtureRoot.path,
          'packages',
          'runner_core',
          'lib',
          'levels',
          'level_id.dart',
        ]),
      );
      expect(levelIdOutputFile.existsSync(), isTrue);
      final levelIdOutput = levelIdOutputFile.readAsStringSync();
      expect(levelIdOutput, contains('enum LevelId { forest, field }'));

      final levelRegistryOutputFile = File(
        _joinPath(<String>[
          fixtureRoot.path,
          'packages',
          'runner_core',
          'lib',
          'levels',
          'level_registry.dart',
        ]),
      );
      expect(levelRegistryOutputFile.existsSync(), isTrue);
      final levelRegistryOutput = levelRegistryOutputFile.readAsStringSync();
      expect(
        levelRegistryOutput,
        contains(
          'defaultChunkPatternSource =\n'
          '    authoredChunkPatternSourceForLevel(LevelRegistry.defaultLevelId.name);',
        ),
      );
      expect(levelRegistryOutput, contains('case LevelId.forest:'));
      expect(levelRegistryOutput, contains('visualThemeId: \'field\''));

      final levelUiMetadataOutputFile = File(
        _joinPath(<String>[
          fixtureRoot.path,
          'lib',
          'ui',
          'levels',
          'generated_level_ui_metadata.dart',
        ]),
      );
      expect(levelUiMetadataOutputFile.existsSync(), isTrue);
      final levelUiMetadataOutput = levelUiMetadataOutputFile
          .readAsStringSync();
      expect(levelUiMetadataOutput, contains('generatedLevelUiMetadataById'));
      expect(levelUiMetadataOutput, contains("displayName: 'Forest'"));
      expect(levelUiMetadataOutput, contains('generatedSelectableLevelIds'));

      final parallaxOutputFile = File(
        _joinPath(<String>[
          fixtureRoot.path,
          'lib',
          'game',
          'themes',
          'authored_parallax_themes.dart',
        ]),
      );
      expect(parallaxOutputFile.existsSync(), isTrue);
      final parallaxOutput = parallaxOutputFile.readAsStringSync();
      expect(parallaxOutput, contains('authoredParallaxThemesById'));
      expect(parallaxOutput, isNot(contains('groundMaterialAssetPath')));
      expect(
        parallaxOutput,
        contains("assetPath: 'parallax/field/layer_01.png'"),
      );
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test(
    'generator stages multiple prefab polygons without legacy solids',
    () async {
      final fixtureRoot = await Directory.systemTemp.createTemp(
        'chunk_generator_multi_collider_',
      );
      try {
        _writeFile(
          fixtureRoot.path,
          'assets/authoring/level/prefab_defs.json',
          '''
{
  "schemaVersion": 3,
  "slices": [
    {
      "id": "rock_slice",
      "sourceImagePath": "assets/images/level/atlases/tiny_swords/ground.png",
      "x": 0,
      "y": 0,
      "width": 32,
      "height": 32
    }
  ],
  "prefabs": [
    {
      "prefabKey": "rock_stack",
      "id": "rock_stack",
      "revision": 1,
      "status": "active",
      "kind": "obstacle",
      "visualSource": {"type": "atlas_slice", "sliceId": "rock_slice"},
      "anchorXPx": 16,
      "anchorYPx": 16,
      "collisionShapes": [
        {
          "shapeId": "left",
          "collisionMode": "solid",
          "vertices": [
            {"x": -32, "y": -32},
            {"x": 0, "y": -32},
            {"x": 0, "y": 0},
            {"x": -32, "y": 0}
          ]
        },
        {
          "shapeId": "right",
          "collisionMode": "solid",
          "vertices": [
            {"x": 16, "y": -64},
            {"x": 48, "y": -64},
            {"x": 48, "y": -32},
            {"x": 16, "y": -32}
          ]
        }
      ],
      "tags": []
    }
  ]
}
''',
        );
        _writeFile(
          fixtureRoot.path,
          'assets/authoring/level/tile_defs.json',
          '''
{
  "schemaVersion": 2,
  "tileSlices": [],
  "platformModules": []
}
''',
        );
        _writeLevelDefs(fixtureRoot.path);
        _writeParallaxDefs(fixtureRoot.path);
        _writeCurrentChunkFixture(
          fixtureRoot.path,
          'assets/authoring/level/chunks/field/chunk_multi.json',
          '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_multi",
  "id": "chunk_multi",
  "levelId": "field",
  "difficulty": "easy",
  "groundProfile": {"kind": "flat", "topY": 224},
  "prefabs": [
    {
      "prefabId": "rock_stack",
      "prefabKey": "rock_stack",
      "x": 128,
      "y": 192,
      "zIndex": 0,
      "snapToGrid": true,
      "flipX": true
    }
  ]
}
''',
        );

        final result = await _runGenerate(workingDirectory: fixtureRoot.path);
        expect(result.exitCode, 0, reason: result.stderr);

        final output = File(
          _joinPath(<String>[
            fixtureRoot.path,
            'packages',
            'runner_core',
            'lib',
            'track',
            'authored_chunk_patterns.dart',
          ]),
        ).readAsStringSync();

        final stagedOutput = File(
          _joinPath(<String>[
            fixtureRoot.path,
            'packages',
            'runner_core',
            'lib',
            'track',
            'staged_authored_terrain.dart',
          ]),
        ).readAsStringSync();

        expect(output, contains('chunk_multi'));
        expect(output, isNot(contains('SolidRel(')));
        expect(stagedOutput, contains('shapeId: "left"'));
        expect(stagedOutput, contains('shapeId: "right"'));
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test(
    'generator stages scaled flipped one-way polygons without projection',
    () async {
      final fixtureRoot = await Directory.systemTemp.createTemp(
        'chunk_generator_platform_flip_scale_',
      );
      try {
        _writeFile(
          fixtureRoot.path,
          'assets/authoring/level/prefab_defs.json',
          '''
{
  "schemaVersion": 3,
  "slices": [
    {
      "id": "bridge_slice",
      "sourceImagePath": "assets/images/level/atlases/tiny_swords/ground.png",
      "x": 0,
      "y": 0,
      "width": 32,
      "height": 32
    }
  ],
  "prefabs": [
    {
      "prefabKey": "bridge_stack",
      "id": "bridge_stack",
      "revision": 1,
      "status": "active",
      "kind": "platform",
      "visualSource": {"type": "atlas_slice", "sliceId": "bridge_slice"},
      "anchorXPx": 16,
      "anchorYPx": 16,
      "collisionShapes": [
        {
          "shapeId": "first",
          "collisionMode": "oneWay",
          "vertices": [
            {"x": -32, "y": -32},
            {"x": 0, "y": -32},
            {"x": 0, "y": 0},
            {"x": -32, "y": 0}
          ]
        },
        {
          "shapeId": "second",
          "collisionMode": "oneWay",
          "vertices": [
            {"x": 0, "y": -48},
            {"x": 32, "y": -48},
            {"x": 32, "y": -16},
            {"x": 0, "y": -16}
          ]
        }
      ],
      "tags": []
    }
  ]
}
''',
        );
        _writeFile(
          fixtureRoot.path,
          'assets/authoring/level/tile_defs.json',
          '''
{
  "schemaVersion": 2,
  "tileSlices": [],
  "platformModules": []
}
''',
        );
        _writeLevelDefs(fixtureRoot.path);
        _writeParallaxDefs(fixtureRoot.path);
        _writeCurrentChunkFixture(
          fixtureRoot.path,
          'assets/authoring/level/chunks/field/chunk_platform_flip_scale.json',
          '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_platform_flip_scale",
  "id": "chunk_platform_flip_scale",
  "levelId": "field",
  "difficulty": "easy",
  "groundProfile": {"kind": "flat", "topY": 224},
  "prefabs": [
    {
      "prefabId": "bridge_stack",
      "prefabKey": "bridge_stack",
      "x": 160,
      "y": 160,
      "zIndex": 0,
      "snapToGrid": true,
      "scale": 2.0,
      "flipX": true,
      "flipY": true
    }
  ]
}
''',
        );

        final result = await _runGenerate(workingDirectory: fixtureRoot.path);
        expect(result.exitCode, 0, reason: result.stderr);

        final output = File(
          _joinPath(<String>[
            fixtureRoot.path,
            'packages',
            'runner_core',
            'lib',
            'track',
            'authored_chunk_patterns.dart',
          ]),
        ).readAsStringSync();

        final stagedOutput = File(
          _joinPath(<String>[
            fixtureRoot.path,
            'packages',
            'runner_core',
            'lib',
            'track',
            'staged_authored_terrain.dart',
          ]),
        ).readAsStringSync();

        expect(output, contains('chunk_platform_flip_scale'));
        expect(output, isNot(contains('SolidRel(')));
        expect(stagedOutput, contains('shapeId: "first"'));
        expect(stagedOutput, contains('shapeId: "second"'));
        expect(
          'StagedTerrainCollisionMode.oneWay'.allMatches(stagedOutput).length,
          greaterThanOrEqualTo(2),
        );
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test('generator emits assembly metadata into runtime outputs', () async {
    final fixtureRoot = await Directory.systemTemp.createTemp(
      'chunk_generator_assembly_',
    );
    try {
      _writePrefabAndTileDefs(fixtureRoot.path);
      _writeLevelDefsWithAssembly(fixtureRoot.path);
      _writeParallaxDefs(fixtureRoot.path);
      _writeCurrentChunkFixture(
        fixtureRoot.path,
        'assets/authoring/level/chunks/field/chunk_ok.json',
        '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_ok",
  "id": "chunk_ok",
  "levelId": "field",
  "difficulty": "easy",
  "assemblyGroupId": "cemetery"
}
''',
      );

      final result = await _runGenerate(workingDirectory: fixtureRoot.path);
      expect(result.exitCode, 0, reason: result.stderr);

      final chunkOutput = File(
        _joinPath(<String>[
          fixtureRoot.path,
          'packages',
          'runner_core',
          'lib',
          'track',
          'authored_chunk_patterns.dart',
        ]),
      ).readAsStringSync();
      expect(chunkOutput, contains("assemblyGroupId: 'cemetery'"));
      expect(
        chunkOutput,
        contains('ChunkPatternListSource authoredChunkPatternSourceForLevel('),
      );
      expect(chunkOutput, isNot(contains('AssembledChunkPatternSource(')));
      expect(chunkOutput, isNot(contains('LevelAssemblyDefinition? assembly')));

      final levelRegistryOutput = File(
        _joinPath(<String>[
          fixtureRoot.path,
          'packages',
          'runner_core',
          'lib',
          'levels',
          'level_registry.dart',
        ]),
      ).readAsStringSync();
      expect(levelRegistryOutput, contains("import 'level_assembly.dart';"));
      expect(levelRegistryOutput, contains('LevelAssemblyDefinition('));
      expect(levelRegistryOutput, contains('LevelAssemblySegment('));
      expect(
        levelRegistryOutput,
        isNot(contains('LevelAssemblyRenderThemeMode')),
      );
      expect(
        RegExp(r'assembly: const LevelAssemblyDefinition\(')
            .allMatches(levelRegistryOutput)
            .length,
        1,
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
        _writeLevelDefs(fixtureRoot.path);
        _writeParallaxDefs(fixtureRoot.path);
        _writeCurrentChunkFixture(
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

void _writeValidSmokeFixture(String rootPath) {
  _writePrefabAndTileDefs(rootPath);
  _writeLevelDefs(rootPath);
  _writeParallaxDefs(rootPath);
  _writeCurrentChunkFixture(
    rootPath,
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
}

Future<ProcessResult> _runCompiledRegistryProbe(
  String rootPath,
  String checks,
) async {
  final coreSource = Directory('packages/runner_core/lib').absolute;
  final fixtureCore = Directory(
    _joinPath(<String>[rootPath, 'packages/runner_core/lib']),
  );
  for (final entity in coreSource.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = entity.path.substring(coreSource.path.length + 1);
    final target = File(_joinPath(<String>[fixtureCore.path, relative]));
    if (target.existsSync()) continue;
    target.parent.createSync(recursive: true);
    entity.copySync(target.path);
  }
  final configFile = File('.dart_tool/package_config.json').absolute;
  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, Object?>;
  for (final entry in config['packages'] as List<Object?>) {
    final package = entry as Map<String, Object?>;
    package['rootUri'] = package['name'] == 'runner_core'
        ? fixtureCore.parent.uri.toString()
        : configFile.uri.resolve(package['rootUri'] as String).toString();
  }
  _writeFile(rootPath, '.dart_tool/package_config.json', jsonEncode(config));
  _writeFile(rootPath, 'registry_probe.dart', '''
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/levels/level_availability.dart';
void main() {
$checks
}
''');
  return Process.run(_resolveDartExecutable(), <String>[
    'registry_probe.dart',
  ], workingDirectory: rootPath);
}

void _updateLevelSource(
  String rootPath,
  void Function(Map<String, Object?>) mutate,
) {
  final path = _joinPath(<String>[
    rootPath,
    'assets/authoring/level/level_defs.json',
  ]);
  final file = File(path);
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  for (final entry in decoded['levels'] as List<Object?>) {
    mutate(entry as Map<String, Object?>);
  }
  final parsed = level_source.decodeLevelDefinitions(
    jsonEncode(decoded),
    defsPath: path,
  );
  expect(
    parsed.issues.where((issue) => issue.code != 'non_canonical_level_defs'),
    isEmpty,
  );
  file.writeAsStringSync(
    level_source.renderCanonicalLevelDefsJson(parsed.levels),
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
  "schemaVersion": 3,
  "slices": [
    {
      "id": "grass_slice",
      "sourceImagePath": "assets/images/level/atlases/tiny_swords/ground.png",
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
      "collisionShapes": [],
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

void _writeTerrainMaterialDefs(String rootPath) {
  _writeFile(rootPath, 'assets/authoring/level/terrain_material_defs.json', '''
{
  "schemaVersion": 3,
  "materials": [
    {
      "key": "grass_dirt",
      "displayName": "Grass / Dirt",
      "revision": 1,
      "fill": {
        "assetPath": "assets/images/level/atlases/tiny_swords/ground.png",
        "x": 32,
        "y": 32,
        "width": 32,
        "height": 32
      },
      "top": {
        "base": {
          "region": {
            "assetPath": "assets/images/level/atlases/tiny_swords/ground.png",
            "x": 32,
            "y": 0,
            "width": 32,
            "height": 32
          },
          "anchorY": 12
        }
      }
    }
  ]
}
''');
  for (final path in const <String>[
    'assets/images/level/atlases/tiny_swords/ground.png',
  ]) {
    final source = File(
      _joinPath(<String>[Directory.current.path, ...path.split('/')]),
    );
    final destination = File(_joinPath(<String>[rootPath, ...path.split('/')]))
      ..parent.createSync(recursive: true);
    source.copySync(destination.path);
  }
}

void _writeLevelDefs(String rootPath) {
  _writeFile(rootPath, 'assets/authoring/level/level_defs.json', '''
{
  "schemaVersion": 2,
  "levels": [
    {
      "levelId": "field",
      "revision": 1,
      "displayName": "Field",
      "visualThemeId": "field",
      "chunkThemeGroups": ["default"],
      "cameraCenterY": 135,
      "groundTopY": 224,
      "earlyPatternChunks": 3,
      "easyPatternChunks": 0,
      "normalPatternChunks": 0,
      "noEnemyChunks": 3,
      "enumOrdinal": 20,
      "includeInBuild": true,
      "status": "active"
    },
    {
      "levelId": "forest",
      "revision": 1,
      "displayName": "Forest",
      "visualThemeId": "forest",
      "chunkThemeGroups": ["default"],
      "cameraCenterY": 135,
      "groundTopY": 224,
      "earlyPatternChunks": 3,
      "easyPatternChunks": 0,
      "normalPatternChunks": 0,
      "noEnemyChunks": 3,
      "enumOrdinal": 10,
      "includeInBuild": false,
      "status": "active"
    }
  ]
}
''');
}

void _writeLevelDefsWithAssembly(String rootPath) {
  _writeFile(rootPath, 'assets/authoring/level/level_defs.json', '''
{
  "schemaVersion": 2,
  "levels": [
    {
      "levelId": "field",
      "revision": 1,
      "displayName": "Field",
      "visualThemeId": "field",
      "chunkThemeGroups": ["default", "cemetery"],
      "cameraCenterY": 135,
      "groundTopY": 224,
      "earlyPatternChunks": 3,
      "easyPatternChunks": 0,
      "normalPatternChunks": 0,
      "noEnemyChunks": 3,
      "enumOrdinal": 20,
      "includeInBuild": true,
      "status": "active",
      "assembly": {
        "loopSegments": true,
        "segments": [
          {
            "segmentId": "cemetery_run",
            "groupId": "cemetery",
            "minChunkCount": 2,
            "maxChunkCount": 5,
            "requireDistinctChunks": false
          }
        ]
      }
    },
    {
      "levelId": "forest",
      "revision": 1,
      "displayName": "Forest",
      "visualThemeId": "forest",
      "chunkThemeGroups": ["default"],
      "cameraCenterY": 135,
      "groundTopY": 224,
      "earlyPatternChunks": 3,
      "easyPatternChunks": 0,
      "normalPatternChunks": 0,
      "noEnemyChunks": 3,
      "enumOrdinal": 10,
      "includeInBuild": false,
      "status": "active"
    }
  ]
}
''');
}

void _writeParallaxDefs(String rootPath) {
  _writeFile(rootPath, 'assets/authoring/level/parallax_defs.json', '''
{
  "schemaVersion": 2,
  "themes": [
    {
      "parallaxThemeId": "field",
      "revision": 1,
      "layers": [
        {
          "layerKey": "field_bg_01",
          "assetPath": "assets/images/parallax/field/layer_01.png",
          "group": "background",
          "parallaxFactor": 0.1,
          "zOrder": 10,
          "opacity": 1,
          "yOffset": 0
        },
        {
          "layerKey": "field_fg_10",
          "assetPath": "assets/images/parallax/field/layer_10.png",
          "group": "foreground",
          "parallaxFactor": 1,
          "zOrder": 10,
          "opacity": 1,
          "yOffset": 0
        }
      ]
    },
    {
      "parallaxThemeId": "forest",
      "revision": 1,
      "layers": [
        {
          "layerKey": "forest_bg_01",
          "assetPath": "assets/images/parallax/forest/layer_01.png",
          "group": "background",
          "parallaxFactor": 0.1,
          "zOrder": 10,
          "opacity": 1,
          "yOffset": 0
        },
        {
          "layerKey": "forest_fg_10",
          "assetPath": "assets/images/parallax/forest/layer_10.png",
          "group": "foreground",
          "parallaxFactor": 1,
          "zOrder": 10,
          "opacity": 1,
          "yOffset": 0
        }
      ]
    }
  ]
}
''');

  for (final relativePath in <String>[
    'assets/images/parallax/field/layer_01.png',
    'assets/images/parallax/field/layer_09.png',
    'assets/images/parallax/field/layer_10.png',
    'assets/images/parallax/forest/layer_01.png',
    'assets/images/parallax/forest/layer_09.png',
    'assets/images/parallax/forest/layer_10.png',
  ]) {
    _writeFile(rootPath, relativePath, '');
  }
}

void _writeParallaxDefsWithGeneratedSymbolCollision(String rootPath) {
  _writeFile(rootPath, 'assets/authoring/level/parallax_defs.json', '''
{
  "schemaVersion": 2,
  "themes": [
    {
      "parallaxThemeId": "field",
      "revision": 1,
      "layers": []
    },
    {
      "parallaxThemeId": "field_",
      "revision": 1,
      "layers": []
    },
    {
      "parallaxThemeId": "forest",
      "revision": 1,
      "layers": []
    }
  ]
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

void _writeCurrentChunkFixture(
  String rootPath,
  String relativePath,
  String legacyContent,
) {
  _writeTerrainMaterialDefs(rootPath);
  final decoded = jsonDecode(legacyContent) as Map<String, Object?>;
  decoded['schemaVersion'] = 2;
  decoded.putIfAbsent('revision', () => 1);
  decoded.putIfAbsent('status', () => 'active');
  decoded.putIfAbsent('tileSize', () => 16);
  decoded.putIfAbsent('width', () => 600);
  decoded.putIfAbsent('height', () => 270);
  decoded.putIfAbsent('assemblyGroupId', () => 'default');
  decoded.putIfAbsent('tags', () => <Object?>[]);
  decoded.putIfAbsent('tileLayers', () => <Object?>[]);
  decoded.putIfAbsent('prefabs', () => <Object?>[]);
  decoded.putIfAbsent('markers', () => <Object?>[]);
  decoded.putIfAbsent('collisionShapes', () => <Object?>[]);
  decoded.remove('groundProfile');
  decoded.remove('groundGaps');
  _writeFile(
    rootPath,
    relativePath,
    '${const JsonEncoder.withIndent('  ').convert(decoded)}\n',
  );
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
