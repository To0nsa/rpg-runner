// Observable aim preview state for the UI layer.
//
// Provides reactive state so that UI widgets (e.g., aim indicators, arrows)
// can listen and update when the player begins aiming, moves the aim direction,
// or releases aim input. This decouples the input router from the rendering layer.
import 'package:flutter/foundation.dart';

/// Immutable snapshot of the current aim preview state.
///
/// - [active]: Whether the player is currently in aiming mode (e.g., touch held).
/// - [hasAim]: Whether a valid aim direction has been determined.
/// - [dirX], [dirY]: The normalized aim direction vector (only meaningful when [hasAim] is true).
class AimPreviewState {
  const AimPreviewState({
    required this.active,
    required this.hasAim,
    required this.dirX,
    required this.dirY,
  });

  /// True when the player is actively aiming (e.g., dragging on the cast button).
  final bool active;

  /// True when a valid direction has been established (drag exceeds dead zone).
  final bool hasAim;

  /// Horizontal component of the normalized aim direction.
  final double dirX;

  /// Vertical component of the normalized aim direction.
  final double dirY;

  /// Default state when the player is not aiming.
  static const AimPreviewState inactive = AimPreviewState(
    active: false,
    hasAim: false,
    dirX: 0,
    dirY: 0,
  );
}

/// Reactive model for aim preview state.
///
/// Extends [ValueNotifier] so UI widgets can listen for changes via
/// [ValueListenableBuilder] or similar patterns. The input layer updates this
/// model as the player interacts with aim controls, and the UI layer consumes
/// it to render visual feedback (e.g., directional arrow, aim reticle).
class AimPreviewModel extends ValueNotifier<AimPreviewState> {
  /// Creates an [AimPreviewModel] initialized to the inactive state.
  AimPreviewModel() : super(AimPreviewState.inactive);

  /// Called when the player starts an aiming gesture (e.g., touch down on cast button).
  ///
  /// Sets [active] to true but [hasAim] remains false until a direction is established.
  void begin() {
    value = const AimPreviewState(
      active: true,
      hasAim: false,
      dirX: 0,
      dirY: 0,
    );
  }

  /// Updates the aim direction during an active aiming gesture.
  ///
  /// [x] and [y] should be the normalized direction vector.
  /// Sets both [active] and [hasAim] to true.
  void updateAim(double x, double y) {
    value = AimPreviewState(active: true, hasAim: true, dirX: x, dirY: y);
  }

  /// Clears the aim direction while keeping the aiming gesture active.
  ///
  /// Used when the drag returns inside the dead zone—player is still touching
  /// but hasn't committed to a direction yet.
  void clearAim() {
    value = const AimPreviewState(
      active: true,
      hasAim: false,
      dirX: 0,
      dirY: 0,
    );
  }

  /// Called when the player ends the aiming gesture (e.g., touch up).
  ///
  /// Resets the model to the fully inactive state.
  void end() {
    value = AimPreviewState.inactive;
  }
}
