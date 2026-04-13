import 'package:flutter/material.dart';

import 'prefab_editor_action_row.dart';
import '../prefab_editor_shell_state.dart';
import 'prefab_editor_ui_tokens.dart';

/// Shared shell chrome for the prefab creator page.
///
/// The page still owns lifecycle and coordinator wiring, but this widget keeps
/// the route-level action bar, status messages, tabs, and body layout out of
/// the shell state object.
class PrefabEditorShellChrome extends StatelessWidget {
  const PrefabEditorShellChrome({
    super.key,
    required this.shellState,
    required this.tabController,
    required this.canHandleUndo,
    required this.canHandleRedo,
    required this.onSave,
    required this.onUndo,
    required this.onRedo,
    required this.onTabTapped,
    required this.children,
  });

  final PrefabEditorShellState shellState;
  final TabController tabController;
  final bool canHandleUndo;
  final bool canHandleRedo;
  final VoidCallback onSave;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final ValueChanged<int> onTabTapped;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: PrefabEditorUiTokens.panelInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: PrefabEditorUiTokens.sectionGap),
            PrefabEditorActionRow(
              children: [
                FilledButton.icon(
                  onPressed: shellState.isSaving ? null : onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Definitions'),
                ),
                if (shellState.activeTabIndex != 0) ...[
                  OutlinedButton.icon(
                    key: const ValueKey<String>('prefab_editor_undo_button'),
                    onPressed:
                        shellState.isLoading ||
                            shellState.isSaving ||
                            !canHandleUndo
                        ? null
                        : onUndo,
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey<String>('prefab_editor_redo_button'),
                    onPressed:
                        shellState.isLoading ||
                            shellState.isSaving ||
                            !canHandleRedo
                        ? null
                        : onRedo,
                    icon: const Icon(Icons.redo),
                    label: const Text('Redo'),
                  ),
                ],
              ],
            ),
            if (shellState.statusMessage != null) ...[
              const SizedBox(height: PrefabEditorUiTokens.controlGap),
              Text(
                shellState.statusMessage!,
                style: const TextStyle(color: Color(0xFF8DE28D)),
              ),
            ],
            if (shellState.errorMessage != null) ...[
              const SizedBox(height: PrefabEditorUiTokens.controlGap),
              Text(
                shellState.errorMessage!,
                style: const TextStyle(color: Color(0xFFFF7F7F)),
              ),
            ],
            const SizedBox(height: PrefabEditorUiTokens.sectionGap),
            TabBar(
              controller: tabController,
              onTap: onTabTapped,
              tabs: const [
                Tab(text: 'Atlas Slicer'),
                Tab(text: 'Obstacle Prefabs'),
                Tab(text: 'Decoration Prefabs'),
                Tab(text: 'Platform Modules'),
                Tab(text: 'Platform Prefabs'),
              ],
            ),
            const SizedBox(height: PrefabEditorUiTokens.sectionGap),
            Expanded(
              child: TabBarView(controller: tabController, children: children),
            ),
          ],
        ),
      ),
    );
  }
}
