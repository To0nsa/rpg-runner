import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/themes/parallax_theme_registry.dart';

void main() {
  test('resolves generated authored theme content for field', () {
    final theme = ParallaxThemeRegistry.forParallaxThemeId('field');

    expect(theme.groundMaterialAssetPath, 'parallax/field/Field Layer 09.png');
    expect(
      theme.backgroundLayers.map((layer) => layer.assetPath).toList(),
      <String>[
        'parallax/field/Field Layer 01.png',
        'parallax/field/Field Layer 02.png',
        'parallax/field/Field Layer 03.png',
        'parallax/field/Field Layer 04.png',
        'parallax/field/Field Layer 05.png',
        'parallax/field/Field Layer 06.png',
        'parallax/field/Field Layer 07.png',
        'parallax/field/Field Layer 08.png',
      ],
    );
    expect(
      theme.foregroundLayers.single.assetPath,
      'parallax/field/Field Layer 10.png',
    );
    expect(theme.backgroundLayers.first.opacity, 1.0);
    expect(theme.backgroundLayers.first.yOffset, 0.0);
  });

  test('falls back to default authored theme for unknown theme id', () {
    final fallbackTheme = ParallaxThemeRegistry.forParallaxThemeId(
      'missing-theme',
    );

    expect(
      fallbackTheme.groundMaterialAssetPath,
      'parallax/field/Field Layer 09.png',
    );
  });

  test('null theme id resolves to default authored theme', () {
    expect(
      ParallaxThemeRegistry.maybeForParallaxThemeId(
        null,
      )?.groundMaterialAssetPath,
      'parallax/field/Field Layer 09.png',
    );
  });
}
