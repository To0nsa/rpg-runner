import 'dart:io';

import 'package:runner_content_pipeline/item_source.dart';

import 'content_build_report.dart';
import 'generated_artifact_plan.dart';
import 'item_generation.dart';
import 'generate_backend_catalog.dart' as backend;

/// Focused offline item build. The shell includes the same plan in its full Build.
Future<void> main(List<String> args) async {
  if (args.any((arg) => arg != '--check')) {
    stderr.writeln('Usage: dart run tool/generate_item_data.dart [--check]');
    exitCode = 64;
    return;
  }
  try {
    final snapshot = await ContentBuildSnapshot.capture();
    final catalog = ItemCatalogSource.decode(
      snapshot.readString(itemSourcePath),
    );
    final plan = GeneratedArtifactPlan([
      ...buildItemArtifacts(catalog),
      GeneratedArtifact(
        path: backend.backendCatalogPath,
        content: backend.renderBackendCatalog(authoredItems: catalog.items),
      ),
    ]);
    final drift = await plan.inspectDrift();
    await snapshot.verifyCurrent();
    if (args.contains('--check')) {
      for (final d in drift) {
        stderr.writeln('${d.code}: ${d.path}');
      }
      if (drift.isNotEmpty) exitCode = 1;
    } else if (drift.isNotEmpty) {
      await plan.writeAll(beforeReplacement: snapshot.verifyCurrent);
      await snapshot.verifyCurrent();
    }
  } on Object catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  }
}
