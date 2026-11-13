import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

/// Point/region and target editing uses typed fields, never raw JSON. Target
/// choices come from the compiled source marker identities used by simulation.
class CampaignMarkerDialog extends StatefulWidget {
  const CampaignMarkerDialog({
    super.key,
    required this.mission,
    required this.chunks,
  });
  final CampaignMissionSource mission;
  final Map<String, PolygonTerrainRuntimeChunk> chunks;
  @override
  State<CampaignMarkerDialog> createState() => _CampaignMarkerDialogState();
}

class _CampaignMarkerDialogState extends State<CampaignMarkerDialog> {
  final form = GlobalKey<FormState>();
  late String missionChunk = widget.mission.route.first.id;
  String kind = 'requiredEnemies';
  int? salt;
  String? encounter;
  @override
  Widget build(BuildContext context) {
    final source = widget.mission.route.firstWhere((o) => o.id == missionChunk);
    final chunk = widget.chunks[source.chunkKey];
    final enemies =
        chunk?.pattern.spawnMarkers
            .where((m) => m.chancePercent == 100)
            .toList() ??
        [];
    final rescues = chunk?.pattern.encounters ?? [];
    return AlertDialog(
      title: const Text('Link shared objective'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Purpose'),
                  items: const [
                    DropdownMenuItem(
                      value: 'requiredEnemies',
                      child: Text('Required enemy defeat'),
                    ),
                    DropdownMenuItem(
                      value: 'requiredRescues',
                      child: Text('Required rescue'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        kind = v;
                        salt = null;
                        encounter = null;
                      });
                    }
                  },
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: missionChunk,
                  decoration: const InputDecoration(
                    labelText: 'Mission chunk ID',
                  ),
                  items: [
                    for (final o in widget.mission.route)
                      DropdownMenuItem(
                        value: o.id,
                        child: Text(
                          '${o.id} · ${o.chunkKey}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        missionChunk = v;
                        salt = null;
                        encounter = null;
                      });
                    }
                  },
                ),
                if (kind == 'requiredEnemies')
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    key: ValueKey('enemy_$missionChunk'),
                    decoration: const InputDecoration(
                      labelText: 'Guaranteed enemy',
                    ),
                    items: [
                      for (final e in enemies)
                        DropdownMenuItem(
                          value: e.salt,
                          child: Text(
                            '${e.enemyId.name} · x ${e.x} · ${e.salt}',
                          ),
                        ),
                    ],
                    validator: (v) => v == null
                        ? 'Select a guaranteed marker; edit the chunk if none exist.'
                        : null,
                    onChanged: (v) => salt = v,
                  ),
                if (kind == 'requiredRescues')
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey('rescue_$missionChunk'),
                    decoration: const InputDecoration(
                      labelText: 'Rescue encounter',
                    ),
                    items: [
                      for (final e in rescues)
                        DropdownMenuItem(value: e.id, child: Text(e.id)),
                    ],
                    validator: (v) =>
                        v == null ? 'Select a rescue encounter.' : null,
                    onChanged: (v) => encounter = v,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            form.currentState!.save();
            final Object value = kind == 'requiredEnemies'
                ? {'missionChunkId': missionChunk, 'markerSalt': salt}
                : {'missionChunkId': missionChunk, 'encounterId': encounter};
            Navigator.pop(context, (kind: kind, value: value));
          },
          child: const Text('Link objective'),
        ),
      ],
    );
  }
}
