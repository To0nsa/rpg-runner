/// Render-layer mapping of Core theme IDs to generated visual theme content.
library;

import 'authored_parallax_themes.dart';
import 'parallax_theme.dart';

/// Returns the [ParallaxTheme] for a given Core visual theme id.
///
/// Unknown or null theme IDs fall back to the default authored theme.
class ParallaxThemeRegistry {
  const ParallaxThemeRegistry._();

  static const String defaultParallaxThemeId = 'field';

  static ParallaxTheme? maybeForParallaxThemeId(String? parallaxThemeId) {
    if (parallaxThemeId != null) {
      final authoredTheme = authoredParallaxThemesById[parallaxThemeId];
      if (authoredTheme != null) {
        return authoredTheme;
      }
    }

    final defaultTheme = authoredParallaxThemesById[defaultParallaxThemeId];
    if (defaultTheme != null) {
      return defaultTheme;
    }

    if (authoredParallaxThemesById.isNotEmpty) {
      return authoredParallaxThemesById.values.first;
    }

    return null;
  }

  static ParallaxTheme forParallaxThemeId(String? parallaxThemeId) {
    final theme = maybeForParallaxThemeId(parallaxThemeId);
    if (theme != null) {
      return theme;
    }

    throw StateError('No authored parallax themes are available.');
  }
}
