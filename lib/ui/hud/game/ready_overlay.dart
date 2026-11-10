import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/widgets.dart';

import '../../theme/ui_tokens.dart';

class ReadyOverlay extends StatelessWidget {
  const ReadyOverlay({
    super.key,
    required this.visible,
    required this.onTap,
    this.desktop = false,
  });

  final bool visible;
  final bool desktop;
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
                desktop
                    ? context.l10n.desktopStartHint
                    : context.l10n.touchStartHint,
                style: ui.text.title.copyWith(
                  color: ui.colors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: ui.space.xs),
              Text(
                context.l10n.survivalGoal,
                style: ui.text.body.copyWith(color: ui.colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
