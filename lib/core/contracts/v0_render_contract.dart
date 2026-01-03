/// V0 render + coordinate contract shared across layers.
///
/// These values are intentionally defined in `lib/core/**` (pure Dart) so Core,
/// Render (Flame), and UI (Flutter) can all agree on the same coordinate system
/// without introducing Flutter/Flame dependencies into the simulation.
///
/// V0 rules:
/// - Virtual resolution is fixed at 600×270 (20:9).
/// - 1 world unit == 1 virtual pixel.
/// - Axes/origin follow Flutter/Flame conventions: (0,0) top-left, +X right,
///   +Y down.
/// - Camera uses a fixed-resolution viewport and integer snapping.
///
/// Ground reference:
/// - The parallax set assets are 512×256.
/// - For `Field Layer 09.png`, the first non-transparent row starts at Y=241
///   within the image (measured from the asset in this repo).
/// - When bottom-aligning the 256px image into a 270px viewport, Y offset is
///   (270 - 256) = 14, therefore `v0GroundTopY = 14 + 241 = 255`.
const int v0VirtualWidth = 600;
const int v0VirtualHeight = 270;

const int v0FieldLayerImageWidth = 512;
const int v0FieldLayerImageHeight = 256;

const int v0FieldLayerBottomAlignedOffsetY =
    v0VirtualHeight - v0FieldLayerImageHeight; // 14

const int v0FieldLayer09OpaqueTopInImageY = 241;
const int v0GroundTopY =
    v0FieldLayerBottomAlignedOffsetY + v0FieldLayer09OpaqueTopInImageY; // 255

const double v0CameraFixedY = v0VirtualHeight / 2; // 135.0

const double v0ProjectileAimRayLength = v0VirtualWidth * 0.5;
const double v0MeleeAimRayLength = v0VirtualWidth * 0.20;
