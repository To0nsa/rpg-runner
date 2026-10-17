import 'package:flutter/animation.dart';

/// Animates a nonnegative integer for UI presentation; callers own its meaning
/// and decide when a new value should animate or appear immediately.
final class UiProgressAnimator {
  /// Starts at a nonnegative [initialValue] without animation. The owning
  /// widget must call [dispose] when it is removed.
  UiProgressAnimator({required TickerProvider vsync, required int initialValue})
    : assert(initialValue >= 0),
      _controller = AnimationController(vsync: vsync, duration: _fillDuration),
      _from = initialValue,
      _target = initialValue;

  /// A readable count-up shared by the hub and Library meters.
  static const _fillDuration = Duration(milliseconds: 1200);

  final AnimationController _controller;
  int _from;
  int _target;

  /// Rebuilds the presentation as [value] changes.
  Animation<double> get animation => _controller;

  /// The most recent destination supplied by the caller.
  int get target => _target;

  /// The currently displayed count, eased and rounded to a whole number.
  int get value =>
      (_from +
              (_target - _from) *
                  Curves.easeInOutCubic.transform(_controller.value))
          .round();

  /// Counts up from [from] to [target], clamping the visual start to the
  /// nonnegative range through [target]. A fresh call replaces any active fill.
  void animateFrom(int from, int target) {
    assert(target >= 0);
    _controller.stop();
    _from = from.clamp(0, target);
    _target = target;
    if (_from < _target) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  /// Displays [target] immediately, including when a previous fill is active.
  void jumpTo(int target) {
    assert(target >= 0);
    _controller.stop();
    _from = _target = target;
    _controller.value = 1;
  }

  /// Releases the ticker when its owning widget is disposed.
  void dispose() => _controller.dispose();
}
