import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../components/map_label_button.dart';
import '../l10n/app_localization.dart';
import '../pages/town/map_callout.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_world_palette.dart';
import 'campaign_catalog.dart';

const campaignRegionalMapAsset =
    'assets/images/maps/theodonis_region_unlabelled.png';

/// Fills the viewport with pannable artwork and anchored chapter navigation.
/// Initial labels respect the overlay toolbar and system insets.
class CampaignRegionalMap extends StatelessWidget {
  const CampaignRegionalMap({super.key, required this.onChapterPressed});

  final ValueChanged<CampaignChapter> onChapterPressed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _CampaignMapViewport(
      viewport: constraints.biggest,
      onChapterPressed: onChapterPressed,
    ),
  );
}

class _CampaignMapViewport extends StatefulWidget {
  const _CampaignMapViewport({
    required this.viewport,
    required this.onChapterPressed,
  });

  final Size viewport;
  final ValueChanged<CampaignChapter> onChapterPressed;

  @override
  State<_CampaignMapViewport> createState() => _CampaignMapViewportState();
}

class _CampaignMapViewportState extends State<_CampaignMapViewport> {
  late final TransformationController _transform;

  Size get _scene {
    const aspectRatio = 1361 / 1156;
    final width = math.max(
      widget.viewport.width,
      widget.viewport.height * aspectRatio,
    );
    return Size(width, width / aspectRatio);
  }

  Matrix4 get _initialTransform => Matrix4.identity()
    ..setTranslationRaw(
      (widget.viewport.width - _scene.width) / 2,
      (widget.viewport.height - _scene.height) / 2,
      0,
    );

  @override
  void initState() {
    super.initState();
    _transform = TransformationController(_initialTransform);
  }

  @override
  void didUpdateWidget(covariant _CampaignMapViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewport != oldWidget.viewport) {
      _transform.value = _initialTransform;
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final language = Localizations.localeOf(context).languageCode;
    final scene = _scene;
    final initial = _initialTransform;
    // Clamp labels to the initial safe viewport without moving geographic pins.
    final visibleMap = MediaQuery.paddingOf(context)
        .deflateRect(
          Rect.fromLTWH(
            -initial.storage[12],
            -initial.storage[13],
            widget.viewport.width,
            widget.viewport.height,
          ),
        )
        .deflate(ui.space.xs);

    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          transformationController: _transform,
          constrained: false,
          alignment: Alignment.topLeft,
          minScale: 1,
          maxScale: 3,
          child: SizedBox(
            width: scene.width,
            height: scene.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  campaignRegionalMapAsset,
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: ui.colors.background),
                ),
                for (final chapter in CampaignCatalog.chapters)
                  MapCallout(
                    anchor: Offset(
                      scene.width * chapter.mapX,
                      scene.height * chapter.mapY,
                    ),
                    labelCenter: Offset(
                      scene.width * chapter.mapX,
                      scene.height * chapter.mapY - ui.sizes.tapTarget,
                    ),
                    visibleMap: visibleMap,
                    child: MapLabelButton(
                      label: chapter.title(language),
                      icon: Icons.flag_outlined,
                      onPressed: () => widget.onChapterPressed(chapter),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          right: ui.space.xs,
          top: ui.space.xs,
          child: SafeArea(
            child: IconButton(
              tooltip: context.l10n.uiResetMap,
              onPressed: () => _transform.value = _initialTransform,
              icon: const Icon(
                Icons.center_focus_strong,
                color: UiWorldPalette.mist200,
                shadows: mapLabelShadows,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A stable crop centered on Val Outpost in the existing regional artwork.
class ValOutpostArtwork extends StatelessWidget {
  const ValOutpostArtwork({super.key});
  @override
  Widget build(BuildContext context) => ClipRect(
    child: FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: 460,
        height: 270,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: 230 - 1361 * .8,
              top: 135 - 1156 * .595,
              width: 1361,
              height: 1156,
              child: Image.asset(campaignRegionalMapAsset, fit: BoxFit.fill),
            ),
          ],
        ),
      ),
    ),
  );
}
