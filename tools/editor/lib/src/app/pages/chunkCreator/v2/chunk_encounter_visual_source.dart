import 'package:flutter/material.dart';
import 'package:runner_core/encounters/encounter_definition.dart';

import '../../../../chunks/chunk_encounter_edit.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/scene_rectangle_gesture.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import 'chunk_encounter_projection.dart';

/// Loads the same catalog idle sources used by participant cards, then paints
/// authored facing and Core-resolved placement without becoming gameplay authority.
class ChunkEncounterVisualSource extends StatefulWidget {
  const ChunkEncounterVisualSource({
    super.key,
    required this.actors,
    required this.groups,
    required this.selected,
    required this.transform,
    required this.chunkSize,
    required this.authoring,
    required this.images,
  });
  final List<ChunkEncounterActorProjection> actors;
  final List<EncounterDefinition> groups;
  final ChunkEncounterSelection? selected;
  final TerrainPolygonViewportTransform transform;
  final Size chunkSize;
  final bool authoring;
  final EditorUiImageCache images;
  @override
  State<ChunkEncounterVisualSource> createState() =>
      _ChunkEncounterVisualSourceState();
}

class _ChunkEncounterVisualSourceState
    extends State<ChunkEncounterVisualSource> {
  final _requested = <String>{};
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ChunkEncounterVisualSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images != widget.images) _requested.clear();
    _load();
  }

  Future<void> _load() async {
    final paths = widget.actors
        .map((a) => a.frame?.absoluteSourcePath)
        .nonNulls
        .where(_requested.add)
        .toList();
    if (paths.isEmpty) return;
    await Future.wait(paths.map(widget.images.ensureLoaded));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _Painter(
      widget,
      Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
    ),
  );
}

class _Painter extends CustomPainter {
  const _Painter(this.source, this.labelStyle);
  final ChunkEncounterVisualSource source;
  final TextStyle labelStyle;
  @override
  void paint(Canvas canvas, Size size) {
    final t = source.transform;
    Offset point(Offset p) => t.origin + p * t.zoom;
    Rect rect(Rect r) =>
        Rect.fromPoints(point(r.topLeft), point(r.bottomRight));
    void label(String value, Offset position, Color color) {
      final text = TextPainter(
        text: TextSpan(
          text: value,
          style: labelStyle.copyWith(
            fontSize: 11,
            color: color,
            backgroundColor: const Color(0xdd101820),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, position);
    }

    if (source.authoring && source.selected != null) {
      canvas.drawRect(
        rect(Offset.zero & source.chunkSize),
        Paint()
          ..color = const Color(0xff66bb6a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      label(
        'NPC movement bounds · owning chunk',
        point(Offset.zero),
        const Color(0xffa5d6a7),
      );
    }
    if (source.authoring) {
      for (final group in source.groups) {
        final bounds = rect(encounterTriggerBounds(group));
        canvas.drawRect(bounds, Paint()..color = const Color(0x2239b9ff));
        canvas.drawRect(
          bounds,
          Paint()
            ..color = const Color(0xff39b9ff)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        label(
          '${group.name} · activation',
          bounds.topLeft + const Offset(2, 14),
          const Color(0xff80d8ff),
        );
        if (source.selected == ChunkEncounterSelection(group.id)) {
          for (final corner in SceneRectangleCorner.values) {
            paintTerrainRectangleHandle(
              canvas,
              corner.position(bounds),
              fill: const Color(0xff101820),
              stroke: const Color(0xff39b9ff),
            );
          }
        }
      }
    }
    for (final actor in source.actors) {
      final body = point(actor.body);
      final frame = actor.frame;
      final image = frame == null
          ? null
          : source.images.imageFor(frame.absoluteSourcePath);
      if (frame != null && image != null && frame.fits(image)) {
        canvas.save();
        canvas.translate(body.dx, body.dy);
        if (actor.member.facing != actor.artFacing) canvas.scale(-1, 1);
        canvas.drawImageRect(
          image,
          frame.sourceRect,
          frame.runtimeDestination(bodyPoint: Offset.zero, sceneZoom: t.zoom),
          Paint()..filterQuality = FilterQuality.none,
        );
        canvas.restore();
      }
      if (source.authoring) {
        final color = actor.diagnostic != null
            ? Colors.redAccent
            : actor.member is EncounterNpcPlacement
            ? Colors.lightGreenAccent
            : Colors.orangeAccent;
        final bounds = rect(actor.bounds);
        canvas.drawRect(
          bounds,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = source.selected == actor.selection ? 3 : 1,
        );
        label(
          '${actor.member.id}${actor.diagnostic == null ? '' : ' · invalid support'}',
          bounds.bottomLeft,
          color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Painter oldDelegate) => true;
}
