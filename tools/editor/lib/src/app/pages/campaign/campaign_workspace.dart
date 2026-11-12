import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gives marker editing the scene area while retaining the contents/route
/// shelves and preview at stable element positions across workspace changes.
class CampaignWorkspace extends StatelessWidget {
  const CampaignWorkspace({
    super.key,
    required this.header,
    required this.tabs,
    required this.preview,
    required this.content,
    required this.editingScene,
  });

  final Widget header, tabs, preview, content;
  final bool editingScene;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: const PageStorageKey('campaign_workspace_scroll'),
      child: SizedBox(
        height: math.max(
          constraints.maxHeight,
          (editingScene ? 560 : 720) *
              MediaQuery.textScalerOf(context).scale(1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 8),
            tabs,
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, available) => Column(
                  children: [
                    Expanded(child: preview),
                    Offstage(
                      offstage: editingScene,
                      child: TickerMode(
                        enabled: !editingScene,
                        child: ExcludeFocus(
                          excluding: editingScene,
                          child: SizedBox(
                            height: available.maxHeight * .5,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: content,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
