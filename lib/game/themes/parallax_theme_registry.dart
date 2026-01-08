/// Render-layer mapping of Core theme IDs to concrete parallax assets.
library;

import 'parallax_theme.dart';
import '../components/pixel_parallax_backdrop_component.dart';

/// Returns the [ParallaxTheme] for a given Core `themeId`.
///
/// Unknown or null theme IDs fall back to the default theme.
class ParallaxThemeRegistry {
  const ParallaxThemeRegistry._();

  static ParallaxTheme forThemeId(String? themeId) {
    switch (themeId) {
      case 'field':
        return _field;
      case 'forest':
        return _forest;
      default:
        return _field;
    }
  }
}

const ParallaxTheme _field = ParallaxTheme(
  backgroundLayers: <PixelParallaxLayerSpec>[
    PixelParallaxLayerSpec(
      assetPath: 'parallax/field/Field Layer 01.png',
      parallaxFactor: 0.10,
    ),
    PixelParallaxLayerSpec(
      assetPath: 'parallax/field/Field Layer 02.png',
      parallaxFactor: 0.15,
    ),
    PixelParallaxLayerSpec(
      assetPath: 'parallax/field/Field Layer 03.png',
      parallaxFactor: 0.20,
    ),
    PixelParallaxLayerSpec(
      assetPath: 'parallax/field/Field Layer 04.png',
      parallaxFactor: 0.30,
    ),
    PixelParallaxLayerSpec(
      assetPath: 'parallax/field/Field Layer 05.png',
      parallaxFactor: 0.40,
    ),
    PixelParallaxLayerSpec(
      assetPath: 'parallax/field/Field Layer 06.png',
      parallaxFactor: 0.50,
    ),
    PixelParallaxLayerSpec(
      assetPath: 'parallax/field/Field Layer 07.png',
      parallaxFactor: 0.60,
    ),
    PixelParallaxLayerSpec(
      assetPath: 'parallax/field/Field Layer 08.png',
      parallaxFactor: 0.70,
    ),
  ],
  groundLayerAsset: 'parallax/field/Field Layer 09.png',
  foregroundLayers: <PixelParallaxLayerSpec>[
    PixelParallaxLayerSpec(
      assetPath: 'parallax/field/Field Layer 10.png',
      parallaxFactor: 1.0,
    ),
  ],
);

const ParallaxTheme _forest = ParallaxTheme(
  backgroundLayers: <PixelParallaxLayerSpec>[
    PixelParallaxLayerSpec(
      assetPath: 'parallax/forest/Forest Layer 01.png',
      parallaxFactor: 0.10,
    ),
    PixelParallaxLayerSpec(
      assetPath: 'parallax/forest/Forest Layer 02.png',
      parallaxFactor: 0.20,
    ),
    PixelParallaxLayerSpec(
      assetPath: 'parallax/forest/Forest Layer 03.png',
      parallaxFactor: 0.30,
    ),
  ],
  groundLayerAsset: 'parallax/forest/Forest Layer 04.png',
  foregroundLayers: <PixelParallaxLayerSpec>[
    PixelParallaxLayerSpec(
      assetPath: 'parallax/forest/Forest Layer 05.png',
      parallaxFactor: 1.0,
    ),
  ],
);