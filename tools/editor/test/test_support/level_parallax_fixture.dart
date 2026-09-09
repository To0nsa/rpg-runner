import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';

Future<EditorSessionController> createLevelParallaxTestSession(
  AuthoringDomainPlugin plugin,
) async {
  final root = await Directory.systemTemp.createTemp('level_parallax_history_');
  addTearDown(() async {
    // Widget image reads can still be closing when teardown starts on Windows.
    // Retry only that sharing violation; every other cleanup failure is real.
    for (var attempt = 0; ; attempt++) {
      try {
        await root.delete(recursive: true);
        return;
      } on FileSystemException catch (error) {
        if (error.osError?.errorCode != 32 || attempt >= 10) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });
  void write(String sourcePath, String contents) {
    final file = File(p.join(root.path, sourcePath));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  write(
    levelDefsSourcePath,
    renderCanonicalLevelDefsJson(<LevelDef>[
      for (final (id, ordinal) in const <(String, int)>[
        ('field', 10),
        ('forest', 20),
      ])
        LevelDef(
          levelId: id,
          revision: 1,
          displayName: titleCaseLevelId(id),
          visualThemeId: id,
          cameraCenterY: 135,
          groundTopY: 224,
          earlyPatternChunks: 3,
          easyPatternChunks: 0,
          normalPatternChunks: 0,
          noEnemyChunks: 3,
          enumOrdinal: ordinal,
          status: levelStatusActive,
        ),
    ]),
  );
  write(
    parallaxDefsSourcePath,
    renderCanonicalParallaxDefsJson(const <ParallaxThemeDef>[
      ParallaxThemeDef(
        parallaxThemeId: 'field',
        revision: 1,
        layers: <ParallaxLayerDef>[
          ParallaxLayerDef(
            layerKey: 'field_bg',
            assetPath: 'assets/images/parallax/field/layer_01.png',
            group: parallaxGroupBackground,
            parallaxFactor: 0.5,
            zOrder: 10,
            opacity: 1,
            yOffset: 0,
          ),
        ],
      ),
      ParallaxThemeDef(
        parallaxThemeId: 'forest',
        revision: 1,
        layers: <ParallaxLayerDef>[],
      ),
    ]),
  );
  final image = File(
    p.join(root.path, 'assets/images/parallax/field/layer_01.png'),
  );
  image.parent.createSync(recursive: true);
  image.writeAsBytesSync(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aQ1sAAAAASUVORK5CYII=',
    ),
  );
  final controller = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: <AuthoringDomainPlugin>[plugin],
    ),
    initialPluginId: plugin.id,
    initialWorkspacePath: root.path,
  );
  addTearDown(controller.dispose);
  await controller.loadWorkspace();
  expect(controller.loadError, isNull);
  return controller;
}
