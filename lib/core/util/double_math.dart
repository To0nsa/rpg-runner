/// Floating-point math helpers.
///
/// Supplements `dart:math` with common operations not in the standard library.
library;

import 'dart:math';

/// Clamps [v] to the range \[[lo], [hi]\].
///
/// Returns [lo] if `v < lo`, [hi] if `v > hi`, otherwise [v].
double clampDouble(double v, double lo, double hi) => max(lo, min(hi, v));

