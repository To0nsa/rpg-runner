import 'package:flutter/material.dart';

import '../../../text/ability_tooltip_builder.dart';
import '../../../theme/ui_tokens.dart';

class SkillsDetailsPane extends StatelessWidget {
  const SkillsDetailsPane({super.key, required this.tooltip});

  final AbilityTooltip? tooltip;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: _AbilityDetailsPane(tooltip: tooltip));
  }
}

class _AbilityDetailsPane extends StatelessWidget {
  const _AbilityDetailsPane({required this.tooltip});

  final AbilityTooltip? tooltip;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.25)),
      ),
      padding: EdgeInsets.all(ui.space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tooltip == null) ...[
            Text(
              'No ability available for this slot.',
              style: ui.text.body.copyWith(color: ui.colors.textMuted),
            ),
          ] else ...[
            Text(
              tooltip!.title,
              style: ui.text.headline.copyWith(color: ui.colors.textPrimary),
            ),
            SizedBox(height: ui.space.xxs),
            Text(
              tooltip!.subtitle,
              style: ui.text.body.copyWith(color: ui.colors.textMuted),
            ),
            if (tooltip!.badges.isNotEmpty) ...[
              SizedBox(height: ui.space.xs),
              Wrap(
                spacing: ui.space.xs,
                runSpacing: ui.space.xs,
                children: [
                  for (final badge in tooltip!.badges)
                    _AbilityBadge(text: badge),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AbilityBadge extends StatelessWidget {
  const _AbilityBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ui.space.xs,
        vertical: ui.space.xxs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ui.radii.sm),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: ui.text.caption.copyWith(color: ui.colors.textPrimary),
      ),
    );
  }
}
