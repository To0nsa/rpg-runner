import 'package:flutter/material.dart';

import '../theme/ui_tokens.dart';

/// Labelled, bounded progress fill shared by discoveries and achievements.
/// Animation and canonical accessibility values remain with the owning widget.
class ProgressMeter extends StatelessWidget {
  const ProgressMeter({super.key, required this.fraction, required this.label});
  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui.radii.sm),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: ColoredBox(color: ui.colors.background)),
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0, 1),
                heightFactor: 1,
                child: ColoredBox(
                  color: ui.colors.accentStrong.withValues(alpha: .35),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(ui.space.xs),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: ui.text.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
