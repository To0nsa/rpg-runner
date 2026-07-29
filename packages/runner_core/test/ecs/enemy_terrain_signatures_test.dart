import 'dart:convert';
import 'dart:io';

import 'package:runner_core/snapshots/enemy_terrain_signatures.dart';
import 'package:test/test.dart';

import '../fixtures/enemy_terrain_run_fixture.dart';

void main() {
  test('enemy terrain run is complete, canonical, and reviewed', () {
    final first = buildEnemyTerrainRunFixture();
    final second = buildEnemyTerrainRunFixture();
    final permuted = buildEnemyTerrainRunFixture(reverseInputOrder: true);
    final collectionPermuted = _reverseCollections(first);
    final firstRecords = enemyTerrainRunCanonicalRecordsV1(first);

    expect(
      first.scenarios.map((scenario) => scenario.scenarioId).toSet(),
      <String>{
        for (var index = 1; index <= 15; index += 1)
          'SG-E${index.toString().padLeft(2, '0')}',
      },
    );
    expect(enemyTerrainRunCanonicalRecordsV1(second), firstRecords);
    expect(enemyTerrainRunCanonicalRecordsV1(permuted), firstRecords);
    expect(enemyTerrainRunCanonicalRecordsV1(collectionPermuted), firstRecords);
    expect(permuted.surfaceSignature, first.surfaceSignature);
    expect(permuted.graphSignature, first.graphSignature);

    expect(firstRecords.first, contains('enemy-terrain-run-v1'));
    expect(
      firstRecords.where(
        (record) => record.contains('enemy-terrain-scenario-v1'),
      ),
      hasLength(15),
    );
    expect(
      firstRecords.any((record) => RegExp(r'[-+]?\d+\.\d+').hasMatch(record)),
      isFalse,
      reason: 'signature numeric fields must be canonical integers',
    );

    expect(
      first.surfaceSignature,
      _golden('slopes_golden_nav_surfaces_v1.sha256'),
    );
    expect(first.graphSignature, _golden('slopes_golden_nav_graphs_v1.sha256'));
    expect(
      enemyTerrainRunSignatureV1(first),
      _golden('slopes_golden_enemy_terrain_run_v1.sha256'),
    );
  });

  test('scenario outcomes participate in the run digest', () {
    final fixture = buildEnemyTerrainRunFixture();
    final original = fixture.scenarios.first;
    final changedScenario = EnemyTerrainScenarioSignatureInput(
      scenarioId: original.scenarioId,
      fixtureId: original.fixtureId,
      seed: original.seed,
      actorProfiles: original.actorProfiles,
      schedule: original.schedule,
      checkpoints: original.checkpoints,
      outcomes: <EnemyTerrainOutcomeSignatureRecord>[
        ...original.outcomes,
        const EnemyTerrainOutcomeSignatureRecord(
          key: 'intentional-mutation',
          value: 1,
        ),
      ],
      legacyDisposition: original.legacyDisposition,
    );
    final changed = EnemyTerrainRunSignatureInput(
      surfaceSignature: fixture.surfaceSignature,
      graphSignature: fixture.graphSignature,
      scenarios: <EnemyTerrainScenarioSignatureInput>[
        changedScenario,
        ...fixture.scenarios.skip(1),
      ],
    );

    expect(
      enemyTerrainRunSignatureV1(changed),
      isNot(enemyTerrainRunSignatureV1(fixture)),
    );
  });

  test('incomplete matrices are rejected', () {
    final fixture = buildEnemyTerrainRunFixture();
    expect(
      () => enemyTerrainRunSignatureV1(
        EnemyTerrainRunSignatureInput(
          surfaceSignature: fixture.surfaceSignature,
          graphSignature: fixture.graphSignature,
          scenarios: fixture.scenarios.take(14).toList(),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('phase 3 signatures repeat in fresh Dart processes', () {
    Map<String, dynamic> runHelper() {
      final process = Process.runSync(Platform.resolvedExecutable, <String>[
        'run',
        'test/helpers/print_enemy_terrain_run_signatures.dart',
      ], workingDirectory: Directory.current.path);
      expect(process.exitCode, 0, reason: process.stderr.toString());
      return jsonDecode(process.stdout.toString()) as Map<String, dynamic>;
    }

    final first = runHelper();
    final second = runHelper();
    for (final key in const <String>[
      'slopes_golden_nav_surfaces_v1.sha256',
      'slopes_golden_nav_graphs_v1.sha256',
      'slopes_golden_enemy_terrain_run_v1.sha256',
    ]) {
      expect(second[key], first[key], reason: key);
      expect(first[key], _golden(key), reason: key);
    }
  });
}

String _golden(String name) =>
    File('test/fixtures/goldens/$name').readAsStringSync().trim();

EnemyTerrainRunSignatureInput _reverseCollections(
  EnemyTerrainRunSignatureInput input,
) => EnemyTerrainRunSignatureInput(
  surfaceSignature: input.surfaceSignature,
  graphSignature: input.graphSignature,
  scenarios: <EnemyTerrainScenarioSignatureInput>[
    for (final scenario in input.scenarios.reversed)
      EnemyTerrainScenarioSignatureInput(
        scenarioId: scenario.scenarioId,
        fixtureId: scenario.fixtureId,
        seed: scenario.seed,
        actorProfiles: scenario.actorProfiles.reversed.toList(),
        schedule: scenario.schedule.reversed.toList(),
        checkpoints: scenario.checkpoints.reversed.toList(),
        outcomes: scenario.outcomes.reversed.toList(),
        legacyDisposition: scenario.legacyDisposition,
      ),
  ],
);
