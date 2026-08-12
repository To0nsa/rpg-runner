/// Render-layer parallax theme configuration.
library;

import '../components/pixel_parallax_backdrop.dart';

class ParallaxTheme {
  const ParallaxTheme({
    required this.backgroundLayers,
    required this.foregroundLayers,
  });

  final List<PixelParallaxLayerSpec> backgroundLayers;
  final List<PixelParallaxLayerSpec> foregroundLayers;
}
