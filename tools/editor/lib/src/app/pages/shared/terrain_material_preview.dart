import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:terrain_materials/terrain_materials.dart';

/// Shared composed sample and explicit orientation coverage for one material.
class TerrainMaterialPreview extends StatelessWidget {
  const TerrainMaterialPreview({
    super.key,
    required this.workspaceRootPath,
    required this.material,
    this.compact = false,
    this.keyPrefix,
  });

  final String workspaceRootPath;
  final TerrainMaterialDefinition material;
  final bool compact;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TerrainComposedSample(
          workspaceRootPath: workspaceRootPath,
          material: material,
          height: compact ? 160 : 220,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _CoverageChip(label: 'Top / slope', configured: true),
            _CoverageChip(
              label: 'Left wall',
              configured: material.leftWall != null,
            ),
            _CoverageChip(
              label: 'Right wall',
              configured: material.rightWall != null,
            ),
            _CoverageChip(
              label: 'Underside',
              configured: material.underside != null,
            ),
            _CoverageChip(
              label: 'Cliff caps',
              configured:
                  material.topStartCap != null && material.topEndCap != null,
            ),
          ],
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _assetTiles()),
        ],
      ],
    );
  }

  List<Widget> _assetTiles() => <Widget>[
    _TerrainAssetTile(
      workspaceRootPath: workspaceRootPath,
      label: 'Fill',
      assetPath: material.fillAssetPath,
      tileKey: _tileKey('fill'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: workspaceRootPath,
      label: 'Top base',
      assetPath: material.top.base.assetPath,
      tileKey: _tileKey('surface'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: workspaceRootPath,
      label: 'Top detail',
      assetPath: material.top.detail?.assetPath,
      tileKey: _tileKey('foreground'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: workspaceRootPath,
      label: 'Start cap',
      assetPath: material.topStartCap?.assetPath,
      tileKey: _tileKey('start_cap'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: workspaceRootPath,
      label: 'End cap',
      assetPath: material.topEndCap?.assetPath,
      tileKey: _tileKey('end_cap'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: workspaceRootPath,
      label: 'Left wall',
      assetPath: material.leftWall?.base.assetPath,
      tileKey: _tileKey('left_wall'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: workspaceRootPath,
      label: 'Right wall',
      assetPath: material.rightWall?.base.assetPath,
      tileKey: _tileKey('right_wall'),
    ),
    _TerrainAssetTile(
      workspaceRootPath: workspaceRootPath,
      label: 'Underside',
      assetPath: material.underside?.base.assetPath,
      tileKey: _tileKey('underside'),
    ),
  ];

  String? _tileKey(String suffix) =>
      keyPrefix == null ? null : '${keyPrefix}_material_preview_$suffix';
}

class _TerrainComposedSample extends StatelessWidget {
  const _TerrainComposedSample({
    required this.workspaceRootPath,
    required this.material,
    required this.height,
  });

  final String workspaceRootPath;
  final TerrainMaterialDefinition material;
  final double height;

  @override
  Widget build(BuildContext context) {
    final edgeY = height * 0.34;
    return Container(
      key: ValueKey<String>('terrain_material_sample_${material.key}'),
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: <Widget>[
            Positioned(
              left: 24,
              right: 24,
              top: edgeY,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: FileImage(_file(material.fillAssetPath)),
                    repeat: ImageRepeat.repeat,
                  ),
                ),
              ),
            ),
            _edgeLayer(material.top.base, edgeY: edgeY),
            if (material.top.detail case final detail?)
              _edgeLayer(detail, edgeY: edgeY),
            if (material.topStartCap case final cap?)
              _cap(cap, edgeY: edgeY, sampleWidth: constraints.maxWidth),
            if (material.topEndCap case final cap?)
              _cap(cap, edgeY: edgeY, sampleWidth: constraints.maxWidth),
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  child: Text(
                    '${material.displayName} · ${material.key}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _edgeLayer(TerrainMaterialEdgeLayer layer, {required double edgeY}) {
    return Positioned(
      left: 24,
      right: 24,
      top: edgeY - layer.anchorY,
      height: 72,
      child: Image.file(
        _file(layer.assetPath),
        alignment: Alignment.topLeft,
        fit: BoxFit.none,
        repeat: ImageRepeat.repeatX,
        filterQuality: FilterQuality.none,
        errorBuilder: _imageError,
      ),
    );
  }

  Widget _cap(
    TerrainMaterialCap cap, {
    required double edgeY,
    required double sampleWidth,
  }) {
    final isStart = identical(cap, material.topStartCap);
    return Positioned(
      left: (isStart ? 24 : sampleWidth - 24) - cap.anchorX,
      top: edgeY - cap.anchorY,
      child: Image.file(
        _file(cap.assetPath),
        filterQuality: FilterQuality.none,
        errorBuilder: _imageError,
      ),
    );
  }

  File _file(String assetPath) =>
      File(p.normalize(p.join(workspaceRootPath, p.fromUri(assetPath))));
}

class _CoverageChip extends StatelessWidget {
  const _CoverageChip({required this.label, required this.configured});

  final String label;
  final bool configured;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      configured ? Icons.check_circle_outline : Icons.remove_circle_outline,
      size: 17,
      color: configured
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    label: Text('$label · ${configured ? 'configured' : 'fill only'}'),
  );
}

class _TerrainAssetTile extends StatelessWidget {
  const _TerrainAssetTile({
    required this.workspaceRootPath,
    required this.label,
    required this.assetPath,
    required this.tileKey,
  });

  final String workspaceRootPath;
  final String label;
  final String? assetPath;
  final String? tileKey;

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(label, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Container(
            height: 88,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: path == null
                ? const Center(child: Text('Not configured'))
                : Image.file(
                    File(
                      p.normalize(p.join(workspaceRootPath, p.fromUri(path))),
                    ),
                    key: tileKey == null ? null : ValueKey<String>(tileKey!),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: _imageError,
                  ),
          ),
          const SizedBox(height: 3),
          Tooltip(
            message: path ?? 'No asset configured',
            child: Text(
              path == null ? '—' : p.basename(path),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _imageError(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
) => const ColoredBox(
  color: Color(0x22000000),
  child: Center(child: Icon(Icons.broken_image_outlined)),
);
