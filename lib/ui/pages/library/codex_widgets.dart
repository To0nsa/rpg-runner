import 'package:flutter/material.dart';

import '../../components/ui_progress_animator.dart';
import '../../theme/ui_tokens.dart';

/// A compact name/portrait row with its requirement inside the trailing meter.
class CodexEntryTile extends StatefulWidget {
  const CodexEntryTile({
    super.key,
    required this.title,
    required this.portrait,
    required this.current,
    required this.requiredProgress,
    required this.progressLabel,
    required this.active,
    required this.onPressed,
    this.concealUntilUnlocked = false,
  });
  final String title, progressLabel;
  final Widget portrait;
  final int current, requiredProgress;
  final bool active;
  final VoidCallback onPressed;
  final bool concealUntilUnlocked;

  @override
  State<CodexEntryTile> createState() => _CodexEntryTileState();
}

class _CodexEntryTileState extends State<CodexEntryTile>
    with SingleTickerProviderStateMixin {
  late final UiProgressAnimator _progressAnimation;

  int get _target => widget.current.clamp(0, widget.requiredProgress);

  @override
  void initState() {
    super.initState();
    _progressAnimation = UiProgressAnimator(vsync: this, initialValue: _target);
    if (widget.active) {
      _progressAnimation.animateFrom(0, _target);
    }
  }

  @override
  void didUpdateWidget(CodexEntryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) {
      if (oldWidget.active || _target != _progressAnimation.target) {
        _progressAnimation.jumpTo(_target);
      }
    } else if (!oldWidget.active) {
      _progressAnimation.animateFrom(0, _target);
    } else if (_target != _progressAnimation.target) {
      if (_target > _progressAnimation.target) {
        _progressAnimation.animateFrom(_progressAnimation.value, _target);
      } else {
        _progressAnimation.jumpTo(_target);
      }
    }
  }

  @override
  void dispose() {
    _progressAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final unlocked = widget.current >= widget.requiredProgress;
    final concealed = widget.concealUntilUnlocked && !unlocked;
    final count =
        '${codexNumber(widget.current)} / ${codexNumber(widget.requiredProgress)}';
    return Padding(
      padding: EdgeInsets.only(bottom: ui.space.xs),
      child: Semantics(
        label:
            '${concealed ? 'Entry locked' : widget.title}, ${unlocked ? 'discovered' : 'locked'}',
        value: unlocked
            ? 'Open'
            : concealed
            ? 'Defeat $count to unlock'
            : '$count ${widget.progressLabel}',
        button: true,
        onTap: widget.onPressed,
        child: ExcludeSemantics(
          child: Material(
            color: ui.colors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ui.radii.sm),
              side: BorderSide(color: ui.colors.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onPressed,
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
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: concealed && widget.current == 0
                                ? Icon(
                                    Icons.lock_outline,
                                    color: ui.colors.textMuted,
                                  )
                                : widget.portrait,
                          ),
                          SizedBox(width: ui.space.xs),
                          Expanded(
                            child: Text(
                              concealed ? 'Entry locked' : widget.title,
                              style: ui.text.headline,
                            ),
                          ),
                          SizedBox(width: ui.space.sm),
                          SizedBox(
                            width: barWidth,
                            child: AnimatedBuilder(
                              animation: _progressAnimation.animation,
                              builder: (context, _) {
                                final shown = _progressAnimation.value;
                                final shownCount =
                                    '${codexNumber(shown)} / ${codexNumber(widget.requiredProgress)}';
                                final open =
                                    unlocked &&
                                    shown >= widget.requiredProgress;
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    ui.radii.sm,
                                  ),
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
                                                shown / widget.requiredProgress,
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
                                            open
                                                ? 'Open'
                                                : concealed
                                                ? 'Defeat $shownCount to unlock'
                                                : shownCount,
                                            style: ui.text.body.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
