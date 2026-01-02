import 'package:flutter/widgets.dart';

/// Floating horizontal joystick (V0).
///
/// - Touch anywhere inside the widget bounds to place the base.
/// - Drag left/right to set axis in `[-1, 1]`.
/// - Soft-follow: when dragged past the knob radius, the base eases toward the
///   pointer so the gesture stays comfortable.
/// - Release to snap back to center and hide.
class FloatingJoystick extends StatefulWidget {
  const FloatingJoystick({
    super.key,
    required this.onAxisChanged,
    this.areaSize = 220,
    this.baseSize = 120,
    this.knobSize = 56,
    this.followSmoothing = 0.25,
  });

  final ValueChanged<double> onAxisChanged;

  /// Size of the touch area (square).
  final double areaSize;

  /// Visual size of the joystick base circle.
  final double baseSize;

  /// Visual size of the joystick knob circle.
  final double knobSize;

  /// How strongly the base follows the pointer when stretched past the knob
  /// radius.
  ///
  /// - `0`: no follow (base stays where pressed).
  /// - `1`: hard follow (base snaps to keep the pointer on the edge).
  final double followSmoothing;

  @override
  State<FloatingJoystick> createState() => _FloatingJoystickState();
}

class _FloatingJoystickState extends State<FloatingJoystick> {
  int? _activePointer;
  Offset? _baseCenter;
  double _axis = 0;

  @override
  Widget build(BuildContext context) {
    final areaSize = widget.areaSize;
    final baseSize = widget.baseSize;
    final knobSize = widget.knobSize;
    final radius = (baseSize - knobSize) / 2;

    return SizedBox(
      width: areaSize,
      height: areaSize,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _onPointerDown(e, radius),
        onPointerMove: (e) => _onPointerMove(e, radius),
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Stack(
          children: [
            if (_baseCenter case final baseCenter?) ...[
              _JoystickBase(center: baseCenter, size: baseSize),
              _JoystickKnob(
                center: baseCenter.translate(_axis * radius, 0),
                size: knobSize,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event, double radius) {
    if (_activePointer != null) return;
    final center = _clampBaseCenter(event.localPosition);
    setState(() {
      _activePointer = event.pointer;
      _baseCenter = center;
      _axis = 0;
    });
    widget.onAxisChanged(0);
  }

  void _onPointerMove(PointerMoveEvent event, double radius) {
    if (event.pointer != _activePointer) return;
    final baseCenter = _baseCenter;
    if (baseCenter == null) return;

    final pointer = event.localPosition;

    var nextBaseCenter = baseCenter;
    if (radius > 0) {
      final delta = pointer - baseCenter;
      final dist = delta.distance;
      if (dist > radius && dist > 0) {
        final targetBaseCenter = pointer - (delta / dist) * radius;
        final t = widget.followSmoothing.clamp(0.0, 1.0).toDouble();
        nextBaseCenter =
            Offset.lerp(baseCenter, targetBaseCenter, t) ?? baseCenter;
        nextBaseCenter = _clampBaseCenter(nextBaseCenter);
      }
    }

    final dx = pointer.dx - nextBaseCenter.dx;
    final clamped = dx.clamp(-radius, radius);
    final axis = radius <= 0 ? 0.0 : clamped / radius;
    _setBaseAndAxis(baseCenter: nextBaseCenter, axis: axis);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _reset();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _reset();
  }

  Offset _clampBaseCenter(Offset local) {
    final areaSize = widget.areaSize;
    final baseSize = widget.baseSize;
    final halfBase = baseSize / 2;

    if (areaSize <= baseSize) {
      return Offset(areaSize / 2, areaSize / 2);
    }

    final clampedX = local.dx.clamp(halfBase, areaSize - halfBase).toDouble();
    final clampedY = local.dy.clamp(halfBase, areaSize - halfBase).toDouble();
    return Offset(clampedX, clampedY);
  }

  void _reset() {
    final shouldNotify = _axis != 0;
    setState(() {
      _activePointer = null;
      _baseCenter = null;
      _axis = 0;
    });
    if (shouldNotify) widget.onAxisChanged(0);
  }

  void _setBaseAndAxis({required Offset baseCenter, required double axis}) {
    final nextAxis = axis.clamp(-1.0, 1.0);
    final axisChanged = nextAxis != _axis;
    final baseChanged = baseCenter != _baseCenter;
    if (!axisChanged && !baseChanged) return;

    setState(() {
      _baseCenter = baseCenter;
      _axis = nextAxis;
    });
    if (axisChanged) widget.onAxisChanged(nextAxis);
  }
}

class _JoystickBase extends StatelessWidget {
  const _JoystickBase({required this.center, required this.size});

  final Offset center;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x55FFFFFF)),
        ),
      ),
    );
  }
}

class _JoystickKnob extends StatelessWidget {
  const _JoystickKnob({required this.center, required this.size});

  final Offset center;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x66FFFFFF),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x88FFFFFF)),
        ),
      ),
    );
  }
}
