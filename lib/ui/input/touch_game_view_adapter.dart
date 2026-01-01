import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../game/game_controller.dart';
import '../../game/input/runner_input_router.dart';
import 'v0_viewport_mapper.dart';

/// Handles touch interactions on the game view (V0).
///
/// - Optional tap-to-cast (disabled by default).
class TouchGameViewAdapter extends StatelessWidget {
  const TouchGameViewAdapter({
    super.key,
    required this.controller,
    required this.input,
    required this.mapper,
    required this.child,
    this.enableTapCast = false,
  });

  final GameController controller;
  final RunnerInputRouter input;
  final V0ViewportMapper mapper;
  final Widget child;
  final bool enableTapCast;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        if (!enableTapCast) return;
        if (e.kind == PointerDeviceKind.mouse) return;
        final dir = mapper.aimDirFromLocal(e.localPosition, controller.snapshot);
        if (dir != null) {
          input.setAimDir(dir.x, dir.y);
          input.pressCastWithAim();
        } else {
          input.pressCast();
        }
      },
      child: child,
    );
  }
}
