import 'dart:io';

import 'generated_artifact_plan.dart';
import 'terrain_material_generation.dart';

Future<void> main(List<String> args) async {
  final showHelp = args.contains('-h') || args.contains('--help');
  if (showHelp) {
    stdout.writeln(
      'Usage: dart run tool/generate_terrain_material_registry.dart '
      '[--dry-run]',
    );
    return;
  }
  final unknown = args.where((arg) => arg != '--dry-run').toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown argument(s): ${unknown.join(', ')}');
    exitCode = 64;
    return;
  }

  final result = await buildTerrainMaterialRegistry();
  if (result.issues.isNotEmpty) {
    for (final issue in result.issues) {
      stderr.writeln('[ERROR] ${issue.code} ${issue.path}: ${issue.message}');
    }
    exitCode = 1;
    return;
  }
  final output = result.output!;
  final plan = GeneratedArtifactPlan(<GeneratedArtifact>[output]);
  if (args.contains('--dry-run')) {
    final drift = await plan.inspectDrift();
    if (drift.isNotEmpty) {
      for (final item in drift) {
        stderr.writeln('[ERROR] ${item.code} ${item.path}: ${item.message}');
      }
      exitCode = 1;
      return;
    }
    stdout.writeln('Terrain material registry is current.');
    return;
  }
  await plan.writeAll();
  stdout.writeln(
    'Generated ${output.path} '
    '(${result.catalog!.materials.length} material(s)).',
  );
}
