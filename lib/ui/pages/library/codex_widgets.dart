import 'package:flutter/material.dart';

import '../../theme/ui_tokens.dart';

class CodexEntryTile extends StatelessWidget {
  const CodexEntryTile({
    super.key,
    required this.title,
    required this.category,
    required this.current,
    required this.requiredProgress,
    required this.progressLabel,
    required this.onPressed,
  });
  final String title, category, progressLabel;
  final int current, requiredProgress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final unlocked = current >= requiredProgress;
    return Padding(
      padding: EdgeInsets.only(bottom: ui.space.sm),
      child: Material(
        color: ui.colors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ui.radii.md),
          side: BorderSide(color: ui.colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.all(ui.space.md),
            child: Row(
              children: [
                Icon(
                  unlocked ? Icons.menu_book : Icons.lock_outline,
                  color: unlocked
                      ? ui.colors.accentStrong
                      : ui.colors.textMuted,
                ),
                SizedBox(width: ui.space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: ui.text.headline),
                      Text(
                        '$category • ${unlocked ? 'Discovered' : 'Locked'}',
                        style: ui.text.body.copyWith(
                          color: ui.colors.textMuted,
                        ),
                      ),
                      SizedBox(height: ui.space.xs),
                      Text(
                        '${codexNumber(current)} / ${codexNumber(requiredProgress)} $progressLabel',
                        style: ui.text.body,
                      ),
                      SizedBox(height: ui.space.xs),
                      LinearProgressIndicator(
                        value: (current / requiredProgress).clamp(0, 1),
                        color: ui.colors.accentStrong,
                        backgroundColor: ui.colors.background,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: ui.space.xs),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A scrollable reading surface shared by journal and discovered entries.
class CodexReadingView extends StatelessWidget {
  const CodexReadingView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.paragraphs,
    this.children = const [],
  });
  final String title, subtitle;
  final List<String> paragraphs;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(ui.space.md),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          padding: EdgeInsets.all(ui.space.lg),
          decoration: BoxDecoration(
            color: ui.colors.background,
            border: Border.all(color: ui.colors.outline),
            borderRadius: BorderRadius.circular(ui.radii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ui.text.display),
              SizedBox(height: ui.space.xs),
              Text(
                subtitle,
                style: ui.text.body.copyWith(color: ui.colors.accentStrong),
              ),
              for (final paragraph in paragraphs) ...[
                SizedBox(height: ui.space.md),
                Text(
                  paragraph,
                  style: ui.text.body.copyWith(fontSize: 18, height: 1.5),
                ),
              ],
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

String codexNumber(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);
