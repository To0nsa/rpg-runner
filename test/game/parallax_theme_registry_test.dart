import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/themes/parallax_theme_registry.dart';

void main() {
  test('resolves generated authored theme content for field', () {
    final theme = ParallaxThemeRegistry.forParallaxThemeId('field');

    expect(
      theme.backgroundLayers.map((layer) => layer.assetPath).toList(),
      <String>[
        'parallax/field/layer_01.png',
        'parallax/field/layer_02.png',
        'parallax/field/layer_03.png',
        'parallax/field/layer_04.png',
        'parallax/field/layer_05.png',
        'parallax/field/layer_06.png',
        'parallax/field/layer_07.png',
        'parallax/field/layer_08.png',
      ],
    );
    expect(theme.foregroundLayers, isEmpty);
    expect(theme.backgroundLayers.first.opacity, 1.0);
    expect(theme.backgroundLayers.first.yOffset, -44.0);
  });

  test('falls back to default authored theme for unknown theme id', () {
    final fallbackTheme = ParallaxThemeRegistry.forParallaxThemeId(
      'missing-theme',
    );

    expect(fallbackTheme.backgroundLayers, isNotEmpty);
  });

  test('null theme id resolves to default authored theme', () {
    expect(
      ParallaxThemeRegistry.maybeForParallaxThemeId(null)?.backgroundLayers,
      isNotEmpty,
    );
  });
}
