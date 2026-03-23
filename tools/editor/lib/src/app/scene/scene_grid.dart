part of '../editor_home_page.dart';

class _ViewportPixelGridPainter extends CustomPainter {
  const _ViewportPixelGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _paintGridLayer(canvas, size, spacingPx: 1, color: const Color(0x0D9FB4C7));
    _paintGridLayer(
      canvas,
      size,
      spacingPx: 16,
      color: const Color(0x1E9FB4C7),
    );
    _paintGridLayer(
      canvas,
      size,
      spacingPx: 32,
      color: const Color(0x389FB4C7),
    );
  }

  void _paintGridLayer(
    Canvas canvas,
    Size size, {
    required int spacingPx,
    required Color color,
  }) {
    if (spacingPx <= 0) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (var x = 0; x <= size.width; x += spacingPx) {
      final alignedX = x + 0.5;
      canvas.drawLine(
        Offset(alignedX, 0),
        Offset(alignedX, size.height),
        paint,
      );
    }
    for (var y = 0; y <= size.height; y += spacingPx) {
      final alignedY = y + 0.5;
      canvas.drawLine(Offset(0, alignedY), Offset(size.width, alignedY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ViewportPixelGridPainter oldDelegate) => false;
}
