/// Defines shared spatial coordinate contract constants.
///
/// This file intentionally contains coordinate-system primitives only.
/// Asset-specific alignment constants stay outside this contract.
library;

/// Fixed virtual viewport width used by gameplay and rendering.
const int virtualViewportWidth = 600;

/// Fixed virtual viewport height used by gameplay and rendering.
const int virtualViewportHeight = 270;

/// Camera center X for the default fixed-resolution runner framing.
const double virtualCameraCenterX = virtualViewportWidth / 2;

/// Camera center Y for the default fixed-resolution runner framing.
const double virtualCameraCenterY = virtualViewportHeight / 2;

/// In world/view coordinates, increasing Y moves downward on screen.
const bool yAxisPointsDown = true;
