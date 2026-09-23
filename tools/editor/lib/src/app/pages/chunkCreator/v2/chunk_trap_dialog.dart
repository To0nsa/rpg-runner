import 'package:flutter/material.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_geometry.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../terrain_authoring/terrain_axis_aligned_rectangle.dart';
import '../../shared/terrain_polygon_rectangle_editor.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import 'chunk_trap_gesture.dart';
import 'chunk_trap_panel.dart';
import 'chunk_trap_visual_source.dart';

Future<TrapPlacement?> showChunkTrapDialog(
  BuildContext context, {
  required ChunkV2FileData chunk,
  required TrapPlacement source,
  required String workspaceRootPath,
  required EditorUiImageCache images,
  bool duplicate = false,
}) => showDialog<TrapPlacement>(
  context: context,
  builder: (_) => _TrapDialog(
    chunk: chunk,
    source: source,
    duplicate: duplicate,
    workspaceRootPath: workspaceRootPath,
    images: images,
  ),
);

class _TrapDialog extends StatefulWidget {
  const _TrapDialog({
    required this.chunk,
    required this.source,
    required this.duplicate,
    required this.workspaceRootPath,
    required this.images,
  });
  final ChunkV2FileData chunk;
  final TrapPlacement source;
  final bool duplicate;
  final String workspaceRootPath;
  final EditorUiImageCache images;
  @override
  State<_TrapDialog> createState() => _TrapDialogState();
}

class _TrapDialogState extends State<_TrapDialog> {
  late final _x = TextEditingController(
    text: '${widget.source.x + (widget.duplicate ? widget.chunk.tileSize : 0)}',
  );
  late final _y = TextEditingController(text: '${widget.source.y}');
  late Facing _facing = widget.source.facing;
  String? _error;
  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trigger = widget.source.trigger;
    final preview = widget.source.copyWith(facing: _facing);
    return AlertDialog(
      title: Text(
        '${widget.duplicate ? 'Duplicate' : 'Edit'} ${trapDisplayName(widget.source.trapId)}',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final pass in [
                      ChunkTrapVisualPass.active,
                      ChunkTrapVisualPass.overlay,
                    ])
                      ChunkTrapVisualSource(
                        workspaceRootPath: widget.workspaceRootPath,
                        images: widget.images,
                        traps: [preview],
                        selected: preview,
                        previewFrame: TrapCatalog.get(preview.trapId)
                            .firstHarmfulFrame,
                        transform: TerrainPolygonViewportTransform(
                          origin: Offset(220.0 - preview.x, 60.0 - preview.y),
                          zoom: 1,
                        ),
                        pass: pass,
                        authoring: true,
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chunk_trap_x'),
                      controller: _x,
                      decoration: const InputDecoration(
                        labelText: 'Anchor X (px)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chunk_trap_y'),
                      controller: _y,
                      decoration: const InputDecoration(
                        labelText: 'Anchor Y (px)',
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.source.trapId != TrapId.spike)
                SegmentedButton<Facing>(
                  segments: [
                    for (final facing in Facing.values)
                      ButtonSegment(value: facing, label: Text(facing.name)),
                  ],
                  selected: {_facing},
                  onSelectionChanged: (values) =>
                      setState(() => _facing = values.single),
                ),
              const SizedBox(height: 12),
              const Text(
                'Trigger offsets from the anchor. Facing mirrors art and damage, and keeps these offsets unchanged.',
              ),
              TerrainPolygonRectangleEditor(
                keyPrefix: 'chunk_trap_trigger',
                coordinateStepHalfPixels: 2,
                rectangle: TerrainAxisAlignedRectangle.tryCreate(
                  xHalfPixels: trigger.offsetX * 2,
                  yHalfPixels: trigger.offsetY * 2,
                  widthHalfPixels: trigger.width * 2,
                  heightHalfPixels: trigger.height * 2,
                )!,
                applyLabel: widget.duplicate ? 'Add copy' : 'Apply trap edit',
                onApply:
                    ({
                      required xHalfPixels,
                      required bottomYHalfPixels,
                      required widthHalfPixels,
                      required heightHalfPixels,
                    }) {
                      final x = int.tryParse(_x.text.trim()),
                          y = int.tryParse(_y.text.trim());
                      if (x == null || y == null) {
                        setState(
                          () => _error = 'Use whole-pixel anchor coordinates.',
                        );
                        return false;
                      }
                      final candidate = widget.source.copyWith(
                        x: x,
                        y: y,
                        facing: _facing,
                        trigger: TrapRect(
                          xHalfPixels ~/ 2,
                          (bottomYHalfPixels - heightHalfPixels) ~/ 2,
                          widthHalfPixels ~/ 2,
                          heightHalfPixels ~/ 2,
                        ),
                      );
                      final error = validateChunkTrapCandidate(
                        widget.chunk,
                        candidate,
                        replacing: widget.duplicate ? null : widget.source,
                      );
                      if (error != null) {
                        setState(() => _error = error);
                        return false;
                      }
                      Navigator.of(context).pop(candidate);
                      return true;
                    },
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
