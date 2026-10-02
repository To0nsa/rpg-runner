import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';

import '../../../../chunks/chunk_pocket_projection.dart';
import '../../shared/terrain_polygon_scene_painter.dart';

/// Read-only pocket diagnostics for accepted, unsaved Chunk geometry.
///
/// Recomputes off the UI isolate after edits/undo/source refresh, never in build.
/// Draft gestures hide old evidence; generation guards discard obsolete results.
class ChunkPocketOverlay extends StatefulWidget {
  const ChunkPocketOverlay({
    super.key,
    required this.geometry,
    required this.transform,
    required this.paused,
  });

  final TerrainGeometry? geometry;
  final TerrainPolygonViewportTransform transform;
  final bool paused;

  @override
  State<ChunkPocketOverlay> createState() => _ChunkPocketOverlayState();
}

class _ChunkPocketOverlayState extends State<ChunkPocketOverlay> {
  List<ChunkPocketWarning> _warnings = const [];
  Timer? _debounce;
  int _generation = 0;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant ChunkPocketOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.geometry, oldWidget.geometry) ||
        widget.paused != oldWidget.paused) {
      _refresh();
    }
  }

  void _refresh() {
    _debounce?.cancel();
    final generation = ++_generation;
    _warnings = const [];
    _failed = false;
    final geometry = widget.geometry;
    _loading = geometry != null && !widget.paused;
    if (!_loading) return;
    // Coalesce rapid source notifications; pan and zoom never restart work.
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      try {
        final warnings = await compute(buildChunkPocketWarnings, geometry!);
        if (!mounted || generation != _generation) return;
        setState(() {
          _warnings = warnings;
          _loading = false;
        });
      } catch (_) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String summary;
    if (widget.paused) {
      summary = 'Pocket warnings paused — finish the current edit.';
    } else if (widget.geometry == null) {
      summary = 'Pocket warnings unavailable — fix collision validation.';
    } else if (_failed) {
      summary = 'Pocket check failed. Toggle Pockets to retry.';
    } else if (_loading) {
      summary = 'Checking pockets…';
    } else if (_warnings.isEmpty) {
      summary = 'No steep-sided fall pockets detected.';
    } else {
      summary = [
        for (final (index, warning) in _warnings.indexed)
          'Pocket ${index + 1}: ${warning.actors.join(', ')}',
      ].join('\n');
    }
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            key: const ValueKey('chunk_pocket_zones'),
            painter: ChunkPocketPainter(
              warnings: _warnings,
              transform: widget.transform,
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                color: const Color(0xE6202020),
                child: Text(
                  summary,
                  key: const ValueKey('chunk_pocket_summary'),
                  style: TextStyle(
                    fontSize: 11,
                    color: _warnings.isEmpty
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFFFCA5A5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shades the physical pocket, not an actor's enclosing bounding rectangle.
class ChunkPocketPainter extends CustomPainter {
  const ChunkPocketPainter({required this.warnings, required this.transform});

  final List<ChunkPocketWarning> warnings;
  final TerrainPolygonViewportTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final (index, warning) in warnings.indexed) {
      final vertices = warning.pocket.outline.map(_canvasPoint).toList();
      final path = Path()..addPolygon(vertices, true);
      canvas.drawPath(path, Paint()..color = const Color(0x66EF4444));
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFEF4444)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${index + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0xFFB91C1C),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        _canvasPoint(warning.pocket.center) -
            Offset(label.width / 2, label.height / 2),
      );
      label.dispose();
    }
    canvas.restore();
  }

  Offset _canvasPoint(TerrainPoint p) =>
      transform.origin +
      Offset(
        p.xTicks / terrainPhysicsTicksPerWorldUnit * transform.zoom,
        p.yTicks / terrainPhysicsTicksPerWorldUnit * transform.zoom,
      );

  @override
  bool shouldRepaint(covariant ChunkPocketPainter oldDelegate) =>
      !identical(warnings, oldDelegate.warnings) ||
      transform.origin != oldDelegate.transform.origin ||
      transform.zoom != oldDelegate.transform.zoom;
}
