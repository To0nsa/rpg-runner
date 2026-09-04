import 'package:flutter/material.dart';

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../shared/editor_panel_card.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_ui_tokens.dart';
import '../shared/prefab_polygon_visual_source.dart';
import '../shared/prefab_visual_catalog_support.dart';

/// Visual-only preview used by the Prefabs identity/metadata workflow.
class PrefabVisualPreviewPanel extends StatelessWidget {
  const PrefabVisualPreviewPanel({
    super.key,
    required this.document,
    required this.prefab,
    required this.imageCache,
    required this.workspaceRootPath,
  });

  final PrefabV3Document document;
  final PrefabV3Def? prefab;
  final EditorUiImageCache imageCache;
  final String workspaceRootPath;

  @override
  Widget build(BuildContext context) => EditorPanelCard(
    key: const ValueKey<String>('prefab_visual_preview_panel'),
    title: 'Prefab preview',
    bodyMode: EditorPanelBodyMode.expanded,
    child: prefab == null
        ? const Center(
            child: Text('Create or select a prefab to preview its visual.'),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: EditorUiTokens.controlGap,
                runSpacing: EditorUiTokens.controlGap,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Chip(
                    key: const ValueKey<String>('prefab_preview_owner_context'),
                    avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text('${prefab!.id} · ${prefab!.kind.jsonValue}'),
                  ),
                  Text(
                    '${prefab!.visualSource.type.jsonValue}:'
                    '${prefab!.sourceRefId} · ${prefab!.status.jsonValue}',
                  ),
                ],
              ),
              const SizedBox(height: EditorUiTokens.sectionGap),
              Expanded(
                child: SizedBox.expand(
                  key: const ValueKey<String>('prefab_visual_preview'),
                  child: PrefabCatalogThumbnail(
                    projection: PrefabPolygonVisualProjection.fromDocument(
                      document: document,
                      prefab: prefab!,
                    ),
                    imageCache: imageCache,
                    workspaceRootPath: workspaceRootPath,
                  ),
                ),
              ),
            ],
          ),
  );
}
