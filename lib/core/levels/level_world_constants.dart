/// Shared level framing constants (Core-owned).
library;

import '../contracts/spatial_contract.dart';

/// Default gameplay ground top for runner levels.
const int defaultLevelGroundTopYInt = 220;

/// Default gameplay ground top in world units.
const double defaultLevelGroundTopY = defaultLevelGroundTopYInt * 1.0;

/// Default camera center Y in world units.
const double defaultLevelCameraCenterY = virtualCameraCenterY;
