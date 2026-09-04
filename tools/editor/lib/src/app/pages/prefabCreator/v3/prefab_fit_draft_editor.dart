import 'package:flutter/material.dart';

import '../../../../prefabs/collision_fitting/prefab_collision_fitting.dart';
import '../../shared/editor_ui_tokens.dart';

/// Reports one candidate's local inclusion choice without committing it.
typedef PrefabFitCandidateChanged = void Function(
  String shapeId,
  bool included,
);

/// Immutable presentation for a pixel-derived Prefab collision fit draft.
class PrefabFitDraftEditor extends StatelessWidget {
  const PrefabFitDraftEditor({
    super.key,
    required this.method,
    required this.refitShapeId,
    required this.evidence,
    required this.candidateIds,
    required this.vertexCountsByShapeId,
    required this.includedCandidateIds,
    required this.messages,
    required this.isLoading,
    required this.canSave,
    required this.settings,
    required this.settingsChanged,
    required this.advancedExpanded,
    required this.onCandidateChanged,
    required this.onSettingsChanged,
    required this.onAdvancedExpansionChanged,
    required this.onRegenerate,
    required this.onSave,
    required this.onCancel,
  });

  final PrefabCollisionCreationMethod method;
  final String? refitShapeId;
  final PrefabCollisionFitEvidence? evidence;
  final List<String> candidateIds;
  final Map<String, int> vertexCountsByShapeId;
  final Set<String> includedCandidateIds;
  final List<String> messages;
  final bool isLoading;
  final bool canSave;
  final PrefabCollisionFitSettings settings;
  final bool settingsChanged;
  final bool advancedExpanded;
  final PrefabFitCandidateChanged onCandidateChanged;
  final ValueChanged<PrefabCollisionFitSettings> onSettingsChanged;
  final ValueChanged<bool> onAdvancedExpansionChanged;
  final VoidCallback onRegenerate;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final includedCount = candidateIds
        .where(includedCandidateIds.contains)
        .length;
    final vertexCount = candidateIds.fold<int>(
      0,
      (total, id) => total + (vertexCountsByShapeId[id] ?? 0),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x1716C79A),
        border: Border.all(color: const Color(0x664FE3C1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(EditorUiTokens.controlGap),
        child: Column(
          key: const ValueKey<String>('prefab_fit_draft_editor'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              refitShapeId == null
                  ? prefabFitMethodLabel(method)
                  : 'Refit $refitShapeId · ${prefabFitMethodLabel(method)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: EditorUiTokens.controlGap),
            if (isLoading)
              const LinearProgressIndicator(
                key: ValueKey<String>('prefab_fit_loading'),
              )
            else ...<Widget>[
              Text(
                '$includedCount of ${candidateIds.length} shapes included · '
                '$vertexCount vertices',
                key: const ValueKey<String>('prefab_fit_counts'),
              ),
              if (evidence != null) ...<Widget>[
                const SizedBox(height: EditorUiTokens.controlGap),
                Text(
                  _fitEvidenceText(method, evidence!),
                  key: const ValueKey<String>('prefab_fit_evidence'),
                ),
              ],
              if (candidateIds.length > 1 ||
                  candidateIds.any(
                    (id) => !includedCandidateIds.contains(id),
                  )) ...<Widget>[
                const SizedBox(height: EditorUiTokens.controlGap),
                for (final id in candidateIds)
                  CheckboxListTile(
                    key: ValueKey<String>('prefab_fit_component_$id'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(id),
                    subtitle: Text(
                      '${vertexCountsByShapeId[id] ?? 0} vertices',
                    ),
                    value: includedCandidateIds.contains(id),
                    onChanged: (included) =>
                        onCandidateChanged(id, included ?? false),
                  ),
              ],
              if (messages.isNotEmpty) ...<Widget>[
                const SizedBox(height: EditorUiTokens.controlGap),
                for (final message in messages)
                  Text(
                    message,
                    style: const TextStyle(color: Color(0xFFFFD166)),
                  ),
              ],
              if (settingsChanged) ...<Widget>[
                const SizedBox(height: EditorUiTokens.controlGap),
                const Text(
                  'Fit settings changed. Regenerate to review the new result.',
                  style: TextStyle(color: Color(0xFFFFD166)),
                ),
              ],
            ],
            const SizedBox(height: EditorUiTokens.controlGap),
            Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                key: const ValueKey<String>('prefab_fit_advanced'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: advancedExpanded,
                onExpansionChanged: onAdvancedExpansionChanged,
                title: const Text('Advanced'),
                children: <Widget>[
                  _IntegerFitSlider(
                    label: 'Alpha cutoff',
                    value: settings.alphaCutoff,
                    min: 1,
                    max: 255,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(alphaCutoff: value),
                    ),
                  ),
                  _IntegerFitSlider(
                    label: 'Minimum island area',
                    value: settings.minimumIslandArea,
                    min: 1,
                    max: 64,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(minimumIslandArea: value),
                    ),
                  ),
                  if (method != PrefabCollisionCreationMethod.fitVisibleBounds)
                    _IntegerFitSlider(
                      label: 'Maximum vertices',
                      value: settings.maximumVerticesPerShape,
                      min: 4,
                      max: PrefabCollisionFitSettings
                          .hardMaximumVerticesPerShape,
                      onChanged: (value) => onSettingsChanged(
                        settings.copyWith(maximumVerticesPerShape: value),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: EditorUiTokens.controlGap),
            Wrap(
              spacing: EditorUiTokens.controlGap,
              runSpacing: EditorUiTokens.controlGap,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>('prefab_fit_regenerate'),
                  onPressed: isLoading ? null : onRegenerate,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate'),
                ),
                FilledButton.icon(
                  key: const ValueKey<String>('prefab_fit_save'),
                  onPressed: canSave && !settingsChanged ? onSave : null,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    refitShapeId == null ? 'Save shapes' : 'Save replacement',
                  ),
                ),
                TextButton(
                  key: const ValueKey<String>('prefab_fit_cancel'),
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IntegerFitSlider extends StatelessWidget {
  const _IntegerFitSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(width: 150, child: Text('$label: $value')),
      Expanded(
        child: Slider(
          key: ValueKey<String>(
            'prefab_fit_${label.toLowerCase().replaceAll(' ', '_')}',
          ),
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value',
          onChanged: (next) => onChanged(next.round()),
        ),
      ),
    ],
  );
}

String _fitEvidenceText(
  PrefabCollisionCreationMethod method,
  PrefabCollisionFitEvidence evidence,
) => switch (method) {
  PrefabCollisionCreationMethod.detectPlatformSurface =>
    '${evidence.supportedColumns}/${evidence.sourceColumns} support columns · '
        'max deviation ${evidence.maximumDeviationPx} px',
  PrefabCollisionCreationMethod.traceVisibleOutline =>
    '${evidence.coveredVisiblePixels}/${evidence.acceptedVisiblePixels} '
        'visible pixels covered · ${evidence.coveredTransparentPixels} '
        'transparent cells added · max deviation '
        '${evidence.maximumDeviationPx} px',
  _ =>
    '${evidence.coveredVisiblePixels}/${evidence.acceptedVisiblePixels} '
        'visible pixels covered · ${evidence.coveredTransparentPixels} '
        'transparent cells added',
};

/// User-facing label shared by fit entry points and the active draft.
String prefabFitMethodLabel(PrefabCollisionCreationMethod method) =>
    switch (method) {
      PrefabCollisionCreationMethod.rectangle => 'Rectangle',
      PrefabCollisionCreationMethod.polygon => 'Polygon',
      PrefabCollisionCreationMethod.fitVisibleBounds => 'Fit visible bounds',
      PrefabCollisionCreationMethod.traceVisibleOutline =>
        'Trace visible outline',
      PrefabCollisionCreationMethod.detectPlatformSurface =>
        'Detect platform surface',
    };

/// Icon shared by fit entry points and replacement controls.
IconData prefabFitMethodIcon(
  PrefabCollisionCreationMethod method,
) => switch (method) {
  PrefabCollisionCreationMethod.rectangle => Icons.crop_square,
  PrefabCollisionCreationMethod.polygon => Icons.polyline,
  PrefabCollisionCreationMethod.fitVisibleBounds => Icons.fit_screen,
  PrefabCollisionCreationMethod.traceVisibleOutline => Icons.gesture_outlined,
  PrefabCollisionCreationMethod.detectPlatformSurface => Icons.horizontal_rule,
};
