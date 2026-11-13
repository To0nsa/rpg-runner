import 'package:flutter/material.dart';

import '../theme/ui_tokens.dart';

/// Selects an item without applying or buying it. The parent owns tile extent;
/// [statusLabel] supplies a check mark and an accessible ownership/equipped state.
class ItemPickerTile extends StatelessWidget {
  const ItemPickerTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.statusLabel,
    this.showLabel = false,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final VoidCallback? onTap;
  final String? statusLabel;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final radius = BorderRadius.circular(ui.radii.sm);
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        value: statusLabel,
        selected: selected,
        button: true,
        enabled: onTap != null,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: selected
                    ? UiBrandPalette.steelBlueInsetBottom
                    : ui.colors.cardBackground,
                borderRadius: radius,
                border: Border.all(
                  color: selected
                      ? ui.colors.accentStrong
                      : statusLabel != null
                      ? ui.colors.success
                      : ui.colors.outline,
                  width: selected ? ui.sizes.borderWidth : 1,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(showLabel ? ui.space.xxs : 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          icon,
                          if (showLabel) ...[
                            SizedBox(height: ui.space.xxs),
                            Text(
                              label,
                              style: ui.text.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (statusLabel != null)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Icon(
                        Icons.check_circle,
                        size: 14,
                        color: ui.colors.success,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
