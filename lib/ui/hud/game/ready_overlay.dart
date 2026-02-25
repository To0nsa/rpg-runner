import 'package:flutter/widgets.dart';

import '../../theme/ui_tokens.dart';

class ReadyOverlay extends StatelessWidget {
  const ReadyOverlay({super.key, required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final ui = context.ui;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: ui.colors.scrim.withValues(alpha: 0.53),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tap to start',
                style: ui.text.title.copyWith(
                  color: ui.colors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: ui.space.xs),
              Text(
                'Survive as long as possible',
                style: ui.text.body.copyWith(color: ui.colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
