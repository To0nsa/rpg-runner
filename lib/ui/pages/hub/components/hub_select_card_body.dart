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
    required this.subtitle,
    this.labelMaxLines = 1,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 1,
    this.trailing,
  });

  final String label;
  final String title;
  final String subtitle;
  final int labelMaxLines;
  final int titleMaxLines;
  final int subtitleMaxLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final base = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ui.text.cardLabel,
          maxLines: labelMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: ui.space.xs),
        Text(
          title,
          style: ui.text.cardTitle,
          maxLines: titleMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: ui.space.xxs),
        Text(
          subtitle,
          style: ui.text.cardSubtitle,
          maxLines: subtitleMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
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
