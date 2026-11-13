import 'package:flutter/material.dart';

/// Shared form for compiled world targets. A missing reference stays invalid;
/// only an explicit user selection may rebind an existing lesson.
class CampaignTutorialWorldTargetPicker<T> extends StatelessWidget {
  const CampaignTutorialWorldTargetPicker({
    super.key,
    required this.choicesByChunk,
    required this.chunkId,
    required this.target,
    required this.chunkLabel,
    required this.targetLabel,
    required this.describe,
    required this.onChunkChanged,
    required this.onTargetChanged,
  });
  final Map<String, List<T>> choicesByChunk;
  final String? chunkId;
  final T? target;
  final String chunkLabel, targetLabel;
  final String Function(T) describe;
  final ValueChanged<String?> onChunkChanged;
  final ValueChanged<T?> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    final chunks = choicesByChunk.entries.where((e) => e.value.isNotEmpty);
    final choices = choicesByChunk[chunkId] ?? <T>[];
    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey((chunkLabel, chunkId)),
          initialValue: chunks.any((e) => e.key == chunkId) ? chunkId : null,
          decoration: InputDecoration(labelText: chunkLabel),
          items: [
            for (final e in chunks)
              DropdownMenuItem(value: e.key, child: Text(e.key)),
          ],
          validator: (value) =>
              value == null ? 'Choose ${chunkLabel.toLowerCase()}.' : null,
          onChanged: onChunkChanged,
        ),
        DropdownButtonFormField<T>(
          key: ValueKey((targetLabel, chunkId, target)),
          initialValue: choices.contains(target) ? target : null,
          decoration: InputDecoration(labelText: targetLabel),
          items: [
            for (final choice in choices)
              DropdownMenuItem(value: choice, child: Text(describe(choice))),
          ],
          validator: (value) => value == null
              ? 'Select ${targetLabel.toLowerCase()} from this chunk.'
              : null,
          onChanged: onTargetChanged,
        ),
      ],
    );
  }
}

class CampaignTutorialApproachDistanceField extends StatelessWidget {
  const CampaignTutorialApproachDistanceField({
    super.key,
    required this.subject,
    required this.distance,
    required this.onSaved,
  });
  final String subject;
  final double distance;
  final ValueChanged<double> onSaved;
  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: '$distance',
    decoration: InputDecoration(
      labelText: 'Approach distance before $subject (world units)',
    ),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    validator: (value) {
      final d = double.tryParse(value ?? '');
      return d == null || !d.isFinite || d < 1 || d > 600
          ? 'Enter a distance from 1 to 600.'
          : null;
    },
    onSaved: (value) => onSaved(double.parse(value!)),
  );
}
