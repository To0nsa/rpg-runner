import 'package:flutter/material.dart';

import '../../shared/editor_section_card.dart';

/// Shared Terrain/Water creation layout. Callers own tool state and commits;
/// supported geometry determines which draw actions are presented.
class ChunkShapeCreationCard extends StatelessWidget {
  const ChunkShapeCreationCard({
    super.key,
    required this.keyPrefix,
    required this.title,
    required this.description,
    required this.metadata,
    required this.gridSnap,
    required this.neighborSnap,
    required this.onDrawRectangle,
    required this.onSave,
    required this.onCancel,
    this.status,
    this.draftEditor,
    this.supportsPolygons = false,
    this.polygonDraftActive = false,
    this.onDrawPolygon,
    this.saveLabel = 'Save shape',
  });

  final String keyPrefix;
  final String title;
  final String description;
  final Widget metadata;
  final Widget gridSnap;
  final Widget neighborSnap;
  final Widget? status;
  final Widget? draftEditor;
  final bool supportsPolygons;
  final bool polygonDraftActive;
  final VoidCallback? onDrawPolygon;
  final VoidCallback? onDrawRectangle;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final String saveLabel;

  @override
  Widget build(BuildContext context) => EditorSectionCard(
    key: ValueKey('${keyPrefix}_creation_panel'),
    expansionKey: ValueKey('${keyPrefix}_creation_panel_toggle'),
    title: title,
    description: description,
    collapsible: true,
    initiallyExpanded: false,
    child: Column(
      key: ValueKey('${keyPrefix}_creation_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        metadata,
        const SizedBox(height: 4),
        gridSnap,
        neighborSnap,
        if (status != null) ...[const SizedBox(height: 10), status!],
        if (draftEditor != null) ...[const SizedBox(height: 10), draftEditor!],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (supportsPolygons)
              FilledButton.icon(
                key: ValueKey('${keyPrefix}_new_shape'),
                onPressed: onDrawPolygon,
                icon: const Icon(Icons.polyline),
                label: Text(
                  polygonDraftActive ? 'Continue drawing' : 'Draw polygon',
                ),
              ),
            FilledButton.tonalIcon(
              key: ValueKey('${keyPrefix}_new_rectangle'),
              onPressed: onDrawRectangle,
              icon: const Icon(Icons.crop_square),
              label: const Text('Draw rectangle'),
            ),
            OutlinedButton.icon(
              key: ValueKey('${keyPrefix}_save_draft'),
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: Text(saveLabel),
            ),
            TextButton(
              key: ValueKey('${keyPrefix}_cancel_draft'),
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Consistent ready/drawing/draft feedback for the shared creation card.
class ChunkShapeCreationStatus extends StatelessWidget {
  const ChunkShapeCreationStatus({
    super.key,
    required this.title,
    required this.message,
    this.isError = false,
  });
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.edit_outlined,
            color: isError ? colors.error : colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
