import 'package:flutter/material.dart';

import '../theme/ui_tokens.dart';

enum GoldDisplayVariant { body, headline }

class GoldDisplay extends StatelessWidget {
  const GoldDisplay({
    super.key,
    required this.gold,
    this.label,
    this.variant = GoldDisplayVariant.headline,
  });

  final int gold;
  final String? label;
  final GoldDisplayVariant variant;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final valueStyle = switch (variant) {
      GoldDisplayVariant.body => ui.text.body.copyWith(
        color: ui.colors.textPrimary,
      ),
      GoldDisplayVariant.headline => ui.text.headline.copyWith(
        color: ui.colors.textPrimary,
      ),
    };
    final iconSize = switch (variant) {
      GoldDisplayVariant.body => ui.sizes.iconSize.xs,
      GoldDisplayVariant.headline => ui.sizes.iconSize.sm,
    };

    final resolvedLabel = label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (resolvedLabel != null && resolvedLabel.isNotEmpty) ...[
          Text(
            resolvedLabel,
            style: ui.text.body.copyWith(color: ui.colors.textMuted),
          ),
          SizedBox(width: ui.space.sm),
        ],
        Text(gold.toString(), style: valueStyle),
        SizedBox(width: ui.space.xs),
        Icon(
          Icons.monetization_on,
          color: ui.colors.accentStrong,
          size: iconSize,
        ),
      ],
    );
  }
}
