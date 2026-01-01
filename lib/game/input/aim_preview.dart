import 'package:flutter/foundation.dart';

class AimPreviewState {
  const AimPreviewState({
    required this.active,
    required this.hasAim,
    required this.dirX,
    required this.dirY,
  });

  final bool active;
  final bool hasAim;
  final double dirX;
  final double dirY;

  static const AimPreviewState inactive = AimPreviewState(
    active: false,
    hasAim: false,
    dirX: 0,
    dirY: 0,
  );
}

class AimPreviewModel extends ValueNotifier<AimPreviewState> {
  AimPreviewModel() : super(AimPreviewState.inactive);

  void begin() {
    value = const AimPreviewState(
      active: true,
      hasAim: false,
      dirX: 0,
      dirY: 0,
    );
  }

  void updateAim(double x, double y) {
    value = AimPreviewState(active: true, hasAim: true, dirX: x, dirY: y);
  }

  void clearAim() {
    value = const AimPreviewState(
      active: true,
      hasAim: false,
      dirX: 0,
      dirY: 0,
    );
  }

  void end() {
    value = AimPreviewState.inactive;
  }
}
