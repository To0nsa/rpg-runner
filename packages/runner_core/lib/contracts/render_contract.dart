/// Defines the virtual resolution and coordinate system constants for the valid
/// gameplay area.
///
/// These values are the "truth" for the simulation and the renderer.
/// The renderer scales this virtual viewport to fit the actual screen.
library;

import 'spatial_contract.dart';

/// The fixed virtual width of the gameplay view in logic units (pixels).
const int virtualWidth = virtualViewportWidth;

/// The fixed virtual height of the gameplay view in logic units (pixels).
const int virtualHeight = virtualViewportHeight;

// -- Gameplay Constants --

/// Length of the ray cast for projectile aiming.
const double projectileAimRayLength = virtualWidth * 0.5;

/// Length of the ray cast for melee aiming.
const double meleeAimRayLength = virtualWidth * 0.20;
