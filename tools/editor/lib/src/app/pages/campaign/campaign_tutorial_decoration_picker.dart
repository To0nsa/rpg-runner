import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:runner_core/track/chunk_pattern.dart';

/// Only unambiguous, collision-free prefab targets can be accepted. A deleted,
/// reclassified or duplicated target stays invalid until explicitly repaired.
class CampaignTutorialDecorationPicker extends StatelessWidget {
  const CampaignTutorialDecorationPicker({
    super.key,
    required this.sprites,
    required this.prefabKey,
    required this.onChanged,
  });
  final List<ChunkVisualSpriteRel> sprites;
  final String? prefabKey;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = campaignTutorialDecorations(sprites);
    return DropdownButtonFormField<String>(
      key: ValueKey((prefabKey, Object.hashAll(options))),
      initialValue: options.any((s) => s.prefabKey == prefabKey)
          ? prefabKey
          : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Decoration to highlight',
        helperText: 'Choose a unique single-sprite decoration in this chunk.',
      ),
      items: [
        for (final sprite in options)
          DropdownMenuItem(
            value: sprite.prefabKey,
            child: Text(sprite.prefabKey!),
          ),
      ],
      validator: (value) =>
          value == null ? 'Choose an existing, unambiguous decoration.' : null,
      onChanged: onChanged,
    );
  }
}
