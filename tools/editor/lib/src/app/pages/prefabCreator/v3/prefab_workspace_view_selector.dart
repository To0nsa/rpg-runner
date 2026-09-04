import 'package:flutter/material.dart';

import '../../shared/editor_ui_tokens.dart';

/// Stable IndexedStack order for the four Prefab Creator workflows.
enum PrefabWorkspaceView { prefabs, collision, atlasSlices, platformModules }

/// Renders the user-facing workflow order independently from stack order.
class PrefabWorkspaceViewSelector extends StatelessWidget {
  const PrefabWorkspaceViewSelector({
    super.key,
    required this.selectedView,
    required this.onSelected,
  });

  final PrefabWorkspaceView selectedView;
  final ValueChanged<PrefabWorkspaceView> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: EditorUiTokens.controlGap,
    runSpacing: EditorUiTokens.controlGap,
    children: <Widget>[
      _ViewChip(
        chipKey: const ValueKey<String>('prefab_v3_view_atlas_slices'),
        label: 'Atlas slicer',
        view: PrefabWorkspaceView.atlasSlices,
        selectedView: selectedView,
        onSelected: onSelected,
      ),
      _ViewChip(
        chipKey: const ValueKey<String>('prefab_v3_view_owners'),
        label: 'Prefabs',
        view: PrefabWorkspaceView.prefabs,
        selectedView: selectedView,
        onSelected: onSelected,
      ),
      _ViewChip(
        chipKey: const ValueKey<String>('prefab_v3_view_platform_modules'),
        label: 'Platforms',
        view: PrefabWorkspaceView.platformModules,
        selectedView: selectedView,
        onSelected: onSelected,
      ),
      _ViewChip(
        chipKey: const ValueKey<String>('prefab_v3_view_collision'),
        label: 'Collision',
        view: PrefabWorkspaceView.collision,
        selectedView: selectedView,
        onSelected: onSelected,
      ),
    ],
  );
}

class _ViewChip extends StatelessWidget {
  const _ViewChip({
    required this.chipKey,
    required this.label,
    required this.view,
    required this.selectedView,
    required this.onSelected,
  });

  final Key chipKey;
  final String label;
  final PrefabWorkspaceView view;
  final PrefabWorkspaceView selectedView;
  final ValueChanged<PrefabWorkspaceView> onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    key: chipKey,
    label: Text(label),
    selected: selectedView == view,
    onSelected: (_) => onSelected(view),
  );
}
