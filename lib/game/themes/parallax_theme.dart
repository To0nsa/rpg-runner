/// Render-layer parallax theme configuration.
library;

import '../components/pixel_parallax_backdrop_component.dart';

class ParallaxTheme {
  const ParallaxTheme({
    required this.backgroundLayers,
    required this.groundLayerAsset,
    required this.foregroundLayers,
  });

  final List<PixelParallaxLayerSpec> backgroundLayers;
  final String groundLayerAsset;
  final List<PixelParallaxLayerSpec> foregroundLayers;
}

