import 'package:flutter/material.dart';

import '../../theme/ui_tokens.dart';

/// A compact name/portrait row with its requirement inside the trailing meter.
class CodexEntryTile extends StatelessWidget {
  const CodexEntryTile({
    super.key,
    required this.title,
    required this.portrait,
    required this.current,
    required this.requiredProgress,
    required this.progressLabel,
    required this.onPressed,
  });
  final String title, progressLabel;
  final Widget portrait;
  final int current, requiredProgress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final unlocked = current >= requiredProgress;
    final count = '${codexNumber(current)} / ${codexNumber(requiredProgress)}';
    return Padding(
      padding: EdgeInsets.only(bottom: ui.space.xs),
      child: Semantics(
        label: '$title, ${unlocked ? 'discovered' : 'locked'}',
        value: '$count $progressLabel',
        button: true,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: Material(
            color: ui.colors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ui.radii.sm),
              side: BorderSide(color: ui.colors.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ui.space.xs,
                  vertical: ui.space.xxs,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = (constraints.maxWidth * .36).clamp(
                      100.0,
                      200.0,
                    );
                    return ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        children: [
                          SizedBox(width: 48, height: 48, child: portrait),
                          SizedBox(width: ui.space.xs),
                          Expanded(child: Text(title, style: ui.text.headline)),
                          SizedBox(width: ui.space.sm),
                          SizedBox(
                            width: barWidth,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(ui.radii.sm),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned.fill(
                                    child: ColoredBox(
                                      color: ui.colors.background,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor:
                                            (current / requiredProgress).clamp(
                                              0,
                                              1,
                                            ),
                                        heightFactor: 1,
                                        child: ColoredBox(
                                          color: ui.colors.accentStrong
                                              .withValues(alpha: .35),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: ui.space.xs,
                                      vertical: ui.space.xs,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        count,
                                        style: ui.text.body.copyWith(
                                          fontWeight: FontWeight.w600,
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
                    );
                  },
                ),
              ),
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
