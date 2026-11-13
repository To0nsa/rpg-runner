import 'package:flutter/material.dart';
import 'package:runner_core/terrain/water_region.dart';

import 'campaign_tutorial_world_target_picker.dart';

/// Edits stable water references; missing dependencies stay visible as errors
/// instead of silently rebinding an existing lesson to a different pool.
class CampaignTutorialWaterTargetPicker extends StatelessWidget {
  const CampaignTutorialWaterTargetPicker({
    super.key,
    required this.waterRegionsByChunk,
    required this.chunkId,
    required this.waterId,
    this.approachDistance,
    required this.onChunkChanged,
    required this.onWaterChanged,
    this.onDistanceSaved,
  });
  final Map<String, List<WaterRegionData>> waterRegionsByChunk;
  final String? chunkId, waterId;
  final double? approachDistance;
  final ValueChanged<String?> onChunkChanged, onWaterChanged;
  final ValueChanged<double>? onDistanceSaved;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CampaignTutorialWorldTargetPicker<WaterRegionData>(
        choicesByChunk: waterRegionsByChunk,
        chunkId: chunkId,
        target: waterRegionsByChunk[chunkId]
            ?.where((w) => w.id == waterId)
            .firstOrNull,
        chunkLabel: 'Mission chunk with water',
        targetLabel: 'Water region',
        describe: (w) =>
            '${w.id} · (${w.x}, ${w.y}) · ${w.width} × ${w.height}',
        onChunkChanged: onChunkChanged,
        onTargetChanged: (w) => onWaterChanged(w?.id),
      ),
      if (approachDistance != null)
        CampaignTutorialApproachDistanceField(
          subject: 'water',
          distance: approachDistance!,
          onSaved: (d) => onDistanceSaved?.call(d),
        ),
    ],
  );
}
