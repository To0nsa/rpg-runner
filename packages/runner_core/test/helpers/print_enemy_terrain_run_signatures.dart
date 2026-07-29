import 'dart:convert';
import 'dart:io';

import 'package:runner_core/snapshots/enemy_terrain_signatures.dart';

import '../fixtures/enemy_terrain_run_fixture.dart';

void main() {
  final fixture = buildEnemyTerrainRunFixture();
  stdout.writeln(
    jsonEncode(<String, String>{
      'slopes_golden_nav_surfaces_v1.sha256': fixture.surfaceSignature,
      'slopes_golden_nav_graphs_v1.sha256': fixture.graphSignature,
      'slopes_golden_enemy_terrain_run_v1.sha256': enemyTerrainRunSignatureV1(
        fixture,
      ),
    }),
  );
}
