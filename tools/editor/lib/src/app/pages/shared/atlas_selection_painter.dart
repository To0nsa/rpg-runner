import 'package:flutter/material.dart';

import '../../../atlas/atlas_pixel_rect.dart';

/// Named source-region overlay shown in a shared atlas viewport.
final class AtlasSelectionOverlay {
  const AtlasSelectionOverlay({required this.id, required this.rect});

  final String id;
  final AtlasPixelRect rect;
}

/// Draws existing and current source regions over a zoomed atlas image.
class AtlasSelectionPainter extends CustomPainter {
  const AtlasSelectionPainter({
    required this.zoom,
    required this.selection,
    this.existingRegions = const <AtlasSelectionOverlay>[],
    this.selectedRegionId,
  });

  final double zoom;
  final AtlasPixelRect? selection;
  final List<AtlasSelectionOverlay> existingRegions;
  final String? selectedRegionId;

  @override
  void paint(Canvas canvas, Size size) {
    final occupiedFill = Paint()
      ..color = const Color(0x1FECB365)
      ..style = PaintingStyle.fill;
    final occupiedStroke = Paint()
      ..color = const Color(0xFFE0A14A)
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;
    final selectedFill = Paint()
      ..color = const Color(0x3389F3B7)
      ..style = PaintingStyle.fill;
    final selectedStroke = Paint()
      ..color = const Color(0xFF89F3B7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final region in existingRegions) {
      final scaled = _scaled(region.rect);
      final isSelected = selectedRegionId == region.id;
      canvas.drawRect(scaled, isSelected ? selectedFill : occupiedFill);
      canvas.drawRect(scaled, isSelected ? selectedStroke : occupiedStroke);
    }

    final current = selection;
    if (current == null) return;
    final fill = Paint()
      ..color = const Color(0x5546C3FF)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF8AD8FF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(_scaled(current), fill);
    canvas.drawRect(_scaled(current), stroke);
  }

  Rect _scaled(AtlasPixelRect rect) => Rect.fromLTWH(
    rect.x * zoom,
    rect.y * zoom,
    rect.width * zoom,
    rect.height * zoom,
  );

  @override
  bool shouldRepaint(covariant AtlasSelectionPainter oldDelegate) =>
      oldDelegate.zoom != zoom ||
      oldDelegate.selection != selection ||
      oldDelegate.selectedRegionId != selectedRegionId ||
      oldDelegate.existingRegions != existingRegions;
}
