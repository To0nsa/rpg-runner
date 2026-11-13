import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_chapter_dialog.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';
import 'package:rpg_runner/ui/components/map_location_layer.dart';

void main() {
  final workspace = EditorWorkspace(
    rootPath: Directory.current.parent.parent.path,
  );
  final catalog = CampaignCatalogSource.decode(
    File(workspace.resolve(campaignSourcePath)).readAsStringSync(),
  );
  Future<void> openDialog(
    WidgetTester tester,
    ValueChanged<Map<String, Object?>?> onResult,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => onResult(
                await showDialog<Map<String, Object?>>(
                  context: context,
                  builder: (_) => CampaignChapterDialog(
                    map: catalog.map,
                    workspace: workspace,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
  }

  Future<void> language(WidgetTester tester, String label) async {
    final tab = find.widgetWithText(Tab, label).first;
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'map zoom and pan preserve coordinates and preview uses game callouts',
    (tester) async {
      await openDialog(tester, (_) {});
      await fill(tester, 'Chapter title (en)', 'Preview location');
      final zoom = find.widgetWithText(TextField, 'Zoom');
      await tester.ensureVisible(zoom);
      await tester.enterText(zoom, '200');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final canvas = find.byKey(const ValueKey('location_map_placement'));
      await tester.ensureVisible(canvas);
      await tester.pumpAndSettle();
      final image = find.byKey(const ValueKey('location_map_image'));
      final bounds = tester.getRect(image);
      await tester.tapAt(
        bounds.topLeft + Offset(bounds.width * .6, bounds.height * .6),
      );
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('mapX')))
            .controller!
            .text,
        '0.6000',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('mapY')))
            .controller!
            .text,
        '0.6000',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.dragFrom(
        tester.getCenter(canvas),
        const Offset(35, 20),
        kind: PointerDeviceKind.mouse,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(tester.getTopLeft(image).dx, closeTo(bounds.left + 35, .1));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('mapX')))
            .controller!
            .text,
        '0.6000',
      );
      await tester.ensureVisible(find.text('Game preview'));
      await tester.tap(find.text('Game preview'));
      await tester.pumpAndSettle();
      expect(find.byType(MapLocationLayer), findsOneWidget);
      expect(find.text('Preview location'), findsWidgets);
      await tester.tap(find.text('Portrait'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'map placement, numeric preview and clamped dragging save the same position',
    (tester) async {
      Map<String, Object?>? result;
      await openDialog(tester, (value) => result = value);
      await fill(tester, 'Chapter title (en)', 'North Pass');
      await language(tester, 'Français');
      await fill(tester, 'Chapter title (fr)', 'Col du Nord');
      final map = find.byKey(const ValueKey('location_map_image'));
      await tester.ensureVisible(map);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(map);
      await tester.tapAt(
        bounds.topLeft + Offset(bounds.width * .25, bounds.height * .75),
      );
      await tester.pump();
      expect(find.text('0.2500'), findsOneWidget);
      expect(find.text('0.7500'), findsOneWidget);
      final marker = find.byKey(const ValueKey('location_map_marker'));
      expect(
        tester.getCenter(marker).dx,
        closeTo(bounds.left + bounds.width * .25, .1),
      );
      expect(
        tester.getCenter(marker).dy,
        closeTo(bounds.top + bounds.height * .75, .1),
      );
      await fill(tester, 'Map X (left 0 → right 1)', '0.8');
      await tester.pump();
      expect(
        tester.getCenter(marker).dx,
        closeTo(bounds.left + bounds.width * .8, .1),
      );
      await tester.ensureVisible(map);
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(tester.getCenter(map));
      await drag.moveTo(tester.getTopRight(map) + const Offset(30, -30));
      await drag.up();
      await tester.pump();
      expect(find.text('1.0000'), findsOneWidget);
      expect(find.text('0.0000'), findsOneWidget);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(result?['mapX'], 1.0);
      expect(result?['mapY'], 0.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'language tabs retain and save both translations and shared fields',
    (tester) async {
      Map<String, Object?>? result;
      await openDialog(tester, (value) => result = value);
      expect(find.text('Chapter title (en)'), findsOneWidget);
      expect(find.text('Chapter title (fr)'), findsNothing);
      await fill(tester, 'Chapter title (en)', 'North Pass');
      await fill(tester, 'Chapter description (en)', 'English draft');
      await fill(tester, 'Map X (left 0 → right 1)', '0.3');
      await language(tester, 'Français');
      expect(find.text('Chapter title (en)'), findsNothing);
      expect(find.text('Chapter title (fr)'), findsOneWidget);
      expect(find.text('Map X (left 0 → right 1)'), findsOneWidget);
      expect(find.text('0.3'), findsOneWidget);
      await fill(tester, 'Chapter title (fr)', 'Col du Nord');
      await fill(tester, 'Chapter description (fr)', 'Brouillon français');
      await language(tester, 'English');
      expect(find.text('North Pass'), findsOneWidget);
      expect(find.text('English draft'), findsOneWidget);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(result?['title'], {'en': 'North Pass', 'fr': 'Col du Nord'});
      expect(result?['description'], {
        'en': 'English draft',
        'fr': 'Brouillon français',
      });
      expect(result?['mapX'], 0.3);
      expect(result?['mapY'], 0.5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'validation reveals hidden language errors and Cancel discards edits',
    (tester) async {
      var closed = false;
      Map<String, Object?>? result;
      await openDialog(tester, (value) {
        closed = true;
        result = value;
      });
      await fill(tester, 'Chapter title (en)', 'North Pass');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      expect(find.text('Chapter title (fr)'), findsOneWidget);
      expect(find.text('Required.'), findsOneWidget);
      await fill(tester, 'Chapter title (fr)', 'Col du Nord');
      await language(tester, 'English');
      await fill(tester, 'Chapter title (en)', '');
      await language(tester, 'Français');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      expect(find.text('Chapter title (en)'), findsOneWidget);
      expect(find.text('Required.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
