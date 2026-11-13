import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/components/map_callout.dart';
import 'package:rpg_runner/ui/components/map_location_layer.dart';

void main() {
  testWidgets('automatic locations avoid clustered pins and measured labels', (
    tester,
  ) async {
    const anchors = [Offset(180, 145), Offset(184, 150), Offset(188, 155)];
    const visible = Rect.fromLTWH(8, 8, 384, 484);
    for (final scale in [1.0, 1.5]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Center(
              child: SizedBox(
                width: 400,
                height: 500,
                child: MapLocationLayer(
                  anchors: anchors,
                  visibleMap: visible,
                  children: [
                    for (var i = 0; i < 3; i++)
                      TextButton(
                        key: ValueKey('location_$i'),
                        onPressed: () {},
                        child: Text('Location with a longer name $i'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byType(MapLocationLayer));
      final bounds = [
        for (var i = 0; i < 3; i++)
          tester.getRect(find.byKey(ValueKey('location_$i'))).shift(-origin),
      ];
      for (var i = 0; i < bounds.length; i++) {
        expect(visible.contains(bounds[i].topLeft), isTrue);
        expect(bounds[i].right, lessThanOrEqualTo(visible.right));
        expect(bounds[i].bottom, lessThanOrEqualTo(visible.bottom));
        expect(anchors.any(bounds[i].contains), isFalse);
        for (var j = i + 1; j < bounds.length; j++) {
          expect(
            bounds[i].overlaps(bounds[j]),
            isFalse,
            reason: 'scale $scale, bounds $bounds',
          );
        }
        await tester.tap(find.byKey(ValueKey('location_$i')));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('leaders meet measured label edges without crossing the label', (
    tester,
  ) async {
    const labelKey = ValueKey('label');
    const visibleMap = Rect.fromLTWH(40, 8, 320, 284);
    var taps = 0;
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final anchor in [
        const Offset(10, 100),
        const Offset(390, 100),
        const Offset(200, 30),
        const Offset(200, 270),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Center(
                child: SizedBox(
                  width: 400,
                  height: 300,
                  child: MapCallout(
                    anchor: anchor,
                    labelCenter: const Offset(200, 150),
                    visibleMap: visibleMap,
                    child: TextButton(
                      key: labelKey,
                      onPressed: () => taps++,
                      child: const Text('A longer location name'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final callout = find.byType(MapCallout);
        final bounds = tester
            .getRect(find.byKey(labelKey))
            .shift(-tester.getTopLeft(callout));
        expect(bounds.left, greaterThanOrEqualTo(visibleMap.left));
        expect(bounds.right, lessThanOrEqualTo(visibleMap.right));
        final canvas = TestRecordingCanvas();
        tester
            .renderObject<RenderBox>(callout)
            .paint(TestRecordingPaintingContext(canvas), Offset.zero);
        final path =
            canvas.invocations
                    .firstWhere(
                      (call) => call.invocation.memberName == #drawPath,
                    )
                    .invocation
                    .positionalArguments
                    .first
                as Path;
        final metric = path.computeMetrics().single;
        final last = metric.getTangentForOffset(metric.length)!;
        final edge = anchor.dx < bounds.center.dx
            ? bounds.centerLeft
            : bounds.centerRight;
        expect((last.position - edge).distance, lessThan(.01));
        expect(last.vector.dy.abs(), lessThan(.001));
        for (var distance = 0.0; distance < metric.length; distance += .5) {
          expect(
            bounds
                .deflate(.1)
                .contains(metric.getTangentForOffset(distance)!.position),
            isFalse,
            reason:
                'Leader crosses the label at text scale $scale from $anchor',
          );
        }
        final before = taps;
        await tester.tap(find.byKey(labelKey));
        await tester.pumpAndSettle();
        expect(taps, before + 1);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
