import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../controls/control_resource_usage.dart';
import '../../theme/ui_hud_theme.dart';
import '../../theme/ui_resource_colors.dart';

/// Chooses the resource identity; only health receives loss trails and low warnings.
enum HudResource { health, mana, stamina }

/// Read-only vitals presentation. Values are resource units, not fixed-point.
/// Spending is immediate; only restoration and the health loss trail interpolate.
class ResourceBar extends StatefulWidget {
  const ResourceBar({
    super.key,
    required this.resource,
    required this.value,
    required this.maximum,
    this.active = true,
    this.compact = false,
    this.warningSignal,
  });

  final HudResource resource;
  final double value;
  final double maximum;
  final bool active;

  /// Narrows the track to reserve room for timer and score on small landscapes.
  final bool compact;
  final ValueListenable<ControlResourceUsage>? warningSignal;

  @override
  State<ResourceBar> createState() => _ResourceBarState();
}

class _ResourceBarState extends State<ResourceBar>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late double _fill;
  late double _trail;
  double _trailFrom = 0;
  double _lossAge = 1;
  double _warningLeft = 0;
  double _pulseAge = 0;
  Duration _previousElapsed = Duration.zero;
  bool _reduceMotion = false;

  // Seconds: hold loss briefly, then drain it without delaying the real fill.
  static const _lossHold = .18;
  static const _lossDuration = .42;
  // A 60 ms smoothing time keeps continuous regeneration responsive.
  static const _restoreTime = .06;
  static const _warningDuration = .45;

  double get _target =>
      widget.maximum <= 0 ? 0 : (widget.value / widget.maximum).clamp(0, 1);
  bool get _lowHealth =>
      widget.resource == HudResource.health && _target > 0 && _target <= .25;
  bool get _moving =>
      !_reduceMotion &&
      ((_fill - _target).abs() > .0001 ||
          _trail > _target + .0001 ||
          _lowHealth);

  @override
  void initState() {
    super.initState();
    _fill = _trail = _target;
    _ticker = createTicker(_tick);
    widget.warningSignal?.addListener(_warn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ResourceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.warningSignal != widget.warningSignal) {
      oldWidget.warningSignal?.removeListener(_warn);
      widget.warningSignal?.addListener(_warn);
      _warningLeft = 0;
    }
    final oldTarget = oldWidget.maximum <= 0
        ? 0.0
        : (oldWidget.value / oldWidget.maximum).clamp(0.0, 1.0);
    if (oldWidget.maximum != widget.maximum ||
        oldWidget.resource != widget.resource) {
      _fill = _trail = _target;
      _trailFrom = _target;
      _lossAge = 1;
      _warningLeft = 0;
    } else if (_target < oldTarget) {
      _fill = _target;
      if (widget.resource == HudResource.health) {
        _trailFrom = math.max(_trail, oldTarget);
        _trail = _trailFrom;
        _lossAge = 0;
      } else {
        _trail = _target;
      }
    }
    _syncAnimation();
  }

  void _warn() {
    final warning = widget.warningSignal?.value;
    final applies = switch (widget.resource) {
      HudResource.health => warning?.health ?? false,
      HudResource.mana => warning?.mana ?? false,
      HudResource.stamina => warning?.stamina ?? false,
    };
    if (!applies || !widget.active) return;
    setState(() => _warningLeft = _warningDuration);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_reduceMotion || !widget.active) {
      _fill = _trail = _trailFrom = _target;
      _lossAge = 1;
    }
    if (!widget.active) _warningLeft = 0;
    if (widget.active && (_moving || _warningLeft > 0)) {
      if (!_ticker.isActive) {
        _previousElapsed = Duration.zero;
        _ticker.start();
      }
    } else {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt =
        (elapsed - _previousElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _previousElapsed = elapsed;
    setState(() {
      _warningLeft = math.max(0, _warningLeft - dt);
      _pulseAge += dt;
      _fill += (_target - _fill) * (1 - math.exp(-dt / _restoreTime));
      if ((_fill - _target).abs() < .0001) _fill = _target;
      _lossAge += dt;
      final progress = ((_lossAge - _lossHold) / _lossDuration).clamp(0.0, 1.0);
      _trail = math.max(
        _target,
        _trailFrom + (_target - _trailFrom) * progress,
      );
    });
    _syncAnimation();
  }

  @override
  void dispose() {
    widget.warningSignal?.removeListener(_warn);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (widget.resource) {
      HudResource.health => (
        'Health',
        LucideIcons.heart,
        UiResourceColors.health,
      ),
      HudResource.mana => ('Mana', LucideIcons.droplet, UiResourceColors.mana),
      HudResource.stamina => (
        'Stamina',
        LucideIcons.zap,
        UiResourceColors.stamina,
      ),
    };
    final theme = context.hudTheme;
    final warning = _warningLeft <= 0
        ? 0.0
        : _reduceMotion
        ? 1.0
        : _warningLeft / _warningDuration;
    final low = !_lowHealth
        ? 0.0
        : _reduceMotion || !widget.active
        ? .55
        : .4 + .2 * math.sin(_pulseAge * math.pi * 2 / 1.6);
    final border = Color.lerp(theme.border, color, math.max(low, warning))!;
    return Semantics(
      label: label,
      value:
          '${widget.value.clamp(0, math.max(0, widget.maximum)).toStringAsFixed(0)} / ${math.max(0, widget.maximum).toStringAsFixed(0)}',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: Color.lerp(color, Colors.white, warning * .5),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: widget.compact ? 120 : 160,
                  height: widget.resource == HudResource.health ? 12 : 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.track,
                      borderRadius: BorderRadius.circular(1),
                    ),
                    position: DecorationPosition.background,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (widget.resource == HudResource.health &&
                              _trail > _target + .0001)
                            FractionallySizedBox(
                              key: const ValueKey('resource-loss-trail'),
                              alignment: Alignment.centerLeft,
                              widthFactor: _trail,
                              child: ColoredBox(
                                color: Color.lerp(color, Colors.white, .55)!,
                              ),
                            ),
                          FractionallySizedBox(
                            key: const ValueKey('resource-fill'),
                            alignment: Alignment.centerLeft,
                            widthFactor: _fill,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: color,
                                border: Border(
                                  top: BorderSide(
                                    color: theme.foreground.withValues(
                                      alpha: .2,
                                    ),
                                  ),
                                  bottom: BorderSide(
                                    color: theme.track.withValues(alpha: .45),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Paint the frame last so full resources cannot cover it.
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1),
                              border: Border.all(
                                color: border.withValues(alpha: .7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
