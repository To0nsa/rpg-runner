import 'package:flutter/material.dart';

/// Shared inner content for hub selection cards (level/character/etc.).
///
/// Owns typography + spacing contract so individual cards only provide data
/// (header/title/subtitle) and optional visuals (e.g. character preview).
class HubSelectionCardBody extends StatelessWidget {
  const HubSelectionCardBody({
    super.key,
    required this.headerText,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 1,
  });

  final String headerText;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final int titleMaxLines;
  final int subtitleMaxLines;

  static const TextStyle _headerStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    letterSpacing: 1.5,
    fontWeight: FontWeight.bold,
    shadows: [
      Shadow(
        color: Colors.black,
        blurRadius: 2,
        offset: Offset(0, 2),
      ),
    ],
  );

  static const TextStyle _titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    shadows: [
      Shadow(
        color: Colors.black,
        blurRadius: 2,
        offset: Offset(0, 2),
      ),
    ],
  );

  static const TextStyle _subtitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.bold,
    shadows: [
      Shadow(
        color: Colors.black,
        blurRadius: 2,
        offset: Offset(0, 2),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final base = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(headerText, style: _headerStyle),
        const SizedBox(height: 8),
        Text(
          title,
          style: _titleStyle,
          maxLines: titleMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: _subtitleStyle,
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
        Positioned(
          right: 0,
          bottom: 0,
          child: t,
        ),
      ],
    );
  }
}
