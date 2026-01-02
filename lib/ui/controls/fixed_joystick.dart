import 'package:flutter/widgets.dart';

/// Fixed-position horizontal joystick (V0).
///
/// - Only outputs an X axis in `[-1, 1]`.
/// - Centered at the widget's bounds; drag left/right to set axis.
class FixedJoystick extends StatefulWidget {
  const FixedJoystick({
    super.key,
    required this.onAxisChanged,
    this.size = 120,
    this.knobSize = 56,
    this.baseColor = const Color(0x33000000),
    this.baseBorderColor = const Color(0x55FFFFFF),
    this.baseBorderWidth = 1,
    this.knobColor = const Color(0x66FFFFFF),
    this.knobBorderColor = const Color(0x88FFFFFF),
    this.knobBorderWidth = 1,
  });

  final ValueChanged<double> onAxisChanged;
  final double size;
  final double knobSize;
  final Color baseColor;
  final Color baseBorderColor;
  final double baseBorderWidth;
  final Color knobColor;
  final Color knobBorderColor;
  final double knobBorderWidth;

  @override
  State<FixedJoystick> createState() => _FixedJoystickState();
}

class _FixedJoystickState extends State<FixedJoystick> {
  double _axis = 0;

  @override
  Widget build(BuildContext context) {
    final baseSize = widget.size;
    final knobSize = widget.knobSize;
    final radius = (baseSize - knobSize) / 2;

    return SizedBox(
      width: baseSize,
      height: baseSize,
      child: GestureDetector(
        onPanStart: (d) => _update(d.localPosition, radius),
        onPanUpdate: (d) => _update(d.localPosition, radius),
        onPanEnd: (_) => _setAxis(0),
        onPanCancel: () => _setAxis(0),
        child: CustomPaint(
          painter: _JoystickPainter(axis: _axis),
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: baseSize,
                    height: baseSize,
                    decoration: BoxDecoration(
                      color: widget.baseColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.baseBorderColor,
                        width: widget.baseBorderWidth,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(_axis * radius, 0),
                    child: Container(
                      width: knobSize,
                      height: knobSize,
                      decoration: BoxDecoration(
                        color: widget.knobColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.knobBorderColor,
                          width: widget.knobBorderWidth,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _update(Offset local, double radius) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final dx = local.dx - center.dx;
    final clamped = dx.clamp(-radius, radius);
    final axis = radius <= 0 ? 0.0 : clamped / radius;
    _setAxis(axis);
  }

  void _setAxis(double axis) {
    final a = axis.clamp(-1.0, 1.0);
    if (a == _axis) return;
    setState(() => _axis = a);
    widget.onAxisChanged(a);
  }
}

class _JoystickPainter extends CustomPainter {
  const _JoystickPainter({required this.axis});

  final double axis;

  @override
  void paint(Canvas canvas, Size size) {
    // No-op; visuals are via Containers. Keep painter for future extensions.
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.axis != axis;
}
