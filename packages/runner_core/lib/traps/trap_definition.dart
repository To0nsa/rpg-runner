import '../contracts/render_frame_rect.dart';
import '../util/vec2.dart';
import 'trap_geometry.dart';
import 'trap_id.dart';

/// One explicit art pose with its authoritative duration and damage geometry.
final class TrapFrame {
  const TrapFrame({
    required this.source,
    required this.durationMs,
    this.hitbox,
    this.firesDart = false,
  });
  final RenderFrameRect source;
  final int durationMs;
  final TrapHitCapsule? hitbox;
  final bool firesDart;
}

/// Immutable catalog policy shared by simulation, rendering and authoring.
/// Frame boundaries round cumulative milliseconds up to a Core tick, limiting
/// total timing error to less than one tick rather than rounding every frame.
final class TrapDefinition {
  TrapDefinition({
    required this.id,
    required this.assetPath,
    required this.anchor,
    required this.restingBounds,
    required this.activationVisibilityBounds,
    required this.defaultTrigger,
    required this.damage100,
    required Iterable<TrapFrame> frames,
    this.idleFrameIndex = 0,
    this.muzzle = const Vec2(0, 0),
  }) : frames = List.unmodifiable(frames);

  final TrapId id;
  final String assetPath;
  final Vec2 anchor;
  final TrapRect restingBounds;

  /// Anchor-relative area that must overlap the camera, alongside resting art,
  /// before activation or further contact hits. This is not rendered geometry.
  final TrapRect activationVisibilityBounds;
  final TrapRect defaultTrigger;
  final int damage100;
  final Vec2 muzzle;
  final List<TrapFrame> frames;
  final int idleFrameIndex;

  /// One second after the complete sequence, followed by empty-trigger rearming.
  int cooldownTicks(int tickHz) => tickHz;
  int get durationMs => frames.fold(0, (sum, frame) => sum + frame.durationMs);
  late final int firstHarmfulFrame = frames.indexWhere(
    (f) => f.hitbox != null || f.firesDart,
  );
  late final int windupMs = _frameStartMs(firstHarmfulFrame);

  int _frameStartMs(int frameIndex) =>
      frames.take(frameIndex).fold(0, (sum, frame) => sum + frame.durationMs);

  /// Retimes only pre-attack poses. Harmful/recovery durations remain authored.
  /// Rational integer boundaries avoid intermediate millisecond rounding and
  /// keep simulation and editor frame previews on the same fixed-tick schedule.
  int _tickAtMs(int sourceMs, int tickHz, int? requestedWindupMs) {
    final originalWindup = windupMs;
    final requested = requestedWindupMs ?? originalWindup;
    if (sourceMs < originalWindup) {
      final denominator = originalWindup * 1000;
      return (sourceMs * requested * tickHz + denominator - 1) ~/ denominator;
    }
    return ((requested + sourceMs - originalWindup) * tickHz + 999) ~/ 1000;
  }

  int durationTicks(int tickHz, {int? windupMs}) =>
      _tickAtMs(durationMs, tickHz, windupMs);

  int frameStartTick(int frameIndex, int tickHz, {int? windupMs}) =>
      _tickAtMs(_frameStartMs(frameIndex), tickHz, windupMs);

  int frameAtTick(int elapsedTicks, int tickHz, {int? windupMs}) {
    var elapsedMs = 0;
    for (var i = 0; i < frames.length; i++) {
      elapsedMs += frames[i].durationMs;
      if (elapsedTicks < _tickAtMs(elapsedMs, tickHz, windupMs)) return i;
    }
    return frames.length - 1;
  }

  int firstHarmfulTick(int tickHz, {int? windupMs}) =>
      frameStartTick(firstHarmfulFrame, tickHz, windupMs: windupMs);

  TrapRect get spriteBounds => TrapRect(
    -anchor.x.toInt(),
    -anchor.y.toInt(),
    frames.first.source.width,
    frames.first.source.height,
  );
}
