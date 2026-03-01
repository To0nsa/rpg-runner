import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/text/semantic_text.dart';

void main() {
  test('buildUiSemanticTextSpans styles repeated tokens per segment tone', () {
    const semantic = UiSemanticText(
      segments: <UiSemanticTextSegment>[
        UiSemanticTextSegment(
          'Lose: 5% power',
          highlights: <UiSemanticHighlight>[
            UiSemanticHighlight('5%', tone: UiSemanticTone.negative),
          ],
        ),
        UiSemanticTextSegment(
          'Add: 5% power',
          highlights: <UiSemanticHighlight>[
            UiSemanticHighlight('5%', tone: UiSemanticTone.positive),
          ],
        ),
      ],
      segmentSeparator: ' | ',
    );

    final spans = buildUiSemanticTextSpans(
      semanticText: semantic,
      normalStyleForTone: (_) => const TextStyle(color: Colors.white),
      highlightStyleForTone: (tone) => TextStyle(
        color: switch (tone) {
          UiSemanticTone.positive => Colors.green,
          UiSemanticTone.negative => Colors.red,
          _ => Colors.blue,
        },
      ),
    );

    final fivePercents = spans.where((span) => span.text == '5%').toList();
    expect(fivePercents, hasLength(2));
    expect(fivePercents[0].style?.color, Colors.red);
    expect(fivePercents[1].style?.color, Colors.green);
  });

  test('buildUiSemanticTextSpans can override highlight tone mapping', () {
    const semantic = UiSemanticText(
      segments: <UiSemanticTextSegment>[
        UiSemanticTextSegment(
          'Applies Slow for 3 seconds.',
          highlights: <UiSemanticHighlight>[
            UiSemanticHighlight('Slow', tone: UiSemanticTone.negative),
            UiSemanticHighlight('3 seconds', tone: UiSemanticTone.negative),
          ],
        ),
      ],
    );

    final spans = buildUiSemanticTextSpans(
      semanticText: semantic,
      normalStyleForTone: (_) => const TextStyle(color: Colors.white),
      highlightStyleForTone: (tone) => TextStyle(
        color: switch (tone) {
          UiSemanticTone.positive => Colors.green,
          UiSemanticTone.negative => Colors.red,
          _ => Colors.blue,
        },
      ),
      mapHighlightTone: (_) => UiSemanticTone.positive,
    );

    final highlighted = spans
        .where((span) => span.text == 'Slow' || span.text == '3 seconds')
        .toList();
    expect(highlighted, hasLength(2));
    expect(highlighted[0].style?.color, Colors.green);
    expect(highlighted[1].style?.color, Colors.green);
  });
}
