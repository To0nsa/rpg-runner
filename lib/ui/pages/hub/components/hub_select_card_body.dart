import 'package:flutter/material.dart';

import '../../../theme/ui_hub_theme.dart';

/// Consistent selection cues and readable names over the hub's artwork.
class HubSelectCardBody extends StatelessWidget {
  const HubSelectCardBody({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
    this.characterPreview,
  });

  final String label, title;
  final String? subtitle;
  final Widget? characterPreview;

  @override
  Widget build(BuildContext context) {
    final hub = context.hub;
    final hasPreview = characterPreview != null;
    final details = subtitle == null
        ? null
        : Text(
            subtitle!,
            style: hub.detail,
            maxLines: hasPreview ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: hub.label)),
            Icon(Icons.chevron_right, size: 16, color: hub.muted),
          ],
        ),
        if (hasPreview) const SizedBox(height: 4) else const Spacer(),
        Text(
          title,
          style: hub.title,
          maxLines: MediaQuery.textScalerOf(context).scale(14) > 16.8 ? 3 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (details != null) ...[
          const SizedBox(height: 4),
          if (hasPreview)
            FractionallySizedBox(
              widthFactor: .55,
              child: Tooltip(message: subtitle!, child: details),
            )
          else
            details,
        ],
      ],
    );
    if (!hasPreview) return text;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          // The preview canvas includes transparent space below the feet.
          right: -hub.characterPreviewSize * .25,
          bottom: -hub.characterPreviewSize * .18,
          child: IgnorePointer(child: characterPreview!),
        ),
        text,
      ],
    );
  }
}
