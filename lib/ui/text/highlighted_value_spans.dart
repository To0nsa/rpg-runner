import 'package:flutter/widgets.dart';

/// Inline highlight token with its resolved visual style.
class InlineTextHighlight {
  const InlineTextHighlight({required this.value, required this.style});

  final String value;
  final TextStyle style;
}

/// Builds [TextSpan]s for [text], applying styles to matching [highlights].
///
/// Token matching is longest-first to prevent partial overlap issues.
List<TextSpan> buildHighlightedTextSpans({
  required String text,
  required TextStyle normalStyle,
  required List<InlineTextHighlight> highlights,
}) {
  final ordered = _orderedUniqueHighlights(highlights);
  if (ordered.isEmpty) {
    return <TextSpan>[TextSpan(text: text, style: normalStyle)];
  }

  final regex = RegExp(
    ordered.map((entry) => RegExp.escape(entry.value)).join('|'),
  );
  final styleByToken = <String, TextStyle>{
    for (final entry in ordered) entry.value: entry.style,
  };

  final spans = <TextSpan>[];
  var index = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > index) {
      spans.add(
        TextSpan(text: text.substring(index, match.start), style: normalStyle),
      );
    }

    final token = match.group(0);
    final tokenStyle = token == null ? null : styleByToken[token];
    spans.add(TextSpan(text: token, style: tokenStyle ?? normalStyle));
    index = match.end;
  }

  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index), style: normalStyle));
  }
  return spans;
}

List<InlineTextHighlight> _orderedUniqueHighlights(
  List<InlineTextHighlight> highlights,
) {
  final entries =
      highlights
          .where((entry) => entry.value.isNotEmpty)
          .toList(growable: false)
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

  final seen = <String>{};
  final unique = <InlineTextHighlight>[];
  for (final entry in entries) {
    if (!seen.add(entry.value)) continue;
    unique.add(entry);
  }
  return unique;
}
