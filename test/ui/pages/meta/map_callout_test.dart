import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/pages/town/map_callout.dart';

void main() {
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
