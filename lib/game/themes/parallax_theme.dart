/// Render-layer parallax theme configuration.
library;

import '../components/pixel_parallax_backdrop.dart';

class ParallaxTheme {
  const ParallaxTheme({
    required this.backgroundLayers,
    required this.groundMaterialAssetPath,
    required this.foregroundLayers,
  });

  final List<PixelParallaxLayerSpec> backgroundLayers;
  final String groundMaterialAssetPath;
  final List<PixelParallaxLayerSpec> foregroundLayers;
}
