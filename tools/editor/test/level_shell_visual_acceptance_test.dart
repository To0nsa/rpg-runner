import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/runner_editor_app.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_composition_preview.dart';
import 'package:runner_editor/src/build/content_build_process.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_materials/terrain_material_domain_plugin.dart';

// Opt-in raster acceptance uses the actual repository and native font assets.
// Set LEVEL_EDITOR_SCREENSHOT_DIR and redirect LOCALAPPDATA to a temporary
// directory so convenience-view persistence cannot affect a developer profile.
void main() {
  final output = Platform.environment['LEVEL_EDITOR_SCREENSHOT_DIR'];
  testWidgets(
    'actual Level shell desktop and text-scale visual matrix',
    (tester) async {
      final root = p.normalize(p.absolute('..', '..'));
      expect(
        p.isWithin(
          p.join(root, '.tmp'),
          Platform.environment['LOCALAPPDATA'] ?? '',
        ),
        isTrue,
        reason: 'Redirect LOCALAPPDATA beneath the repository .tmp directory for this opt-in acceptance run.',
      );
      final boundary = GlobalKey();
      await tester.runAsync(() async {
        final dart = await resolveContentBuildDartExecutable();
        final fonts = p.join(
          File(dart).parent.parent.parent.path,
          'artifacts',
          'material_fonts',
        );
        for (final (family, name) in [
          ('Roboto', 'roboto-regular.ttf'),
          ('MaterialIcons', 'materialicons-regular.otf'),
        ]) {
          final loader = FontLoader(family)
            ..addFont(
              File(p.join(fonts, name))
                  .readAsBytes()
                  .then(ByteData.sublistView),
            );
          await loader.load();
        }
        final windowsFont = FontLoader('Segoe UI')
          ..addFont(
            File(
              p.join(
                Platform.environment['WINDIR'] ?? 'C:/Windows',
                'Fonts',
                'segoeui.ttf',
              ),
            ).readAsBytes().then(ByteData.sublistView),
          );
        await windowsFont.load();
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: [
            EntityDomainPlugin(),
            PrefabDomainPlugin(),
            ChunkDomainPlugin(),
            LevelDomainPlugin(),
            ParallaxDomainPlugin(),
            TerrainMaterialDomainPlugin(),
          ],
        ),
        initialPluginId: LevelDomainPlugin.pluginId,
        initialWorkspacePath: root,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: RunnerEditorApp(controller: controller),
        ),
      );
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(ChunkCompositionPreview).evaluate().isNotEmpty &&
            _loadedImages(tester) > 0) {
          break;
        }
      }
      expect(find.byType(ChunkCompositionPreview), findsWidgets);
      expect(_loadedImages(tester), greaterThan(0));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('level_play_button')),
            )
            .onPressed,
        isNotNull,
      );
      final failures = <String>[];
      for (final size in const [
        Size(1440, 900),
        Size(1280, 800),
        Size(1024, 768),
        Size(800, 600),
      ]) {
        for (final scale in [1.0, 1.25, 1.5]) {
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pump();
          for (var i = 0; i < 4; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 80)),
            );
            await tester.pump(const Duration(milliseconds: 80));
          }
          final name =
              'level-shell-${size.width.toInt()}x${size.height.toInt()}-text-$scale';
          if (tester.takeException() case final Object error) {
            failures.add('$name: $error');
          }
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            try {
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(output!).create(recursive: true);
              await File(p.join(output, '$name.png'))
                  .writeAsBytes(png!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('level_workspace_tabs')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Contents').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Flow').hitTestable());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Settings').hitTestable());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('level_input_displayName')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
    skip: output == null,
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}

int _loadedImages(WidgetTester tester) {
  var count = 0;
  for (final paint in tester.widgetList<CustomPaint>(
    find.byType(CustomPaint),
  )) {
    if (paint.painter.runtimeType.toString() ==
        '_ChunkPolygonLevelVisualPainter') {
      final dynamic painter = paint.painter;
      count += painter.loadedImageCount as int;
    }
  }
  return count;
}
