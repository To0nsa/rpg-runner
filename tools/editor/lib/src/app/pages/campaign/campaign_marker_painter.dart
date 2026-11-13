import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/interactions/world_interaction_render_catalog.dart';
import 'package:runner_core/pickups/pickup_render_catalog.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/tuning/collectible_tuning.dart';
import 'package:runner_core/tuning/restoration_item_tuning.dart';

import '../../../campaign/campaign_marker_edit.dart';
import '../../../chunks/chunk_marker_authoring_catalog.dart';
import '../chunkCreator/v2/chunk_actor_idle_frame.dart';
import '../chunkCreator/v2/chunk_trap_gesture.dart';
import '../shared/editor_scene_view_utils.dart';

String campaignMarkerLabel(CampaignMarkerEntry entry) =>
    switch (entry.placement) {
      CampaignPickupSource p =>
        p.resource == null ? 'Gold coin' : '${p.resource!.name} gem',
      CampaignShrineSource() => 'Blessing fire',
      CampaignEnemySource p => chunkMarkerEnemyCatalogEntryFor(
        p.marker.enemyId.name,
      )!.displayName,
      CampaignTrapSource p => p.trap.trapId.sourceKey.replaceAll('_', ' '),
      CampaignRescueSource p => p.encounter.name,
      null =>
        entry.key == 'start'
            ? 'Player start'
            : entry.key == 'exit'
            ? 'Mission exit'
            : entry.region != null
            ? 'Visit region'
            : 'Gold coin',
    };

Rect? campaignMarkerRegion(CampaignMarkerEntry entry) {
  final region = entry.region;
  if (region != null) {
    return Rect.fromLTWH(
      region.origin.x,
      region.origin.y,
      region.width,
      region.height,
    );
  }
  return switch (entry.placement) {
    CampaignTrapSource p => trapTriggerBounds(p.trap),
    CampaignRescueSource p => Rect.fromLTWH(
      p.encounter.trigger.x,
      p.encounter.trigger.y,
      p.encounter.trigger.width,
      p.encounter.trigger.height,
    ),
    _ => null,
  };
}

/// Uses existing pickup, actor and fire catalogs, including their exact crop,
/// anchor, scale and color transform. Previewing a flame does not activate it.
class CampaignMarkerPainter extends CustomPainter {
  CampaignMarkerPainter({
    required this.entries,
    required this.missionChunkId,
    required this.scale,
    required this.root,
    required this.images,
    this.selectedKey,
    this.candidate,
    this.showGrid = false,
  });
  final List<CampaignMarkerEntry> entries;
  final String missionChunkId, root;
  final double scale;
  final EditorUiImageCache images;
  final String? selectedKey;
  final CampaignMarkerEntry? candidate;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    if (showGrid) {
      final grid = Paint()
        ..color = Colors.white.withValues(alpha: .08)
        ..strokeWidth = 1 / scale;
      for (var x = 0.0; x < 600; x += 8) {
        canvas.drawLine(Offset(x, 0), Offset(x, 270), grid);
      }
      for (var y = 0.0; y < 270; y += 8) {
        canvas.drawLine(Offset(0, y), Offset(600, y), grid);
      }
    }
    canvas.drawLine(
      Offset.zero,
      const Offset(0, 270),
      Paint()
        ..color = Colors.grey
        ..strokeWidth = 1 / scale,
    );
    for (final entry in entries) {
      if (entry.position.missionChunkId != missionChunkId ||
          entry.key == candidate?.key) {
        continue;
      }
      _marker(canvas, entry, entry.key == selectedKey, false);
    }
    final preview = candidate;
    if (preview != null && preview.position.missionChunkId == missionChunkId) {
      _marker(canvas, preview, true, true);
    }
    canvas.restore();
  }

  void _marker(
    Canvas canvas,
    CampaignMarkerEntry entry,
    bool selected,
    bool preview,
  ) {
    final pos = Offset(entry.position.x, entry.position.y);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..color = Colors.white.withValues(alpha: preview ? .65 : 1);
    final region = campaignMarkerRegion(entry);
    if (region != null) {
      canvas.drawRect(
        region,
        Paint()..color = Colors.tealAccent.withValues(alpha: .14),
      );
      canvas.drawRect(
        region,
        Paint()
          ..color = selected ? Colors.white : Colors.tealAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 / scale,
      );
      if (selected) {
        for (final p in [
          region.topLeft,
          region.topRight,
          region.bottomLeft,
          region.bottomRight,
        ]) {
          canvas.drawRect(
            Rect.fromCenter(center: p, width: 6 / scale, height: 6 / scale),
            Paint()..color = Colors.white,
          );
        }
      }
    }
    final placement = entry.placement;
    var painted = false;
    if (placement is CampaignShrineSource) {
      final def = WorldInteractionRenderCatalog.get(placement.appearance);
      final image = images.imageFor(
        '$root/assets/images/${def.assetPaths.first}',
      );
      if (image != null) {
        final source = def.source;
        final s = def.worldScale * placement.scale;
        if (def.colorMatrix != null) {
          paint.colorFilter = ColorFilter.matrix(def.colorMatrix!);
        }
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            source.x.toDouble(),
            source.y.toDouble(),
            source.width.toDouble(),
            source.height.toDouble(),
          ),
          Rect.fromLTWH(
            pos.dx - def.anchor.x * s,
            pos.dy + def.surfaceOffsetY - def.anchor.y * s,
            source.width * s,
            source.height * s,
          ),
          paint,
        );
        painted = true;
      }
      canvas.drawLine(
        Offset(pos.dx - placement.activationWidth / 2, pos.dy),
        Offset(pos.dx + placement.activationWidth / 2, pos.dy),
        Paint()
          ..color = Colors.orangeAccent
          ..strokeWidth = 3 / scale,
      );
    } else {
      ChunkActorIdleFrame? frame;
      if (placement is CampaignPickupSource ||
          (placement == null && entry.key.startsWith('collectibles:'))) {
        final resource = placement is CampaignPickupSource
            ? placement.resource
            : null;
        final variant = resource == null
            ? PickupVariant.collectible
            : switch (resource.name) {
                'health' => PickupVariant.restorationHealth,
                'mana' => PickupVariant.restorationMana,
                _ => PickupVariant.restorationStamina,
              };
        final def = const PickupRenderCatalog().get(variant);
        final extent = resource == null
            ? const CollectibleTuning().collectibleSize
            : const RestorationItemTuning().itemSize;
        frame = ChunkActorIdleFrame.fromDefinition(
          renderAnim: def,
          renderScale: extent / def.frameWidth,
          workspaceRootPath: root,
        );
      }
      if (frame != null) {
        final image = images.imageFor(frame.absoluteSourcePath);
        if (image != null && frame.fits(image)) {
          final s = frame.renderScale;
          canvas.drawImageRect(
            image,
            frame.sourceRect,
            Rect.fromLTWH(
              pos.dx - frame.anchorPoint.dx * s,
              pos.dy - frame.anchorPoint.dy * s,
              frame.frameSize.width * s,
              frame.frameSize.height * s,
            ),
            paint,
          );
          painted = true;
        }
      }
    }
    if (!painted &&
        entry.region == null &&
        placement is! CampaignEnemySource &&
        placement is! CampaignTrapSource &&
        placement is! CampaignRescueSource) {
      canvas.drawCircle(
        pos,
        5,
        Paint()
          ..color = entry.key == 'start'
              ? Colors.lightBlueAccent
              : Colors.amber,
      );
    }
    if (selected) {
      canvas.drawCircle(
        pos,
        12,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale,
      );
    }
    if (selected || entry.region != null || placement is CampaignRescueSource) {
      final label = TextPainter(
        text: TextSpan(
          text: campaignMarkerLabel(entry),
          style: TextStyle(
            color: Colors.white,
            fontSize: 11 / scale,
            backgroundColor: Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, pos + Offset(8 / scale, 8 / scale));
    }
  }

  @override
  bool shouldRepaint(covariant CampaignMarkerPainter oldDelegate) => true;
}
