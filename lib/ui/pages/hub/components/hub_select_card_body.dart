import 'package:flutter/material.dart';

import '../../../theme/ui_tokens.dart';

/// Shared inner content for hub selection cards (level/character/etc.).
///
/// Owns typography + spacing contract so individual cards only provide data
/// (header/title/subtitle) and optional visuals (e.g. character preview).
class HubSelectCardBody extends StatelessWidget {
  const HubSelectCardBody({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
    this.labelTextAlign = TextAlign.start,
    this.labelMaxLines = 1,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 1,
    this.trailing,
  });

  final String label;
  final String title;
  /// Optional supporting text; omitting it also removes its spacing.
  final String? subtitle;
  /// Horizontal alignment of the heading across the card's content width.
  final TextAlign labelTextAlign;
  final int labelMaxLines;
  final int titleMaxLines;
  final int subtitleMaxLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final subtitle = this.subtitle;
    final base = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            label,
            style: ui.text.cardLabel,
            textAlign: labelTextAlign,
            maxLines: labelMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(height: ui.space.xs),
        Text(
          title,
          style: ui.text.cardTitle,
          maxLines: titleMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          SizedBox(height: ui.space.xxs),
          Text(
            subtitle,
            style: ui.text.cardSubtitle,
            maxLines: subtitleMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    final t = trailing;
    if (t == null) return base;

    return Stack(
      children: [
        base,
        Positioned(right: 0, bottom: 0, child: t),
      ],
    );
  }
}
