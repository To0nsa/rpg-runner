// Math utilities for the game layer.
//
// Provides helper functions for common math operations that Dart's standard
// library doesn't handle correctly for game use cases (e.g., negative modulo,
// floor division with negative numbers).

import 'package:flame/components.dart';

import '../../core/util/vec2.dart';
import '../spatial/world_view_transform.dart';

/// Returns `value % mod`, always in the range `[0, mod)`.
///
/// Dart's `%` operator can return negative results for negative [value];
/// this function corrects that.
double positiveModDouble(double value, double mod) {
  if (mod <= 0) throw ArgumentError.value(mod, 'mod', 'must be > 0');
  final r = value % mod;
  return r < 0 ? r + mod : r;
}

/// Integer floor division that correctly handles negative dividends.
///
/// Dart's `~/` operator truncates toward zero, which gives incorrect results
/// for negative numbers when you want true floor division (toward -∞).
///
/// Example: `-1 ~/ 16` returns `0`, but `floorDivInt(-1, 16)` returns `-1`.
int floorDivInt(int a, int b) {
  if (b <= 0) throw ArgumentError.value(b, 'b', 'must be > 0');
  if (a >= 0) return a ~/ b;
  return -(((-a) + b - 1) ~/ b);
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

Vec2 lerpVec2(Vec2 a, Vec2 b, double t) =>
    Vec2(lerpDouble(a.x, b.x, t), lerpDouble(a.y, b.y, t));

double roundToPixels(double value) => value.roundToDouble();

/// Snaps a world coordinate to integer pixels in camera space.
///
/// Keeps [camera] fractional and rounds only the screen-space delta
/// (`world - camera`) to the nearest pixel.
double snapWorldToPixelsInCameraSpace1d(double world, double camera) =>
    camera + roundToPixels(world - camera);

/// Convenience 2D version of [snapWorldToPixelsInCameraSpace1d].
Vector2 snapWorldToPixelsInCameraSpace(Vec2 world, Vector2 camera) => Vector2(
  snapWorldToPixelsInCameraSpace1d(world.x, camera.x),
  snapWorldToPixelsInCameraSpace1d(world.y, camera.y),
);

/// Snaps a world X coordinate using an explicit [WorldViewTransform].
double snapWorldToPixelsInViewX(double worldX, WorldViewTransform transform) =>
    transform.viewToWorldX(roundToPixels(transform.worldToViewX(worldX)));

/// Snaps a world Y coordinate using an explicit [WorldViewTransform].
double snapWorldToPixelsInViewY(double worldY, WorldViewTransform transform) =>
    transform.viewToWorldY(roundToPixels(transform.worldToViewY(worldY)));
