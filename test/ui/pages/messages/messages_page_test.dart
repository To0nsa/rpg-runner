import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:game_presentation/catalog_gift.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_runner/ui/components/app_button.dart';
import 'package:rpg_runner/ui/components/attention_marker.dart';
import 'package:rpg_runner/ui/components/menu_icon_column.dart';
import 'package:rpg_runner/ui/pages/messages/messages_page.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/inbox/inbox_models.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';

import '../../test_support/inbox_fixture.dart';

void main() {
  testWidgets(
    'shared marker preserves icon geometry, tap behavior and accessible meaning',
    (tester) async {
      var taps = 0;
      Widget menu(bool visible) => MaterialApp(
        theme: createUiTheme(),
        home: Scaffold(
          body: Center(
            child: MenuIconColumn(
              actions: [
                MenuIconAction(
                  icon: Icons.library_books,
                  tooltip: 'Library',
                  needsAttention: visible,
                  attentionLabel: 'New library entries',
                  onPressed: () => taps += 1,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(menu(false));
      final before = tester.getSize(find.byType(IconButton));
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(menu(true));
        expect(tester.getSize(find.byType(IconButton)), before);
        expect(find.byTooltip('Library'), findsOneWidget);
        final marker = tester.widget<AttentionMarker>(
          find.byType(AttentionMarker),
        );
        expect(marker.semanticLabel, 'New library entries');
        expect(marker.visible, isTrue);
        await tester.tap(find.byType(IconButton));
        expect(taps, 1);
        expect(
          tester.getSemantics(find.byType(AttentionMarker)).value,
          'New library entries',
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final size in [const Size(844, 390), const Size(640, 360)]) {
    testWidgets(
      'landscape $size reads and claims using existing menu controls',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = InboxFixture();
        addTearDown(f.app.dispose);
        await f.app.bootstrap();
        await tester.pumpWidget(_app(f));
        await tester.pumpAndSettle();
        expect(find.text('Select a message to read it.'), findsOneWidget);
        expect(f.app.inboxSummary.unreadCount, 1);
        await tester.tap(find.text('Level 2 reached'));
        await tester.pumpAndSettle();
        expect(f.app.inboxSummary.unreadCount, 0);
        expect(f.app.inboxSummary.needsAttention, isTrue);
        expect(
          tester
              .widget<AppButton>(
                find.widgetWithText(AppButton, 'Delete message'),
              )
              .onPressed,
          isNull,
        );
        expect(
          find.textContaining('Claim your gold before deleting'),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(AppButton, 'Claim'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppButton, 'Claimed'), findsOneWidget);
        expect(f.app.progression.gold, 25);
        expect(f.app.inboxSummary.needsAttention, isFalse);
        await tester.tap(find.widgetWithText(AppButton, 'Delete message'));
        await tester.pumpAndSettle();
        expect(find.text('No messages yet.'), findsOneWidget);
        expect(f.app.progression.gold, 25);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('inbox reports load failure and retries to empty state', (
    tester,
  ) async {
    final f = InboxFixture();
    addTearDown(f.app.dispose);
    f.inbox.failLoad = true;
    await f.app.bootstrap();
    await tester.pumpWidget(_app(f));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to load messages'), findsOneWidget);
    f.inbox.failLoad = false;
    f.inbox.messages = [];
    await tester.tap(find.widgetWithText(AppButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No messages yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'information can be deleted immediately and failure allows retry',
    (tester) async {
      final f = InboxFixture();
      addTearDown(f.app.dispose);
      f.inbox.messages = [
        const InboxMessage(
          id: 'info',
          title: 'News',
          body: 'News body',
          createdAtMs: 1,
        ),
      ];
      await f.app.bootstrap();
      await tester.pumpWidget(_app(f));
      await tester.pumpAndSettle();
      await tester.tap(find.text('News'));
      await tester.pumpAndSettle();
      expect(
        find.text('Automatically removed 30 days after reading.'),
        findsOneWidget,
      );
      f.inbox.failDelete = true;
      await tester.tap(find.widgetWithText(AppButton, 'Delete message'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unable to confirm deletion'), findsOneWidget);
      f.inbox.failDelete = false;
      await tester.tap(find.widgetWithText(AppButton, 'Delete message'));
      await tester.pumpAndSettle();
      expect(find.text('No messages yet.'), findsOneWidget);
      expect(f.app.progression.gold, 0);
    },
  );

  testWidgets('deleting the loaded page keeps older messages reachable', (
    tester,
  ) async {
    final f = InboxFixture();
    addTearDown(f.app.dispose);
    const newer = InboxMessage(
      id: 'newer',
      title: 'Latest news',
      body: 'Latest body',
      createdAtMs: 2,
      readAtMs: 2,
    );
    const older = InboxMessage(
      id: 'older',
      title: 'Earlier news',
      body: 'Earlier body',
      createdAtMs: 1,
    );
    f.inbox.messages = [newer, older];
    f.inbox.delayedPage = Completer<InboxPage>()
      ..complete(
        InboxPage(
          messages: [newer],
          summary: f.inbox.summary,
          nextCursor: const InboxCursor(createdAtMs: 2, messageId: 'newer'),
        ),
      );
    await f.app.bootstrap();
    await tester.pumpWidget(_app(f));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latest news'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Delete message'));
    await tester.pumpAndSettle();
    expect(find.text('More messages are available.'), findsOneWidget);
    expect(find.text('No messages yet.'), findsNothing);
    f.inbox.delayedPage = null;
    await tester.tap(find.widgetWithText(AppButton, 'Load more'));
    await tester.pumpAndSettle();
    expect(find.text('Earlier news'), findsOneWidget);
    expect(find.text('Latest news'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed read can be retried without losing the gift', (
    tester,
  ) async {
    final f = InboxFixture();
    addTearDown(f.app.dispose);
    f.inbox.failRead = true;
    await f.app.bootstrap();
    await tester.pumpWidget(_app(f));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 2 reached'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to mark'), findsOneWidget);
    f.inbox.failRead = false;
    await tester.ensureVisible(find.widgetWithText(AppButton, 'Retry reading'));
    await tester.tap(find.widgetWithText(AppButton, 'Retry reading'));
    await tester.pumpAndSettle();
    expect(f.app.inboxMessages.single.isUnread, isFalse);
    expect(f.app.inboxMessages.single.canClaim, isTrue);
  });

  testWidgets('long mail remains scrollable with larger text', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = InboxFixture();
    addTearDown(f.app.dispose);
    f.inbox.messages = [
      InboxMessage(
        id: 'gift',
        title: 'A longer game message with a gold attachment',
        body: List.filled(
          10,
          'Game information remains readable while scrolling.',
        ).join(' '),
        createdAtMs: 1,
        goldAmount: 25,
      ),
    ];
    await f.app.bootstrap();
    await tester.pumpWidget(_app(f, scale: 1.5));
    await tester.pumpAndSettle();
    await tester.tap(find.text(f.inbox.messages.single.title));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(AppButton, 'Claim'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'item-only gifts show shared labels and protect deletion until claim',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = InboxFixture();
      addTearDown(f.app.dispose);
      f.inbox.messages = [
        InboxMessage(
          id: 'items',
          title: 'Equipment',
          body: 'A gift.',
          createdAtMs: 1,
          attachments: [
            CatalogGift.fromJson({
              'kind': 'gear',
              'slot': 'mainWeapon',
              'itemId': 'waspfang',
            }),
          ],
        ),
      ];
      await f.app.bootstrap();
      await tester.pumpWidget(_app(f));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Equipment'));
      await tester.pumpAndSettle();
      expect(find.text('Waspfang'), findsOneWidget);
      expect(
        find.textContaining('Unclaimed gifts do not expire'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Delete message'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(AppButton, 'Claim'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppButton, 'Claimed'), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Delete message'))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  if (Platform.environment['INBOX_CAPTURE'] == '1') {
    testWidgets('capture inbox for visual review', (tester) async {
      tester.view.physicalSize = const Size(960, 450);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('CrimsonText')
        ..addFont(
          rootBundle.load('assets/fonts/Crimson_Text/CrimsonText-Regular.ttf'),
        );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final f = InboxFixture();
      addTearDown(f.app.dispose);
      f.inbox.messages.add(
        const InboxMessage(
          id: 'info',
          title: 'Game information',
          body: 'Information from the game will appear here.',
          createdAtMs: 1792520000000,
        ),
      );
      await f.app.bootstrap();
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: boundary, child: _app(f)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Level 2 reached'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('.tmp/inbox').create(recursive: true);
        await File('.tmp/inbox/inbox.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}

Widget _app(InboxFixture f, {double scale = 1}) =>
    ChangeNotifierProvider<AppState>.value(
      value: f.app,
      child: MaterialApp(
        theme: createUiTheme(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const MessagesPage(),
      ),
    );
