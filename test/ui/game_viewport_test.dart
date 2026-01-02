import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/ui/viewport/game_viewport.dart';
import 'package:walkscape_runner/ui/viewport/viewport_metrics.dart';

void main() {
  testWidgets('GameViewport pixelPerfectContain letterboxes vertically', (
    tester,
  ) async {
    const childKey = Key('child');

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 600),
          devicePixelRatio: 1,
        ),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: _SizedGameViewport(childKey: childKey),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(childKey));
    expect(size.width, moreOrLessEquals(600.0));
    expect(size.height, moreOrLessEquals(270.0));

    final topLeft = tester.getTopLeft(find.byKey(childKey));
    expect(topLeft.dx, moreOrLessEquals(100.0));
    expect(topLeft.dy, moreOrLessEquals(165.0));
  });

  testWidgets('GameViewport pixelPerfectCover fills screen and crops', (
    tester,
  ) async {
    const childKey = Key('child');

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 600),
          devicePixelRatio: 1,
        ),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: _SizedGameViewport(
            childKey: childKey,
            mode: ViewportScaleMode.pixelPerfectCover,
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(childKey));
    expect(size.width, greaterThanOrEqualTo(800.0));
    expect(size.height, greaterThanOrEqualTo(600.0));

    final topLeft = tester.getTopLeft(find.byKey(childKey));
    expect(topLeft.dx, lessThanOrEqualTo(0.0));
    expect(topLeft.dy, lessThanOrEqualTo(0.0));
  });
}

class _SizedGameViewport extends StatelessWidget {
  const _SizedGameViewport({
    required this.childKey,
    this.mode = ViewportScaleMode.pixelPerfectContain,
    this.alignment = Alignment.center,
  });

  final Key childKey;
  final ViewportScaleMode mode;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final metrics = computeViewportMetrics(
      const BoxConstraints.tightFor(width: 800, height: 600),
      1,
      600,
      270,
      mode,
      alignment: alignment,
    );

    return SizedBox(
      width: 800,
      height: 600,
      child: GameViewport(
        metrics: metrics,
        child: SizedBox(key: childKey),
      ),
    );
  }
}
