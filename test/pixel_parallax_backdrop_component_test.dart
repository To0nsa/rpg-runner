import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/pixel_parallax_backdrop_component.dart';

void main() {
  group('PixelParallaxBackdropComponent.resolveLayerTopY', () {
    test('falls back to viewport-bottom anchoring when anchor is null', () {
      final topY = PixelParallaxBackdropComponent.resolveLayerTopY(
        viewHeight: 270,
        imageHeight: 256,
        bottomAnchorY: null,
      );

      expect(topY, 14.0);
    });

    test('anchors layer bottom to provided view-space Y', () {
      final topY = PixelParallaxBackdropComponent.resolveLayerTopY(
        viewHeight: 270,
        imageHeight: 256,
        bottomAnchorY: 220.0,
      );

      expect(topY, -36.0);
    });

    test('falls back to viewport-bottom anchoring for non-finite anchor', () {
      final topY = PixelParallaxBackdropComponent.resolveLayerTopY(
        viewHeight: 270,
        imageHeight: 256,
        bottomAnchorY: double.nan,
      );

      expect(topY, 14.0);
    });
  });
}
