import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:walkscape_runner/ui/pixel_perfect_viewport.dart';

void main() {
  testWidgets('PixelPerfectViewport contain keeps full frame visible', (
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
          child: SizedBox(
            width: 800,
            height: 600,
            child: PixelPerfectViewport(
              virtualWidth: 480,
              virtualHeight: 270,
              child: SizedBox(key: childKey),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(childKey)), const Size(480, 270));
  });

  testWidgets('PixelPerfectViewport can be bottom-left anchored', (tester) async {
    const childKey = Key('child');

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 600),
          devicePixelRatio: 1,
        ),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 800,
            height: 600,
            child: PixelPerfectViewport(
              virtualWidth: 480,
              virtualHeight: 270,
              alignment: Alignment.bottomLeft,
              child: SizedBox(key: childKey),
            ),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byKey(childKey)), const Offset(0, 330));
  });
}
