/// Fixed-point math helpers for deterministic simulation.
///
/// Units:
/// - Fixed100: 100 = 1.00
/// - Basis Points (bp): 100 = 1%, 10000 = 100%
library;

import 'dart:math';

const int fixedScale = 100;
const int bpScale = 10000;

/// Converts a double to fixed-point (100 = 1.0).
int toFixed100(double value) => (value * fixedScale).round();

/// Converts a double to basis points (100 = 1%).
int toBp(double value) => (value * bpScale).round();

/// Converts fixed-point (100 = 1.0) to double.
double fromFixed100(int value) => value / fixedScale;

/// Clamps [v] to the range [lo, hi].
int clampInt(int v, int lo, int hi) => max(lo, min(hi, v));

/// Scales [value] by a basis-point modifier.
///
/// Example: value=1000, bonusBp=2000 (+20%) -> 1200.
int applyBp(int value, int bonusBp) =>
    (value * (bpScale + bonusBp)) ~/ bpScale;

