import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_presentation/catalog_item.dart';
import 'package:lothringen_admin/src/admin_controller.dart';
import 'package:lothringen_admin/src/admin_page.dart';
import 'package:lothringen_admin/src/repository_assets.dart';
import 'package:tool_ui/tool_ui.dart';

import 'admin_controller_test.dart' show MemoryStore, TestService;

class CatalogService extends TestService {
  final fixture = jsonDecode(
    File('test/fixtures/catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  @override
  Future<Map<String, dynamic>> call(
    String path, [
    Map<String, Object?>? body,
  ]) async => path == '/api/catalog'
      ? {
          ...fixture,
          'environment': body!['environment'],
          'projectId': 'project-${body['environment']}',
        }
      : super.call(path, body);
}

void main() {
  testWidgets(
    'shared catalog renders canonical artwork; compose, preview and send at wide and narrow widths',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AdminController(
        service: CatalogService(),
        store: MemoryStore(),
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.selectEnvironment('dev');
      final repository = Directory.current.parent.parent.path;
      final bundle = RepositoryAssets(repository);
      final boundary = GlobalKey();
      await tester.runAsync(() async {
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        final font = File('C:/Windows/Fonts/segoeui.ttf');
        if (await font.exists()) {
          await (FontLoader(
            'Roboto',
          )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
        }
      });
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: bundle,
          child: MaterialApp(
            theme: createToolTheme(),
            home: RepaintBoundary(
              key: boundary,
              child: AdminPage(controller: c),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('player-uid')),
        'fixture-player',
      );
      await tester.enterText(
        find.byKey(const Key('message-title')),
        'A gift for your next run',
      );
      await tester.enterText(
        find.byKey(const Key('message-body')),
        'New equipment and a skill are waiting in your inbox.',
      );
      await tester.enterText(find.byKey(const Key('gold')), '1000');
      final item = c.catalog.firstWhere((e) => e.itemId == 'waspfang');
      await tester.tap(find.text(item.displayName));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('catalog-search')),
        'arcane_ward',
      );
      await tester.pump();
      final skill = c.catalog.firstWhere(
        (e) => e.itemId == 'eloise.arcane_ward',
      );
      await tester.tap(find.text(skill.displayName));
      await tester.pump();
      expect(c.draft.attachments.length, 2);
      await tester.tap(find.byKey(const Key('preview')));
      await tester.pumpAndSettle();
      expect(c.error, isNull);
      expect(find.byKey(const Key('send')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('catalog-search')), '');
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
      }
      expect(
        tester
            .renderObjectList<RenderImage>(find.byType(RawImage))
            .every((image) => image.image != null),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('$repository/build/admin-proof/admin-wide.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.byKey(const Key('send')));
      await tester.pumpAndSettle();
      expect(find.text('Delivery confirmed'), findsOneWidget);
      tester.view.physicalSize = const Size(600, 900);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tool_three_panel_narrow')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(Tab, 'Compose'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player-uid')), findsOneWidget);
    },
  );
  testWidgets(
    'every backend catalog entry resolves through shared Core presentation and repository assets',
    (tester) async {
      final rows = CatalogService().fixture['entries'] as List;
      final bundle = RepositoryAssets(Directory.current.parent.parent.path);
      for (final raw in rows) {
        final item = GameCatalogItem.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        expect(item.displayName, isNotEmpty);
        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: bundle,
            child: MaterialApp(home: Center(child: item.icon())),
          ),
        );
        for (var i = 0; i < 100; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          });
          await tester.pump();
          final images = tester.renderObjectList<RenderImage>(
            find.byType(RawImage),
          );
          if (images.isNotEmpty &&
              images.every((image) => image.image != null)) {
            break;
          }
        }
        for (final image in tester.renderObjectList<RenderImage>(
          find.byType(RawImage),
        )) {
          expect(image.image, isNotNull, reason: item.key);
        }
        expect(tester.takeException(), isNull, reason: item.key);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      await expectLater(
        bundle.load('assets/images/../secret'),
        throwsFormatException,
      );
    },
  );
}
