import 'package:flutter/widgets.dart';

import 'highlighted_value_spans.dart';

/// Semantic tone metadata shared across UI rich text surfaces.
enum UiSemanticTone { neutral, positive, negative, accent }

/// Tone-tagged token to highlight inside a semantic text segment.
class UiSemanticHighlight {
  const UiSemanticHighlight(this.token, {required this.tone});

  final String token;
  final UiSemanticTone tone;
}

/// Text segment with optional token highlights.
class UiSemanticTextSegment {
  const UiSemanticTextSegment(
    this.text, {
    this.tone = UiSemanticTone.neutral,
    this.highlights = const <UiSemanticHighlight>[],
  });

  final String text;
  final UiSemanticTone tone;
  final List<UiSemanticHighlight> highlights;
}

/// Rich text payload composed from one or more semantic segments.
class UiSemanticText {
  const UiSemanticText({required this.segments, this.segmentSeparator = ''});

  factory UiSemanticText.single(
    String text, {
    UiSemanticTone tone = UiSemanticTone.neutral,
    List<UiSemanticHighlight> highlights = const <UiSemanticHighlight>[],
  }) {
    return UiSemanticText(
      segments: <UiSemanticTextSegment>[
        UiSemanticTextSegment(text, tone: tone, highlights: highlights),
      ],
    );
  }

  static const UiSemanticText empty = UiSemanticText(
    segments: <UiSemanticTextSegment>[],
  );

  final List<UiSemanticTextSegment> segments;
  final String segmentSeparator;

  bool get isEmpty => segments.every((segment) => segment.text.isEmpty);
}

/// Builds text spans for [semanticText] using tone-aware style resolvers.
List<TextSpan> buildUiSemanticTextSpans({
  required UiSemanticText semanticText,
  required TextStyle Function(UiSemanticTone tone) normalStyleForTone,
  required TextStyle Function(UiSemanticTone tone) highlightStyleForTone,
  UiSemanticTone Function(UiSemanticTone tone)? mapHighlightTone,
}) {
  if (semanticText.segments.isEmpty) return const <TextSpan>[];
  final spans = <TextSpan>[];
  for (var i = 0; i < semanticText.segments.length; i++) {
    final segment = semanticText.segments[i];
    final normalStyle = normalStyleForTone(segment.tone);
    spans.addAll(
      buildHighlightedTextSpans(
        text: segment.text,
        normalStyle: normalStyle,
        highlights: <InlineTextHighlight>[
          for (final highlight in segment.highlights)
            InlineTextHighlight(
              value: highlight.token,
              style: highlightStyleForTone(
                mapHighlightTone?.call(highlight.tone) ?? highlight.tone,
              ),
            ),
        ],
      ),
    );
    if (i < semanticText.segments.length - 1 &&
        semanticText.segmentSeparator.isNotEmpty) {
      spans.add(
        TextSpan(
          text: semanticText.segmentSeparator,
          style: normalStyleForTone(UiSemanticTone.neutral),
        ),
      );
    }
  }
  return spans;
}

/// Reusable rich-text widget for semantic highlight rendering.
class UiSemanticRichText extends StatelessWidget {
  const UiSemanticRichText({
    super.key,
    required this.semanticText,
    required this.normalStyleForTone,
    required this.highlightStyleForTone,
    this.mapHighlightTone,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  final UiSemanticText semanticText;
  final TextStyle Function(UiSemanticTone tone) normalStyleForTone;
  final TextStyle Function(UiSemanticTone tone) highlightStyleForTone;
  final UiSemanticTone Function(UiSemanticTone tone)? mapHighlightTone;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: buildUiSemanticTextSpans(
          semanticText: semanticText,
          normalStyleForTone: normalStyleForTone,
          highlightStyleForTone: highlightStyleForTone,
          mapHighlightTone: mapHighlightTone,
        ),
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
