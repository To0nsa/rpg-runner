/// Device-neutral gameplay actions accepted by runner input adapters.
///
/// These identifiers describe player intent only. Input sources remain
/// responsible for translating device-specific press, release, and axis events
/// into the appropriate action lifecycle.
enum RunnerGameplayAction {
  moveLeft,
  moveRight,
  jump,
  primary,
  secondary,
  projectile,
  spell,
  mobility,
}
