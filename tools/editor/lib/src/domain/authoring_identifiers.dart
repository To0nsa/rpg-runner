/// Stable repository identity accepted by level and visual-theme authoring.
///
/// Callers may trim surrounding form whitespace before validation, but must not
/// lowercase or rewrite separators because persisted identities are references.
final RegExp stableAuthoringIdentifierPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// Returns the Dart declaration suffix emitted for a parallax theme identity.
///
/// Distinct authored IDs must not return the same value or generated Dart would
/// contain duplicate declarations.
String generatedParallaxThemeSymbolSuffix(String themeId) {
  final parts = themeId
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty);
  final buffer = StringBuffer();
  for (final part in parts) {
    buffer.write('${part[0].toUpperCase()}${part.substring(1)}');
  }
  return buffer.isEmpty ? 'Theme' : buffer.toString();
}
