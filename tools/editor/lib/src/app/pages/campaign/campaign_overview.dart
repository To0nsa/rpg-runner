import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import '../../../chunks/chunk_v2_models.dart';
import '../../../parallax/parallax_domain_models.dart';
import '../chunkCreator/v2/chunk_composition_preview.dart';

/// Joins authored chunk art at panel height, with horizontal route scrolling.
/// Geometry editing remains in Chunk Creator; markers use occurrence-local units.
class CampaignOverview extends StatefulWidget {
  const CampaignOverview({
    super.key,
    required this.mission,
    required this.chunks,
    required this.workspaceRootPath,
  });

  final CampaignMissionSource mission;
  final ChunkV2Document chunks;
  final String workspaceRootPath;

  @override
  State<CampaignOverview> createState() => _CampaignOverviewState();
}

class _CampaignOverviewState extends State<CampaignOverview> {
  final _scrollController = ScrollController();

  // Campaign's runtime contract fixes every occurrence at 600 x 270 world units.
  static const _occurrenceSize = Size(600, 270);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mission = widget.mission;
    final chunksByKey = {
      for (final chunk in widget.chunks.chunks) chunk.chunkKey: chunk,
    };
    final parallaxTheme = findParallaxThemeById(
      widget.chunks.parallaxThemes,
      mission.visualThemeId,
    );
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: Padding(
          // Keep the scrollbar clear of terrain and markers at the bottom edge.
          padding: const EdgeInsets.only(bottom: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight <= 0 || constraints.maxWidth <= 0) {
                return const SizedBox.shrink();
              }
              final scale = constraints.maxHeight / _occurrenceSize.height;
              return ListView.builder(
                key: PageStorageKey('campaign_route_preview_${mission.id}'),
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemExtent: _occurrenceSize.width * scale,
                itemCount: mission.route.length,
                itemBuilder: (context, index) {
                  final occurrence = mission.route[index];
                  final chunk = chunksByKey[occurrence.chunkKey];
                  return CustomPaint(
                    key: ValueKey('campaign_preview_${occurrence.id}'),
                    foregroundPainter: _CampaignMarkers(
                      mission,
                      occurrence.id,
                      scale,
                    ),
                    child: chunk == null
                        ? Center(
                            child: Text(
                              'Missing chunk: ${occurrence.chunkKey}',
                            ),
                          )
                        : ChunkCompositionPreview.joined(
                            workspaceRootPath: widget.workspaceRootPath,
                            chunk: chunk,
                            prefabData: widget.chunks.prefabData,
                            tileData: widget.chunks.tileData,
                            visualBoundsByPrefabKey:
                                widget.chunks.visualBoundsByPrefabKey,
                            parallaxTheme: parallaxTheme,
                          ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Overlays one occurrence so repeated chunks retain distinct mission markers.
class _CampaignMarkers extends CustomPainter {
  _CampaignMarkers(this.mission, this.occurrenceId, this.scale);

  final CampaignMissionSource mission;
  final String occurrenceId;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawLine(
      Offset.zero,
      Offset(0, size.height),
      Paint()..color = Colors.grey,
    );
    canvas.scale(scale);
    for (final region in [
      if (mission.exit != null) mission.exit!,
      ...mission.requiredRegions,
    ]) {
      if (region.origin.occurrenceId == occurrenceId) {
        canvas.drawRect(
          Rect.fromLTWH(
            region.origin.x,
            region.origin.y,
            region.width,
            region.height,
          ),
          Paint()..color = Colors.green.withValues(alpha: .3),
        );
      }
    }
    for (final point in [
      if (mission.start != null) mission.start!,
      ...mission.collectibles,
    ]) {
      if (point.occurrenceId == occurrenceId) {
        canvas.drawCircle(
          Offset(point.x, point.y),
          5 / scale,
          Paint()..color = Colors.amber,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CampaignMarkers oldDelegate) =>
      !identical(mission, oldDelegate.mission) ||
      occurrenceId != oldDelegate.occurrenceId ||
      scale != oldDelegate.scale;
}
