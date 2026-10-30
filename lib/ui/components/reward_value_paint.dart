import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../run/run_reward_diagnostics.dart';

/// Observes the account value's paint, including the final XP animation frame.
/// Only canonical account displays opt in; prices and pending gold do not.
class RewardValuePaint extends SingleChildRenderObjectWidget {
  const RewardValuePaint({
    super.key,
    required this.revision,
    required this.metric,
    required this.value,
    required this.target,
    required this.surface,
    required super.child,
  });

  final int? revision;
  final String metric;
  final int value;
  final int target;
  final String surface;

  _Observation _observation(BuildContext context) => _Observation(
    revision,
    metric,
    value,
    target,
    surface,
    ModalRoute.of(context),
    TickerMode.valuesOf(context).enabled,
    RunRewardDiagnostics.instance,
  );

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RewardPaint(_observation(context));

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) {
    (renderObject as _RewardPaint).observation = _observation(context);
    renderObject.markNeedsPaint();
  }
}

final class _Observation {
  const _Observation(
    this.revision,
    this.metric,
    this.value,
    this.target,
    this.surface,
    this.route,
    this.ticking,
    this.diagnostics,
  );
  final int? revision;
  final String metric;
  final int value;
  final int target;
  final String surface;
  final ModalRoute<dynamic>? route;
  final bool ticking;
  final RunRewardDiagnostics diagnostics;
  bool get eligible =>
      revision != null &&
      diagnostics.enabled &&
      ticking &&
      (route?.isCurrent ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
}

final class _RewardPaint extends RenderProxyBox {
  _RewardPaint(this.observation);
  _Observation observation;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final painted = observation;
    if (!painted.eligible || size.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!attached || !identical(observation, painted) || !painted.eligible) {
        return;
      }
      painted.diagnostics.painted(
        revision: painted.revision!,
        metric: painted.metric,
        value: painted.value,
        target: painted.target,
        surface: painted.surface,
      );
    });
  }
}
