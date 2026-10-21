/// Touch presentation only: all modes emit full-strength horizontal movement.
enum MovementControlMode {
  arrows,

  /// Floating base, confined to the left 33% of the run overlay.
  joystick,

  /// Stationary base at the lower-left movement anchor.
  fixedJoystick,
}
