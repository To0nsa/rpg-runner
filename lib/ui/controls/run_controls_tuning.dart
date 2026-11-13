import 'controls_tuning.dart';
import '../theme/ui_action_button_theme.dart';

/// Shared run styling for the live controls and authoring preview.
ControlsTuning resolveRunControlsTuning({
  required ControlsTuning base,
  required UiActionButtonTheme actionButtons,
}) {
  final baseStyle = base.style;
  return ControlsTuning(
    layout: base.layout,
    moveButtons: base.moveButtons,
    moveJoystick: base.moveJoystick,
    style: ControlsStyleTuning(
      actionButton: actionButtons.resolveAction(
        base: baseStyle.actionButton,
        surface: UiActionButtonSurface.run,
      ),
      directionalActionButton: actionButtons.resolveDirectional(
        base: baseStyle.directionalActionButton,
        surface: UiActionButtonSurface.run,
      ),
      cooldownRing: baseStyle.cooldownRing,
      chargeBar: baseStyle.chargeBar,
    ),
  );
}
