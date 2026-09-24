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
  int durationTicks(int tickHz) => (durationMs * tickHz + 999) ~/ 1000;

  int frameStartTick(int frameIndex, int tickHz) {
    var elapsedMs = 0;
    for (var i = 0; i < frameIndex; i++) {
      elapsedMs += frames[i].durationMs;
    }
    return (elapsedMs * tickHz + 999) ~/ 1000;
  }

  int frameAtTick(int elapsedTicks, int tickHz) {
    var elapsedMs = 0;
    for (var i = 0; i < frames.length; i++) {
      elapsedMs += frames[i].durationMs;
      if (elapsedTicks < (elapsedMs * tickHz + 999) ~/ 1000) return i;
    }
    return frames.length - 1;
  }

  int get firstHarmfulFrame =>
      frames.indexWhere((f) => f.hitbox != null || f.firesDart);
  int firstHarmfulTick(int tickHz) => frameStartTick(firstHarmfulFrame, tickHz);

  TrapRect get spriteBounds => TrapRect(
    -anchor.x.toInt(),
    -anchor.y.toInt(),
    frames.first.source.width,
    frames.first.source.height,
  );
}
