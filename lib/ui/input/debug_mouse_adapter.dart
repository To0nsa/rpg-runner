import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../game/game_controller.dart';
import '../../game/input/runner_input_router.dart';
import 'v0_viewport_mapper.dart';

/// Debug-only mouse adapter (not part of V0 mobile input).
///
/// - Move: updates AimDir.
/// - Left click: Attack.
/// - Middle click (or tertiary): Dash.
/// - Right click: Cast with aim.
class DebugMouseAdapter extends StatelessWidget {
  const DebugMouseAdapter({
    super.key,
    required this.controller,
    required this.input,
    required this.mapper,
    required this.child,
    this.enabled = kDebugMode,
  });

  final GameController controller;
  final RunnerInputRouter input;
  final V0ViewportMapper mapper;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (e) {
        if (e.kind != PointerDeviceKind.mouse) return;
        final dir = mapper.aimDirFromLocal(e.localPosition, controller.snapshot);
        if (dir == null) return;
        input.setAimDir(dir.x, dir.y);
      },
      onPointerMove: (e) {
        if (e.kind != PointerDeviceKind.mouse) return;
        final dir = mapper.aimDirFromLocal(e.localPosition, controller.snapshot);
        if (dir == null) return;
        input.setAimDir(dir.x, dir.y);
      },
      onPointerDown: (e) {
        if (e.kind != PointerDeviceKind.mouse) return;

        final dir = mapper.aimDirFromLocal(e.localPosition, controller.snapshot);
        if (dir != null) {
          input.setAimDir(dir.x, dir.y);
        }

        final b = e.buttons;

        final isDash = (b & kMiddleMouseButton) != 0 || (b & kTertiaryButton) != 0;
        final isAttack = (b & kPrimaryButton) != 0;
        final isCast = (b & kSecondaryButton) != 0;

        if (isDash) input.pressDash();
        if (isAttack) input.pressAttack();
        if (isCast) input.pressCastWithAim();
      },
      child: child,
    );
  }
}
