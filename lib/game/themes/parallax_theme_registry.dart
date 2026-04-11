/// Render-layer mapping of Core theme IDs to generated visual theme content.
library;

import 'authored_parallax_themes.dart';
import 'parallax_theme.dart';

/// Returns the [ParallaxTheme] for a given Core `themeId`.
///
/// Unknown or null theme IDs fall back to the default authored theme.
class ParallaxThemeRegistry {
  const ParallaxThemeRegistry._();

  static const String defaultThemeId = 'field';

  static ParallaxTheme forThemeId(String? themeId) {
    if (themeId != null) {
      final authoredTheme = authoredParallaxThemesById[themeId];
      if (authoredTheme != null) {
        return authoredTheme;
      }
    }

    final defaultTheme = authoredParallaxThemesById[defaultThemeId];
    if (defaultTheme != null) {
      return defaultTheme;
    }

    if (authoredParallaxThemesById.isNotEmpty) {
      return authoredParallaxThemesById.values.first;
    }

    throw StateError('No authored parallax themes are available.');
  }
}
