import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/enemies/enemy_id.dart';

import '../../assets/ui_asset_lifecycle.dart';
import '../../theme/ui_tokens.dart';

/// Static idle art, including locked discoveries; no animation ticker is needed.
class EnemyPortrait extends StatefulWidget {
  const EnemyPortrait({super.key, required this.enemy});
  final EnemyId enemy;

  @override
  State<EnemyPortrait> createState() => _EnemyPortraitState();
}

class _EnemyPortraitState extends State<EnemyPortrait> {
  UiAssetLifecycle? _owner;
  late Future<ui.Image> _portrait;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = context.read<UiAssetLifecycle>();
    if (!identical(owner, _owner)) {
      _owner = owner;
      _portrait = owner.getEnemyPortrait(widget.enemy);
    }
  }

  @override
  void didUpdateWidget(covariant EnemyPortrait oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enemy != widget.enemy) {
      _portrait = _owner!.getEnemyPortrait(widget.enemy);
    }
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FutureBuilder<ui.Image>(
      future: _portrait,
      builder: (context, snapshot) {
        final image = snapshot.data;
        return snapshot.connectionState != ConnectionState.done ||
                image == null ||
                snapshot.hasError
            ? Icon(Icons.image_outlined, color: context.ui.colors.textMuted)
            : Padding(
                padding: const EdgeInsets.all(4),
                child: RawImage(
                  image: image,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
              );
      },
    ),
  );
}
