import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/parallaxEditor/widgets/parallax_preview_view.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';

void main() {
  testWidgets('preview offset shifts every layer without editing theme data', (
    tester,
  ) async {
    double? appliedYOffset;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 800,
            child: ParallaxPreviewView(
              workspaceRootPath: '.',
              onApplyPreviewYOffset: (value) {
                appliedYOffset = value;
                return true;
              },
              theme: const ParallaxThemeDef(
                parallaxThemeId: 'field',
                revision: 1,
                layers: <ParallaxLayerDef>[
                  ParallaxLayerDef(
                    layerKey: 'field_bg',
                    assetPath:
                        'assets/images/parallax/field/Field Layer 01.png',
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

    expect(find.text('previewYOffset=0'), findsOneWidget);

    final offsetSlider = tester.widget<Slider>(
      find.byKey(const ValueKey<String>('parallax_preview_y_offset')),
    );
    offsetSlider.onChanged!(64);
    await tester.pump();

    expect(find.text('previewYOffset=64'), findsOneWidget);
    await tester.tap(find.text('Apply Y Offset to All Layers'));
    await tester.pump();

    expect(appliedYOffset, 64);
    expect(find.text('previewYOffset=0'), findsOneWidget);

    offsetSlider.onChanged!(64);
    await tester.pump();
    await tester.tap(find.text('Reset Y Offset'));
    await tester.pump();

    expect(find.text('previewYOffset=0'), findsOneWidget);
  });
}
