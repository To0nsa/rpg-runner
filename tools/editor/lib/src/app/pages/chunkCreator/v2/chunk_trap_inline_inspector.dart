import 'package:flutter/material.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_geometry.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';

import '../../../../terrain_authoring/terrain_axis_aligned_rectangle.dart';
import '../../shared/terrain_polygon_exact_edit_controller.dart';
import '../../shared/terrain_polygon_rectangle_editor.dart';
import 'chunk_trap_panel.dart';

/// Keeps numeric input local until one revision-guarded composition edit succeeds.
/// The workspace supplies a new key when selection or its source revision changes.
class ChunkTrapInlineInspector extends StatefulWidget {
  const ChunkTrapInlineInspector({
    super.key,
    required this.source,
    required this.editController,
    required this.onApply,
    required this.onCancel,
    required this.onDuplicate,
    required this.onDelete,
    required this.onFrame,
    required this.frame,
    required this.snapControls,
    required this.enabled,
    required this.canDuplicate,
  });
  final TrapPlacement source;
  final TerrainPolygonExactEditController editController;
  final String? Function(TrapPlacement) onApply;
  final VoidCallback onCancel, onDuplicate, onDelete;
  final ValueChanged<int> onFrame;
  final int frame;
  final Widget snapControls;
  final bool enabled, canDuplicate;

  @override
  State<ChunkTrapInlineInspector> createState() =>
      _ChunkTrapInlineInspectorState();
}

class _ChunkTrapInlineInspectorState extends State<ChunkTrapInlineInspector> {
  late final _x = TextEditingController(text: '${widget.source.x}');
  late final _y = TextEditingController(text: '${widget.source.y}');
  late Facing _facing = widget.source.facing;
  final _rectangle = TerrainPolygonExactEditController();
  String? _error;
  bool _saved = false;

  bool get _hasChanges =>
      !_saved &&
      (_x.text != '${widget.source.x}' ||
          _y.text != '${widget.source.y}' ||
          _facing != widget.source.facing ||
          _rectangle.hasChanges);

  @override
  void initState() {
    super.initState();
    _rectangle.addListener(_changed);
    widget.editController.attach(
      this,
      hasChanges: () => _hasChanges,
      save: () => widget.enabled && _rectangle.save(),
      discard: _discard,
    );
  }

  void _changed() {
    _saved = false;
    widget.editController.markChanged();
  }

  void _discard() {
    _rectangle.discard();
    setState(() {
      _x.text = '${widget.source.x}';
      _y.text = '${widget.source.y}';
      _facing = widget.source.facing;
      _error = null;
      _saved = false;
    });
    widget.editController.markChanged();
  }

  @override
  void dispose() {
    widget.editController.detach(this);
    _rectangle
      ..removeListener(_changed)
      ..dispose();
    _x.dispose();
    _y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trigger = widget.source.trigger;
    final def = TrapCatalog.get(widget.source.trapId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit ${trapDisplayName(widget.source.trapId)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('chunk_trap_x'),
                  controller: _x,
                  enabled: widget.enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Anchor X (px)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _changed(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('chunk_trap_y'),
                  controller: _y,
                  enabled: widget.enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Anchor Y (px)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _changed(),
                ),
              ),
            ],
          ),
          if (widget.source.trapId != TrapId.spike) ...[
            const SizedBox(height: 12),
            SegmentedButton<Facing>(
              segments: [
                for (final facing in Facing.values)
                  ButtonSegment(value: facing, label: Text(facing.name)),
              ],
              selected: {_facing},
              onSelectionChanged: widget.enabled
                  ? (values) {
                      setState(() => _facing = values.single);
                      _changed();
                    }
                  : null,
            ),
          ],
          const SizedBox(height: 12),
          widget.snapControls,
          const SizedBox(height: 12),
          const Text(
            'Blue: activation trigger. Red: damage preview. Trigger coordinates are offsets from the anchor; facing leaves them unchanged.',
          ),
          const SizedBox(height: 8),
          TerrainPolygonRectangleEditor(
            keyPrefix: 'chunk_trap_trigger',
            coordinateStepHalfPixels: 2,
            editController: _rectangle,
            applyButtonKey: const ValueKey('chunk_trap_save_edit'),
            applyLabel: 'Save edit',
            applyEnabled: widget.enabled,
            rectangle: TerrainAxisAlignedRectangle.tryCreate(
              xHalfPixels: trigger.offsetX * 2,
              yHalfPixels: trigger.offsetY * 2,
              widthHalfPixels: trigger.width * 2,
              heightHalfPixels: trigger.height * 2,
            )!,
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
                  final error = widget.onApply(candidate);
                  setState(() {
                    _error = error;
                    _saved = error == null;
                  });
                  widget.editController.markChanged();
                  return error == null;
                },
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const ValueKey('chunk_trap_cancel_edit'),
                onPressed: widget.enabled ? widget.onCancel : null,
                child: const Text('Cancel changes'),
              ),
              OutlinedButton(
                key: const ValueKey('chunk_trap_duplicate'),
                onPressed: widget.enabled && widget.canDuplicate
                    ? widget.onDuplicate
                    : null,
                child: const Text('Duplicate'),
              ),
              OutlinedButton(
                key: const ValueKey('chunk_trap_delete'),
                onPressed: widget.enabled ? widget.onDelete : null,
                child: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.frame < 0
                ? 'Preview: idle'
                : 'Preview frame ${widget.frame} · ${def.frameStartTick(widget.frame, 60)} ticks',
          ),
          Slider(
            key: const ValueKey('chunk_trap_frame'),
            min: -1,
            max: def.frames.length - 1.0,
            divisions: def.frames.length,
            value: widget.frame.toDouble(),
            onChanged: widget.enabled
                ? (value) => widget.onFrame(value.round())
                : null,
          ),
        ],
      ),
    );
  }
}
