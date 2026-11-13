import 'package:flutter/material.dart';

import '../../../campaign/campaign_marker_edit.dart';
import '../../../chunks/chunk_v2_file_data.dart';
import '../../../prefabs/models/models.dart';
import '../shared/editor_scene_view_utils.dart';
import 'campaign_actor_preview.dart';

/// Adds the existing terrain-resolved actor preview to a captured tutorial
/// composition. Image ownership follows the dialog subtree, including dismissal.
class CampaignTutorialWorldPreview extends StatefulWidget {
  const CampaignTutorialWorldPreview({
    super.key,
    required this.terrain,
    required this.chunk,
    required this.prefabs,
    required this.entries,
    required this.root,
  });
  final Widget terrain;
  final ChunkV2FileData chunk;
  final PrefabV3FileData prefabs;
  final List<CampaignMarkerEntry> entries;
  final String root;
  @override
  State<CampaignTutorialWorldPreview> createState() => _PreviewState();
}

class _PreviewState extends State<CampaignTutorialWorldPreview> {
  final _images = EditorUiImageCache();
  @override
  void dispose() {
    _images.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 600,
    height: 270,
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.terrain,
        CampaignActorPreview(
          chunk: widget.chunk,
          prefabs: widget.prefabs,
          entries: widget.entries,
          root: widget.root,
          scale: 1,
          images: _images,
        ),
      ],
    ),
  );
}
