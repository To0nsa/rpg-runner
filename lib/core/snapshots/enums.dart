/// Protocol-stable enums used by snapshots and the Core→Renderer contract.
///
/// **Stability**: These enums may become part of the network protocol for
/// replays or multiplayer. Avoid renaming or reordering values.
///
/// **Scope**: These are "logical" game concepts, not tied to specific
/// textures or asset names. The renderer maps them to visuals.
library;

/// Logical animation state for entity rendering.
///
/// The renderer maps these to sprite sheets or animation clips.
enum AnimKey {
  idle,
  run,
  jump,
  fall,
  hit,
  cast,
  death,
  spawn,
  attack,
  dash,
  walk,
  attackBack,
  ranged,
}

/// Broad entity classification for rendering and (future) networking.
///
/// Used to select visual style, collision layer, and render order.
enum EntityKind {
  player,
  enemy,
  projectile,
  obstacle,
  pickup,
  hazard,
  trigger,
}

/// Horizontal facing direction for sprites and directional abilities.
enum Facing {
  left,
  right,
}
