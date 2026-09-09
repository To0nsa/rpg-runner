import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/domain/authoring_dependency_repair.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_store.dart';
import 'package:runner_editor/src/terrain_authoring/polygon_authoring_migration_required.dart';
import 'package:runner_editor/src/terrain_materials/terrain_material_store.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  late EditorWorkspace workspace;
  setUp(() async {
    final root = await Directory.systemTemp.createTemp('repair_source_');
    addTearDown(() => root.deleteSync(recursive: true));
    workspace = EditorWorkspace(rootPath: root.path);
  });

  test(
    'unreadable, missing and wrong-schema sources never suspend the origin',
    () async {
      for (final raw in <String?>[
        null,
        '{',
        '{"schemaVersion":1,"themes":[]}',
        '{"schemaVersion":2,"themes":12}',
      ]) {
        if (raw != null) _write(workspace, parallaxDefsSourcePath, raw);
        final document = await const ParallaxStore().load(workspace);
        expect(
          isDependencyRepairSourceReadable(document),
          isFalse,
          reason: raw ?? 'missing',
        );
      }
      for (final raw in <String?>[
        null,
        '{',
        '{"schemaVersion":3,"materials":12}',
      ]) {
        if (raw != null) {
          _write(
            workspace,
            'assets/authoring/level/terrain_material_defs.json',
            raw,
          );
        }
        final document = await const TerrainMaterialStore().load(workspace);
        expect(
          isDependencyRepairSourceReadable(document),
          isFalse,
          reason: raw ?? 'missing',
        );
      }
      expect(
        isDependencyRepairSourceReadable(
          const PolygonAuthoringMigrationRequiredDocument(
            domain: PolygonAuthoringMigrationDomain.chunks,
            reason: PolygonAuthoringMigrationReason.legacySource,
          ),
        ),
        isFalse,
      );
    },
  );

  test('readable source with repairable layer values and missing images is admitted', () async {
    _write(
      workspace,
      parallaxDefsSourcePath,
      renderCanonicalParallaxDefsJson([
        const ParallaxThemeDef(
          parallaxThemeId: 'forest',
          revision: 1,
          layers: [
            ParallaxLayerDef(
              layerKey: 'sky',
              assetPath: 'assets/images/parallax/forest/layer_01.png',
              group: parallaxGroupBackground,
              parallaxFactor: 3,
              zOrder: 0,
              opacity: 1,
              yOffset: 0,
            ),
          ],
        ),
      ]),
    );
    final plugin = ParallaxDomainPlugin();
    final document = await plugin.loadFromRepo(workspace);
    expect(
      plugin
          .validate(document)
          .any((issue) => issue.blocks(AuthoringOperation.save)),
      isTrue,
    );
    expect(isDependencyRepairSourceReadable(document), isTrue);
  });
}

void _write(EditorWorkspace workspace, String path, String contents) {
  final file = File(workspace.resolve(path));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}
