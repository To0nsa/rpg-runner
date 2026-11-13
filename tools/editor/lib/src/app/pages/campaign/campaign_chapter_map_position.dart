import 'dart:io';

import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import '../../../workspace/editor_workspace.dart';
import '../shared/editor_location_map.dart';

/// Adapts campaign drafts to the reusable geographic placement/game preview.
class CampaignChapterMapPosition extends StatelessWidget {
  // Source IDs start with a letter, so a new draft cannot shadow a saved chapter.
  static const _newChapterId = '__new_chapter__';

  const CampaignChapterMapPosition({
    super.key,
    required this.map,
    required this.workspace,
    required this.position,
    required this.onChanged,
    required this.title,
    required this.campaignTitle,
    this.chapterId,
    this.chapters = const [],
  });
  final CampaignMapSource map;
  final EditorWorkspace workspace;
  final Offset position;
  final ValueChanged<Offset> onChanged;
  final String title;
  final String campaignTitle;
  final String? chapterId;
  final List<CampaignChapterSource> chapters;

  @override
  Widget build(BuildContext context) => EditorLocationMap(
    image: FileImage(File(workspace.resolve(map.assetPath))),
    imageIdentity: map.assetPath,
    aspectRatio: map.width / map.height,
    selectedId: chapterId ?? _newChapterId,
    previewTitle: campaignTitle,
    locations: [
      for (final chapter in chapters)
        EditorMapLocation(
          id: chapter.id,
          label: chapter.id == chapterId ? title : chapter.title['en']!,
          position: chapter.id == chapterId
              ? position
              : Offset(chapter.mapX, chapter.mapY),
        ),
      if (chapterId == null ||
          !chapters.any((chapter) => chapter.id == chapterId))
        EditorMapLocation(
          id: chapterId ?? _newChapterId,
          label: title.isEmpty ? 'Chapter' : title,
          position: position,
        ),
    ],
    onPositionChanged: onChanged,
  );
}
