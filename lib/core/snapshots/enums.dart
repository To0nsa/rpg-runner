// Protocol-stable enums used by snapshots (and later networking).
//
// Keep these enums stable over time because they are part of the render
// contract and may become part of the network protocol.
//
// These enums are "logical" (game meaning), not asset/texture names.

/// Logical animation state (not tied to any specific texture or asset).
enum AnimKey {
  idle,
  run,
  jump,
  fall,
  hit,
  cast,
  death,
  spawn,
}

/// Broad entity classification used by the renderer and (later) networking.
enum EntityKind {
  player,
  enemy,
  projectile,
  obstacle,
  pickup,
  hazard,
  trigger,
}

/// Horizontal facing direction for animation/aiming.
enum Facing {
  left,
  right,
}
