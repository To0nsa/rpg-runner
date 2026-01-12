import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:rpg_runner/ui/viewport/game_viewport.dart';
import 'package:rpg_runner/ui/viewport/viewport_metrics.dart';

void main() {
  testWidgets('GameViewport pixelPerfectContain keeps full frame visible', (
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

    expect(tester.getSize(find.byKey(childKey)), const Size(600, 270));
  });

  testWidgets('GameViewport can be bottom-left anchored', (tester) async {
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
            alignment: Alignment.bottomLeft,
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byKey(childKey)), const Offset(0, 330));
  });
}

class _SizedGameViewport extends StatelessWidget {
  const _SizedGameViewport({
    required this.childKey,
    this.alignment = Alignment.center,
  });

  final Key childKey;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final metrics = computeViewportMetrics(
      const BoxConstraints.tightFor(width: 800, height: 600),
      1,
      600,
      270,
      ViewportScaleMode.pixelPerfectContain,
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
