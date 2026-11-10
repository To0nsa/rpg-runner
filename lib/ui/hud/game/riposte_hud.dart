import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/widgets.dart';

import '../../components/hud_frame.dart';
import '../../theme/ui_tokens.dart';

/// Displays Core's counterattack window without advancing it on the UI clock.
class RiposteHud extends StatelessWidget {
  const RiposteHud({
    super.key,
    required this.ticksLeft,
    required this.guarding,
    required this.tickHz,
  });
  final int ticksLeft;
  final bool guarding;
  final int tickHz;

  @override
  Widget build(BuildContext context) {
    if (ticksLeft <= 0) return const SizedBox.shrink();
    return HudPanel(
      padding: EdgeInsets.all(context.ui.space.xs),
      child: Text(
        guarding
            ? context.l10n.riposteReady
            : context.l10n.riposteCountdown(seconds: ticksLeft / tickHz),
      ),
    );
  }
}
