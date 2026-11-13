import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/components/app_segmented_control.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';

void main() {
  testWidgets('selection and disabled choices retain accessible state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final changes = <String>[];
    await tester.pumpWidget(_Harness(onChanged: changes.add));

    expect(_selected(tester, 'Practice'), ui.Tristate.isTrue);
    expect(_enabled(tester, 'Practice'), ui.Tristate.isTrue);
    expect(_enabled(tester, 'Weekly'), ui.Tristate.isFalse);
    await tester.tap(_option('Practice'));
    await tester.tap(_option('Weekly'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(_selected(tester, 'Practice'), ui.Tristate.isTrue);

    await tester.tap(_option('Competitive'));
    await tester.pumpAndSettle();
    expect(changes, ['Competitive']);
    expect(_selected(tester, 'Competitive'), ui.Tristate.isTrue);
    expect(_selected(tester, 'Practice'), ui.Tristate.isFalse);

    await tester.pumpWidget(_Harness(enabled: false, onChanged: changes.add));
    for (final label in ['Practice', 'Competitive', 'Weekly']) {
      expect(_enabled(tester, label), ui.Tristate.isFalse);
      await tester.tap(_option(label));
    }
    await tester.pumpAndSettle();
    expect(changes, ['Competitive']);
    expect(_selected(tester, 'Competitive'), ui.Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets(
    'keyboard traversal skips locked choices and activates selection',
    (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(_Harness(onChanged: changes.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, ['Competitive']);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, ['Competitive', 'Practice']);
    },
  );

  testWidgets('eligibility is rechecked when a choice is activated', (
    tester,
  ) async {
    final locked = <String>{'Weekly'};
    final changes = <String>[];
    await tester.pumpWidget(_Harness(locked: locked, onChanged: changes.add));
    locked.add('Competitive');
    await tester.tap(_option('Competitive'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });

  for (final size in AppSegmentedControlSize.values) {
    testWidgets('$size keeps separate touch targets and equal choice widths', (
      tester,
    ) async {
      await tester.pumpWidget(_Harness(size: size));
      final rects = [
        for (final label in ['Practice', 'Competitive', 'Weekly'])
          tester.getRect(_option(label)),
      ];
      for (final rect in rects) {
        expect(rect.height, greaterThanOrEqualTo(44));
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.width, closeTo(rects.first.width, .01));
      }
      expect(rects[0].right, lessThan(rects[1].left));
      expect(rects[1].right, lessThan(rects[2].left));
      if (size == AppSegmentedControlSize.sm) {
        expect(
          tester.getSize(find.byType(AppSegmentedControl<String>)).height,
          lessThanOrEqualTo(kToolbarHeight),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long localized labels fit narrow widths with larger text', (
    tester,
  ) async {
    const labels = ['Flèches', 'Joystick flottant', 'Joystick fixe'];
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const _Harness(
        values: labels,
        locked: {},
        textScaler: TextScaler.linear(1.8),
      ),
    );
    await tester.pumpAndSettle();
    final rail = tester.getRect(find.byType(AppSegmentedControl<String>));
    for (final label in labels) {
      final choice = tester.getRect(_option(label));
      final text = tester.getRect(find.text(label));
      expect(choice.left, greaterThanOrEqualTo(rail.left));
      expect(choice.right, lessThanOrEqualTo(rail.right));
      expect(text.left, greaterThanOrEqualTo(choice.left));
      expect(text.right, lessThanOrEqualTo(choice.right));
      expect(text.height, lessThanOrEqualTo(choice.height));
    }
    await tester.tap(_option(labels[1]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('right-to-left layout preserves choice order and selection', (
    tester,
  ) async {
    final changes = <String>[];
    await tester.pumpWidget(
      _Harness(direction: TextDirection.rtl, onChanged: changes.add),
    );
    expect(
      tester.getCenter(_option('Practice')).dx,
      greaterThan(tester.getCenter(_option('Competitive')).dx),
    );
    await tester.tap(_option('Competitive'));
    await tester.pumpAndSettle();
    expect(changes, ['Competitive']);
    expect(tester.takeException(), isNull);
  });

  if (const bool.fromEnvironment('CAPTURE_SELECTORS')) {
    testWidgets('capture the implemented rail with real app fonts', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        for (final (family, path) in [
          ('Inter', 'assets/fonts/Inter/static/Inter_24pt-Medium.ttf'),
          ('CrimsonText', 'assets/fonts/Crimson_Text/CrimsonText-Regular.ttf'),
        ]) {
          await (FontLoader(family)..addFont(rootBundle.load(path))).load();
        }
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: const _Harness()),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image = await tester
            .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
            .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('.tmp/selector-redesign-20261113/implemented-rail.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}

Finder _option(String label) => find.widgetWithText(TextButton, label);

ui.Tristate _selected(WidgetTester tester, String label) => tester
    .getSemantics(_option(label))
    .getSemanticsData()
    .flagsCollection
    .isSelected;

ui.Tristate _enabled(WidgetTester tester, String label) => tester
    .getSemantics(_option(label))
    .getSemanticsData()
    .flagsCollection
    .isEnabled;

class _Harness extends StatefulWidget {
  const _Harness({
    this.values = const ['Practice', 'Competitive', 'Weekly'],
    this.locked = const {'Weekly'},
    this.enabled = true,
    this.size = AppSegmentedControlSize.md,
    this.direction = TextDirection.ltr,
    this.textScaler = TextScaler.noScaling,
    this.onChanged,
  });

  final List<String> values;
  final Set<String> locked;
  final bool enabled;
  final AppSegmentedControlSize size;
  final TextDirection direction;
  final TextScaler textScaler;
  final ValueChanged<String>? onChanged;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late String selected = widget.values.first;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: createUiTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: widget.textScaler),
      child: Directionality(textDirection: widget.direction, child: child!),
    ),
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppSegmentedControl<String>(
            values: widget.values,
            selected: selected,
            enabled: widget.enabled,
            size: widget.size,
            isValueEnabled: (value) => !widget.locked.contains(value),
            onChanged: (value) {
              setState(() => selected = value);
              widget.onChanged?.call(value);
            },
            labelBuilder: (_, value) => Text(value),
          ),
        ),
      ),
    ),
  );
}
