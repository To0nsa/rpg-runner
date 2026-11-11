import 'package:flutter/material.dart';
import 'package:tool_ui/tool_ui.dart';

import '../../../chunks/chunk_domain_models.dart';
import '../../../chunks/chunk_v2_file_data.dart';

/// One authored-content row for Level and Campaign. Selection and actions stay
/// with the route; this card never chooses or changes assembly behavior.
class AuthoredChunkCard extends StatelessWidget {
  const AuthoredChunkCard({
    super.key,
    required this.chunk,
    required this.isSelected,
    required this.onTap,
    required this.preview,
    required this.actions,
    this.badge,
    this.description,
  });

  final ChunkV2FileData chunk;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget preview;
  final List<Widget> actions;
  final Widget? badge;
  final String? description;

  @override
  Widget build(BuildContext context) => ToolListCard(
    isSelected: isSelected,
    onTap: onTap,
    preview: SizedBox(width: 120, height: 70, child: preview),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  chunk.chunkKey,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              ?badge,
            ],
          ),
          Text(
            description ??
                '${chunk.difficulty} · ${chunk.assemblyGroupId} · ${chunk.status == chunkStatusActive ? 'Active' : 'Deprecated — excluded from runs'}',
          ),
          Wrap(spacing: 4, children: actions),
        ],
      ),
    ),
  );
}
