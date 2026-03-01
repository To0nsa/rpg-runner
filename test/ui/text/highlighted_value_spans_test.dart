import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/text/highlighted_value_spans.dart';

void main() {
  test('buildHighlightedTextSpans matches longest token first', () {
    const normal = TextStyle(color: Colors.white);
    const shortStyle = TextStyle(color: Colors.red);
    const longStyle = TextStyle(color: Colors.green);

    final spans = buildHighlightedTextSpans(
      text: 'Gain 50% speed for 5 seconds.',
      normalStyle: normal,
      highlights: const <InlineTextHighlight>[
        InlineTextHighlight(value: '5', style: shortStyle),
        InlineTextHighlight(value: '50%', style: longStyle),
      ],
    );

    final highlighted50 = spans.firstWhere((span) => span.text == '50%');
    final highlighted5 = spans.firstWhere((span) => span.text == '5');
    expect(highlighted50.style?.color, equals(Colors.green));
    expect(highlighted5.style?.color, equals(Colors.red));
  });
}
