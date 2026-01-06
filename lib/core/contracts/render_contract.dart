/// Defines the virtual resolution and coordinate system constants for the valid
/// gameplay area.
///
/// These values are the "truth" for the simulation and the renderer.
/// The renderer scales this virtual viewport to fit the actual screen.
library;

/// The fixed virtual width of the gameplay view in logic units (pixels).
const int virtualWidth = 600;

/// The fixed virtual height of the gameplay view in logic units (pixels).
const int virtualHeight = 270;

// -- Asset / Layer dimensions --

/// Width of the background/field layer images.
const int fieldLayerImageWidth = 512;

/// Height of the background/field layer images.
const int fieldLayerImageHeight = 256;

/// Vertical offset to align the bottom of the field layer image with the
/// bottom of the virtual viewport.
///
/// `virtualHeight (270) - fieldLayerImageHeight (256) = 14`.
const int fieldLayerBottomAlignedOffsetY =
    virtualHeight - fieldLayerImageHeight; // 14

/// The Y-coordinate within the field layer image where the ground visual
/// starts (opaque top). Based on asset analysis.
/// used to calculate [groundTopY].
const int fieldLayer09OpaqueTopInImageY = 241;

/// The world-space Y coordinate of the ground surface.
///
/// Calculated as `fieldLayerBottomAlignedOffsetY + fieldLayer09OpaqueTopInImageY`.
/// Entities standing on the ground will have their `maxY` at this value.
const int groundTopY =
    fieldLayerBottomAlignedOffsetY + fieldLayer09OpaqueTopInImageY; // 255

/// The fixed Y coordinate for the camera center.
///
/// The camera only scrolls horizontally.
const double cameraFixedY = virtualHeight / 2; // 135.0

// -- Gameplay Constants --

/// Length of the ray cast for projectile aiming.
const double projectileAimRayLength = virtualWidth * 0.5;

/// Length of the ray cast for melee aiming.
const double meleeAimRayLength = virtualWidth * 0.20;
