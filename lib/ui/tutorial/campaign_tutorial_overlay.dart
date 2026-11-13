import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';

import '../controls/movement_control_mode.dart';
import '../l10n/app_localization.dart';
import 'campaign_tutorial_geometry.dart';

TutorialMovementControl tutorialMovementControl(MovementControlMode mode) =>
    switch (mode) {
      MovementControlMode.arrows => TutorialMovementControl.arrows,
      MovementControlMode.fixedJoystick =>
        TutorialMovementControl.fixedJoystick,
      MovementControlMode.joystick => TutorialMovementControl.floatingJoystick,
    };

/// The veil is paint-only; card navigation advances informational pages.
/// Gameplay continuation stays on the real controls and the host admission gate.
class CampaignTutorialOverlay extends StatelessWidget {
  const CampaignTutorialOverlay({
    super.key,
    required this.tutorial,
    required this.control,
    required this.targetKey,
    required this.surfaceKey,
    this.step = 0,
    this.onNext,
    this.worldTarget,
  });

  final CampaignTutorialSequence tutorial;
  final TutorialMovementControl control;
  final GlobalKey? targetKey;
  final GlobalKey surfaceKey;
  final int step;
  final VoidCallback? onNext;
  final Rect? Function()? worldTarget;

  Rect? _target() {
    if (worldTarget != null) return worldTarget!();
    final target = targetKey?.currentContext?.findRenderObject();
    final surface = surfaceKey.currentContext?.findRenderObject();
    if (target is! RenderBox ||
        surface is! RenderBox ||
        !target.hasSize ||
        !surface.hasSize) {
      return null;
    }
    return surface.globalToLocal(target.localToGlobal(Offset.zero)) &
        target.size;
  }

  @override
  Widget build(BuildContext context) {
    final language = context.l10n.localeName;
    return LayoutBuilder(
      builder: (context, constraints) {
        final world = worldTarget?.call();
        final spotlight = tutorial.spotlightFor(control, step: step);
        final area = _tutorialCardArea(
          Size(constraints.maxWidth, constraints.maxHeight),
          stepped: tutorial.stepCount > 1,
          target: world != null && spotlight != null
              ? tutorialSpotlightRect(world, spotlight)
              : null,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: CustomPaint(
                painter: TutorialVeilPainter(
                  target: _target,
                  spotlight: tutorial.spotlightFor(control, step: step),
                ),
              ),
            ),
            Positioned(
              top: area.top,
              left: area.left,
              width: area.width,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: area.height),
                child: Semantics(
                  liveRegion: true,
                  child: Card(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (tutorial.stepCount > 1)
                                  Text(
                                    context.l10n.tutorialStepProgress(
                                      step: step + 1,
                                      total: tutorial.stepCount,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                Text(
                                  tutorial.titleFor(language, step: step),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  tutorial.instructionFor(
                                    control,
                                    language,
                                    step: step,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (onNext != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: 12,
                              bottom: 4,
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ExcludeFocus(
                                child: TextButton(
                                  onPressed: onNext,
                                  child: Text(context.l10n.tutorialNext),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Keep world evidence visible when the camera brings it beneath the usual card.
// HUD targets retain their established layout; narrow surfaces retain scrolling.
Rect _tutorialCardArea(Size size, {required bool stepped, Rect? target}) {
  final compact = size.height < 340;
  final margin = math.min(16.0, size.width / 20);
  final width = math.min(420.0, size.width - 2 * margin);
  final top = compact ? 8.0 : 64.0;
  final height = math.max(
    48.0,
    size.height * .5 -
        (compact
            ? 16
            : stepped
            ? 8
            : 72),
  );
  final normal = Rect.fromLTWH((size.width - width) / 2, top, width, height);
  if (target == null || !normal.overlaps(target.inflate(8))) return normal;
  final leftWidth = (target.left - margin - 8).clamp(0.0, width);
  final rightWidth = (size.width - margin - target.right - 8).clamp(0.0, width);
  if (math.max(leftWidth, rightWidth) >= 220) {
    return leftWidth >= rightWidth
        ? Rect.fromLTWH(margin, top, leftWidth, height)
        : Rect.fromLTWH(
            size.width - margin - rightWidth,
            top,
            rightWidth,
            height,
          );
  }
  final above = target.top - 16;
  if (above >= 104) {
    return Rect.fromLTWH(normal.left, 8, width, math.min(height, above));
  }
  return normal;
}

/// Shared by runtime and the authoring canvas; shape changes never alter hit areas.
class TutorialVeilPainter extends CustomPainter {
  TutorialVeilPainter({required this.target, required this.spotlight});
  final Rect? Function() target;
  final TutorialSpotlight? spotlight;

  @override
  void paint(Canvas canvas, Size size) {
    // A padded/manual opening may cross the device edge. Even-odd paths must
    // be clipped so their outside portion cannot paint over editor margins.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final bounds = target();
    final spec = spotlight;
    if (bounds != null && spec != null) {
      final rect = tutorialSpotlightRect(bounds, spec);
      if (spec.shape == TutorialSpotlightShape.ellipse) {
        path.addOval(rect);
      } else {
        path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
      }
    }
    canvas.drawPath(path, Paint()..color = const Color(0xAA35383D));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TutorialVeilPainter oldDelegate) => true;
}
