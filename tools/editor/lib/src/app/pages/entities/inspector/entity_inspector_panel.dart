import 'package:flutter/material.dart';

import '../../../../entities/entity_domain_models.dart';

class EntityInspectorPanel extends StatelessWidget {
  const EntityInspectorPanel({
    super.key,
    required this.selectedEntry,
    required this.isDirty,
    required this.halfXController,
    required this.halfYController,
    required this.offsetXController,
    required this.offsetYController,
    required this.anchorXPxController,
    required this.anchorYPxController,
    required this.frameWidthController,
    required this.frameHeightController,
    required this.renderScaleController,
    required this.onApply,
  });

  final EntityEntry? selectedEntry;
  final bool isDirty;
  final TextEditingController halfXController;
  final TextEditingController halfYController;
  final TextEditingController offsetXController;
  final TextEditingController offsetYController;
  final TextEditingController anchorXPxController;
  final TextEditingController anchorYPxController;
  final TextEditingController frameWidthController;
  final TextEditingController frameHeightController;
  final TextEditingController renderScaleController;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final selected = selectedEntry;
    if (selected == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No entity selected.'),
        ),
      );
    }

    final reference = selected.referenceVisual;
    final canEditRenderScale = reference?.renderScaleBinding != null;
    final canEditAnchor = reference?.anchorBinding != null;
    final shapeType = _resolvedShapeType(selected);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    selected.id,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Chip(label: Text(isDirty ? 'Dirty' : 'Clean')),
              ],
            ),
            const SizedBox(height: 4),
            Text(selected.sourcePath),
            const SizedBox(height: 12),
            Text('Render', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            _InspectorLabeledFieldRow(
              subtitle: 'Frame size',
              fields: [
                TextField(
                  controller: frameWidthController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'frameWidth',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: frameHeightController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'frameHeight',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InspectorLabeledFieldRow(
              subtitle: 'Anchor Point',
              fields: [
                TextField(
                  controller: anchorXPxController,
                  readOnly: !canEditAnchor,
                  decoration: const InputDecoration(
                    labelText: 'anchorPoint.x',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: anchorYPxController,
                  readOnly: !canEditAnchor,
                  decoration: const InputDecoration(
                    labelText: 'anchorPoint.y',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InspectorLabeledFieldRow(
              subtitle: 'Render scale',
              fields: [
                TextField(
                  controller: renderScaleController,
                  readOnly: !canEditRenderScale,
                  decoration: const InputDecoration(
                    labelText: 'renderScale',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Shape "$shapeType"',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            _InspectorLabeledFieldRow(
              subtitle: 'Size',
              fields: [
                TextField(
                  controller: halfXController,
                  decoration: const InputDecoration(
                    labelText: 'halfX',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: halfYController,
                  decoration: const InputDecoration(
                    labelText: 'halfY',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InspectorLabeledFieldRow(
              subtitle: 'Offset',
              fields: [
                TextField(
                  controller: offsetXController,
                  decoration: const InputDecoration(
                    labelText: 'offsetX',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: offsetYController,
                  decoration: const InputDecoration(
                    labelText: 'offsetY',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onApply,
                child: const Text('Apply Values'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolvedShapeType(EntityEntry entry) {
    switch (entry.sourceBinding.kind) {
      case EntitySourceBindingKind.enemyAabbExpression:
      case EntitySourceBindingKind.playerArgs:
      case EntitySourceBindingKind.projectileArgs:
        return 'rectangle';
      case EntitySourceBindingKind.referenceAnchorVec2Expression:
      case EntitySourceBindingKind.referenceRenderScaleScalar:
        return 'unknown';
    }
  }
}

class _InspectorLabeledFieldRow extends StatelessWidget {
  const _InspectorLabeledFieldRow({
    required this.subtitle,
    required this.fields,
  });

  final String subtitle;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              for (var index = 0; index < fields.length; index += 1) ...[
                Expanded(child: fields[index]),
                if (index < fields.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}


