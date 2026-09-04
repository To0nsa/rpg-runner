import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps all three Chunk workspace regions mounted across responsive changes.
class ChunkWorkspaceLayout extends StatelessWidget {
  const ChunkWorkspaceLayout({
    super.key,
    required this.minimumWideWidth,
    required this.gap,
    required this.ownerSidebar,
    required this.scene,
    required this.sidebar,
  });

  final double minimumWideWidth;
  final double gap;
  final Widget ownerSidebar;
  final Widget scene;
  final Widget sidebar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth >= minimumWideWidth;
      final sidebarWidth = math.min(
        460.0,
        math.max(360.0, constraints.maxWidth * 0.34),
      );
      final ownerSidebarWidth = math.min(
        360.0,
        math.max(280.0, constraints.maxWidth * 0.23),
      );
      final availableNarrowHeight = math.max(1.0, constraints.maxHeight - gap);
      final sceneHeight = math.min(
        math.max(540.0, availableNarrowHeight * 0.72),
        math.max(1.0, availableNarrowHeight - 140.0),
      );
      return Stack(
        key: const ValueKey<String>('chunk_workspace_layout'),
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            child: SizedBox.shrink(
              key: ValueKey<String>(
                isWide ? 'chunk_workspace_wide' : 'chunk_workspace_narrow',
              ),
            ),
          ),
          Positioned(
            key: const ValueKey<String>('chunk_scene_slot'),
            left: isWide ? ownerSidebarWidth + gap : 0,
            top: 0,
            right: isWide ? sidebarWidth + gap : 0,
            bottom: isWide ? 0 : null,
            height: isWide ? null : sceneHeight,
            child: scene,
          ),
          Positioned(
            key: const ValueKey<String>('chunk_owner_sidebar_slot'),
            left: 0,
            top: isWide ? 0 : sceneHeight + gap,
            bottom: 0,
            width: ownerSidebarWidth,
            child: ownerSidebar,
          ),
          Positioned(
            key: const ValueKey<String>('chunk_sidebar_slot'),
            left: isWide ? null : ownerSidebarWidth + gap,
            top: isWide ? 0 : sceneHeight + gap,
            right: 0,
            bottom: 0,
            width: isWide ? sidebarWidth : null,
            child: sidebar,
          ),
        ],
      );
    },
  );
}
