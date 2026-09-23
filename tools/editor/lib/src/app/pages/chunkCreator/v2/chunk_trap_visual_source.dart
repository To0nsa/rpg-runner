import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/trap_snapshot.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:rpg_runner/game/components/traps/trap_cue_painter.dart';

import '../../shared/editor_scene_view_utils.dart';
import '../../shared/scene_rectangle_gesture.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import 'chunk_trap_gesture.dart';

enum ChunkTrapVisualPass { idle, active, overlay }

/// Same reviewed art and cue painter as the game, partitioned around terrain.
class ChunkTrapVisualSource extends StatefulWidget {
  const ChunkTrapVisualSource({
    super.key,
    required this.workspaceRootPath,
    required this.images,
    required this.traps,
    required this.selected,
    required this.previewFrame,
    required this.transform,
    required this.pass,
    this.authoring = false,
    this.invalid = false,
  });
  final String workspaceRootPath;
  final EditorUiImageCache images;
  final List<TrapPlacement> traps;
  final TrapPlacement? selected;
  final int previewFrame;
  final TerrainPolygonViewportTransform transform;
  final ChunkTrapVisualPass pass;
  final bool authoring, invalid;
  @override
  State<ChunkTrapVisualSource> createState() => _TrapVisualState();
}

class _TrapVisualState extends State<ChunkTrapVisualSource> {
  final Set<String> _requested = {};
  final Set<String> _failed = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ChunkTrapVisualSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images != widget.images ||
        oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _requested.clear();
      _failed.clear();
    }
    _load();
  }

  String _path(TrapPlacement trap) => p.normalize(
    p.join(
      widget.workspaceRootPath,
      'assets/images',
      TrapCatalog.get(trap.trapId).assetPath,
    ),
  );
  void _load() {
    for (final trap in widget.traps) {
      final path = _path(trap);
      if (!_requested.add(path)) continue;
      final cache = widget.images;
      () async {
        final image = await cache.ensureLoaded(path);
        if (!mounted || widget.images != cache) return;
        setState(() {
          if (image == null) _failed.add(path);
        });
      }();
    }
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TrapPainter(
      traps: widget.traps,
      selected: widget.selected,
      frame: widget.previewFrame,
      transform: widget.transform,
      pass: widget.pass,
      authoring: widget.authoring,
      invalid: widget.invalid,
      images: {
        for (final trap in widget.traps)
          trap.trapId: widget.images.imageFor(_path(trap)),
      },
      missing: {
        for (final trap in widget.traps)
          if (_failed.contains(_path(trap))) trap.trapId,
      },
    ),
  );
}

class _TrapPainter extends CustomPainter {
  _TrapPainter({
    required this.traps,
    required this.selected,
    required this.frame,
    required this.transform,
    required this.pass,
    required this.authoring,
    required this.invalid,
    required this.images,
    required this.missing,
  });
  final List<TrapPlacement> traps;
  final TrapPlacement? selected;
  final int frame;
  final TerrainPolygonViewportTransform transform;
  final ChunkTrapVisualPass pass;
  final bool authoring, invalid;
  final Map<TrapId, ui.Image?> images;
  final Set<TrapId> missing;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(transform.origin.dx, transform.origin.dy);
    canvas.scale(transform.zoom);
    for (final trap in traps) {
      final def = TrapCatalog.get(trap.trapId);
      final index = trap == selected && frame >= 0
          ? frame.clamp(0, def.frames.length - 1)
          : def.idleFrameIndex;
      final phase = trap != selected || frame < 0
          ? TrapPhase.idle
          : index < def.firstHarmfulFrame
          ? TrapPhase.warning
          : TrapPhase.active;
      final active = phase != TrapPhase.idle;
      if (pass == ChunkTrapVisualPass.overlay) {
        if (authoring) {
          final bounds = trapTriggerBounds(trap);
          final color = trap == selected && invalid
              ? Colors.redAccent
              : Colors.lightBlueAccent;
          canvas.drawRect(
            bounds,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1 / transform.zoom,
          );
          if (trap == selected) {
            for (final corner in SceneRectangleCorner.values) {
              canvas.drawRect(
                Rect.fromCenter(
                  center: corner.position(bounds),
                  width: 6 / transform.zoom,
                  height: 6 / transform.zoom,
                ),
                Paint()..color = color,
              );
            }
            paintTrapDamagePose(
              canvas,
              definition: def,
              frameIndex: index,
              x: trap.x.toDouble(),
              y: trap.y.toDouble(),
              facing: trap.facing,
            );
            if (trap.trapId == TrapId.poisonDarts) {
              final sign = trap.facing == Facing.left ? -1 : 1;
              final muzzle = Offset(
                trap.x + def.muzzle.x * sign,
                trap.y + def.muzzle.y,
              );
              final paint = Paint()
                ..color = Colors.redAccent
                ..strokeWidth = 1 / transform.zoom;
              canvas.drawCircle(muzzle, TrapCatalog.dartRadius, paint);
              canvas.drawLine(muzzle, muzzle + Offset(48.0 * sign, 0), paint);
            }
          }
        }
        paintTrapCue(
          canvas,
          definition: def,
          x: trap.x.toDouble(),
          y: trap.y.toDouble(),
          facing: trap.facing,
          phase: phase,
        );
        continue;
      }
      if ((pass == ChunkTrapVisualPass.active) != active) continue;
      final source = def.frames[index].source;
      final image = images[trap.trapId];
      canvas.save();
      canvas.translate(trap.x.toDouble(), trap.y.toDouble());
      if (trap.facing == Facing.left) canvas.scale(-1, 1);
      final destination = Rect.fromLTWH(
        -def.anchor.x,
        -def.anchor.y,
        source.width.toDouble(),
        source.height.toDouble(),
      );
      if (image != null &&
          source.x + source.width <= image.width &&
          source.y + source.height <= image.height) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            source.x.toDouble(),
            source.y.toDouble(),
            source.width.toDouble(),
            source.height.toDouble(),
          ),
          destination,
          Paint()..filterQuality = FilterQuality.none,
        );
      } else if (image != null || missing.contains(trap.trapId)) {
        canvas.drawRect(destination, Paint()..color = const Color(0x66FF00FF));
        final label = TextPainter(
          text: const TextSpan(
            text: 'Missing / invalid trap art',
            style: TextStyle(fontSize: 10, color: Colors.white),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: destination.width);
        label.paint(canvas, destination.topLeft);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrapPainter oldDelegate) => true;
}
