import 'package:flutter/material.dart';

import '../../game/input/aim_preview.dart';
import 'action_button.dart';
import 'directional_action_button.dart';
import 'fixed_joystick.dart';
// import 'floating_joystick.dart';

class RunnerControlsOverlay extends StatelessWidget {
  const RunnerControlsOverlay({
    super.key,
    required this.onMoveAxis,
    required this.onJumpPressed,
    required this.onDashPressed,
    required this.onAttackPressed,
    required this.onCastCommitted,
    required this.onAimDir,
    required this.onAimClear,
    required this.aimPreview,
  });

  final ValueChanged<double> onMoveAxis;
  final VoidCallback onJumpPressed;
  final VoidCallback onDashPressed;
  final VoidCallback onAttackPressed;
  final VoidCallback onCastCommitted;
  final void Function(double x, double y) onAimDir;
  final VoidCallback onAimClear;
  final AimPreviewModel aimPreview;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 16,
            bottom: 16,
            // child: FloatingJoystick(onAxisChanged: onMoveAxis),
            child: FixedJoystick(onAxisChanged: onMoveAxis),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DirectionalActionButton(
                      label: 'Spell',
                      icon: Icons.auto_awesome,
                      onAimDir: onAimDir,
                      onAimClear: onAimClear,
                      onCommit: onCastCommitted,
                      aimPreview: aimPreview,
                    ),
                    const SizedBox(width: 12),
                    ActionButton(
                      label: 'Jump',
                      icon: Icons.arrow_upward,
                      onPressed: onJumpPressed,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ActionButton(
                      label: 'Atk',
                      icon: Icons.close,
                      onPressed: onAttackPressed,
                    ),
                    const SizedBox(width: 12),
                    ActionButton(
                      label: 'Dash',
                      icon: Icons.flash_on,
                      onPressed: onDashPressed,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
