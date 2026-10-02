import '../tuning/score_tuning.dart';

/// Whole metres reached; every HUD, score and persisted result uses this scale.
int distanceUnitsToMeters(double distanceUnits) =>
    distanceUnits <= 0 ? 0 : (distanceUnits / kWorldUnitsPerMeter).floor();

/// Furthest horizontal progress from spawn, measured in world units.
///
/// Signed motion retains backtracking so retracing ground cannot earn distance
/// again. The motion authority excludes recovery corrections and collider
/// facing offsets before recording a tick. Vertical travel is not included.
class RunDistanceTracker {
  double _positionUnits = 0;
  double _furthestUnits = 0;

  double get distanceUnits => _furthestUnits;

  /// Records accepted signed body X motion in world units after collision.
  void recordMotion(double deltaUnits) {
    _positionUnits += deltaUnits;
    if (_positionUnits > _furthestUnits) {
      _furthestUnits = _positionUnits;
    }
  }
}
