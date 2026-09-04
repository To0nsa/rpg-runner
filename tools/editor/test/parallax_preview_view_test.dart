import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/parallaxEditor/widgets/parallax_preview_view.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';

void main() {
  testWidgets('shared Y offset previews and saves an absolute layer value', (
    tester,
  ) async {
    final appliedYOffsets = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 800,
            child: ParallaxPreviewView(
              workspaceRootPath: '.',
              onSetAllLayerYOffsets: (value) {
                appliedYOffsets.add(value);
                return true;
              },
              theme: const ParallaxThemeDef(
                parallaxThemeId: 'field',
                revision: 1,
                layers: <ParallaxLayerDef>[
                  ParallaxLayerDef(
                    layerKey: 'field_bg',
                    assetPath: 'assets/images/parallax/field/layer_01.png',
                    group: parallaxGroupBackground,
                    parallaxFactor: 0.1,
                    zOrder: 10,
                    opacity: 1,
                    yOffset: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('sharedYOffset=24'), findsOneWidget);

    final yOffsetField = find.byKey(
      const ValueKey<String>('parallax_preview_y_offset'),
    );
    await tester.enterText(yOffsetField, '64');
    await tester.pump();

    expect(find.text('sharedYOffset=64'), findsOneWidget);
    await tester.tap(find.text('Set Y Offset on All Layers'));
    await tester.pump();

    expect(appliedYOffsets, <double>[64]);
    expect(find.text('sharedYOffset=64'), findsOneWidget);

    await tester.tap(find.text('Set Y Offset to 0'));
    await tester.pump();

    expect(find.text('sharedYOffset=0'), findsOneWidget);
    await tester.tap(find.text('Set Y Offset on All Layers'));
    await tester.pump();

    expect(appliedYOffsets, <double>[64, 0]);
  });
}
