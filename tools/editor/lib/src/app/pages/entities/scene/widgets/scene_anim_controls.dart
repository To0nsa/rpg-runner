part of '../../entities_editor_page.dart';

extension _SceneAnimControls on _EntitiesEditorPageState {
  Widget _buildSceneAnimControls({
    required List<String> animKeys,
    required String? activeAnimKey,
    required int frameIndex,
    required int frameCount,
  }) {
    if (animKeys.isEmpty || activeAnimKey == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 170,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF4A6074)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: activeAnimKey,
                  isExpanded: true,
                  hint: const Text('Anim Key'),
                  items: [
                    for (final key in animKeys)
                      DropdownMenuItem<String>(
                        value: key,
                        child: Text(key, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _onSceneAnimKeySelected,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 18),
          tooltip: 'Previous frame',
          visualDensity: VisualDensity.compact,
          onPressed: frameCount <= 1
              ? null
              : () => _stepSceneFrame(frameCount: frameCount, delta: -1),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF4A6074)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text('${frameIndex + 1}/$frameCount'),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 18),
          tooltip: 'Next frame',
          visualDensity: VisualDensity.compact,
          onPressed: frameCount <= 1
              ? null
              : () => _stepSceneFrame(frameCount: frameCount, delta: 1),
        ),
      ],
    );
  }

  void _onSceneAnimKeySelected(String? key) {
    if (key == null || key == _sceneAnimKey) {
      return;
    }
    _updateState(() {
      _sceneAnimKey = key;
      _sceneAnimFrameIndex = 0;
    });
    _ensureCurrentReferenceImageLoaded();
  }

  void _stepSceneFrame({required int frameCount, required int delta}) {
    if (frameCount <= 1) {
      return;
    }
    _updateState(() {
      final current = _sceneAnimFrameIndex.clamp(0, frameCount - 1);
      _sceneAnimFrameIndex = (current + delta).clamp(0, frameCount - 1);
    });
  }
}
