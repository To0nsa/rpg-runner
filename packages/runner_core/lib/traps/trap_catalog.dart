import '../contracts/render_frame_rect.dart';
import '../util/vec2.dart';
import 'trap_definition.dart';
import 'trap_geometry.dart';
import 'trap_id.dart';

/// Hardcoded gameplay and reviewed frame maps. See docs/tdd/traps.md for
/// source GIF correspondence, anchors, timing and the single-shot dart edit.
abstract final class TrapCatalog {
  static final Map<TrapId, TrapDefinition> _definitions = {
    TrapId.spike: _spike(),
    TrapId.swingingAxe: _axe(),
    TrapId.poisonDarts: _darts(),
  };
  static TrapDefinition get(TrapId id) => _definitions[id]!;

  /// Straight, nonpiercing dart defaults: readable travel and bounded lifetime.
  static const double dartSpeed = 340;
  static const double dartLifetimeSeconds = 3;
  static const int dartDamage100 = 100;
  static const double dartHalfLength = 4.5;
  static const double dartRadius = 2.5;
  static const RenderFrameRect dartSource = RenderFrameRect(0, 640, 128, 128);
  static const Vec2 dartAnchor = Vec2(15, 72);
  static final List<RenderFrameRect> dartImpactFrames = List.unmodifiable([
    for (var i = 0; i < 12; i++) RenderFrameRect(i * 128, 768, 128, 128),
  ]);

  /// Every renderer-consumed region, including the launcher's separate dart FX.
  static Iterable<RenderFrameRect> sourceRegions(TrapId id) sync* {
    yield* get(id).frames.map((frame) => frame.source);
    if (id == TrapId.poisonDarts) {
      yield dartSource;
      yield* dartImpactFrames;
    }
  }

  static TrapDefinition _spike() {
    const tipY = [
      92,
      93,
      92,
      93,
      93,
      93,
      93,
      82,
      54,
      54,
      54,
      54,
      54,
      54,
      54,
      58,
      62,
      66,
      69,
      74,
      78,
      87,
      93,
      92,
      92,
      92,
      92,
    ];
    return TrapDefinition(
      id: TrapId.spike,
      assetPath: 'entities/traps/spike/trap_spike.png',
      anchor: const Vec2(64, 96),
      restingBounds: const TrapRect(-22, -4, 43, 36),
      activationVisibilityBounds: const TrapRect(-26, -44, 52, 48),
      defaultTrigger: const TrapRect(-160, -44, 210, 64),
      damage100: 500,
      frames: [
        for (var i = 0; i < 27; i++)
          TrapFrame(
            source: RenderFrameRect(i % 15 * 128, i ~/ 15 * 128, 128, 128),
            durationMs: i >= 7 && i <= 9 ? 40 : 100,
            hitbox: i >= 7 && i <= 21
                ? TrapHitCapsule(-14, tipY[i] - 88.0, 13, tipY[i] - 88.0, 8)
                : null,
          ),
      ],
    );
  }

  static TrapDefinition _axe() {
    // GIF 23..73 is one triggered release/hold/retraction; 0..22 is ambient idle.
    final cells = [
      for (var i = 10; i <= 31; i++) i,
      for (var repeat = 0; repeat < 3; repeat++) ...[32, 33, 34, 35, 36],
      for (var i = 37; i <= 49; i++) i,
      0,
    ];
    const centers = <int, (double, double, double)>{
      18: (94, 36, 6),
      21: (26, 53, 9),
      22: (25, 45, 9),
      23: (31, 49, 9),
      24: (43, 65, 9),
      25: (57, 70, 9),
      26: (58, 69, 9),
      27: (58, 69, 9),
      28: (57, 70, 9),
      29: (55, 70, 9),
      30: (55, 70, 9),
      31: (55, 70, 9),
      32: (54, 69, 9),
      33: (54, 69, 9),
      34: (54, 70, 9),
      35: (54, 69, 9),
      36: (54, 69, 9),
      37: (54, 69, 9),
      38: (54, 69, 9),
      39: (54, 69, 9),
      40: (54, 69, 9),
      41: (54, 69, 9),
      42: (56, 68, 9),
      43: (59, 66, 9),
      44: (64, 63, 9),
      45: (78, 60, 9),
      46: (82, 50, 9),
      47: (95, 35, 8),
      48: (98, 35, 7),
    };
    TrapHitCapsule? blade(int cell) {
      if (cell == 19) return const TrapHitCapsule(-34, 37, 20, 37, 16);
      if (cell == 20) return const TrapHitCapsule(-40, 28, -6, 37, 9);
      final center = centers[cell];
      if (center == null) return null;
      return TrapHitCapsule(
        center.$1 - 64,
        center.$2 - 26,
        center.$1 - 64,
        center.$2 - 26,
        center.$3,
      );
    }

    return TrapDefinition(
      id: TrapId.swingingAxe,
      idleFrameIndex: 50,
      assetPath: 'entities/traps/swinging_axe/trap_axe_ambient.png',
      anchor: const Vec2(64, 26),
      restingBounds: const TrapRect(-15, -16, 62, 29),
      activationVisibilityBounds: const TrapRect(-54, 12, 104, 48),
      defaultTrigger: const TrapRect(-224, 16, 280, 68),
      damage100: 800,
      frames: [
        for (final cell in cells)
          TrapFrame(
            source: RenderFrameRect(
              (cell < 10
                      ? cell
                      : cell < 32
                      ? cell - 10
                      : cell < 37
                      ? cell - 32
                      : cell - 37) *
                  128,
              (cell < 10
                      ? 0
                      : cell < 32
                      ? 1
                      : cell < 37
                      ? 2
                      : 3) *
                  128,
              128,
              128,
            ),
            durationMs: cell == 0
                ? 300
                : cell < 32
                ? 100
                : cell < 37
                ? 350
                : cell < 41
                ? 70
                : 150,
            hitbox: blade(cell),
          ),
      ],
    );
  }

  static TrapDefinition _darts() => TrapDefinition(
    id: TrapId.poisonDarts,
    assetPath: 'entities/traps/poison_darts/spritesheet.png',
    anchor: const Vec2(32, 24),
    restingBounds: const TrapRect(-22, 21, 40, 34),
    activationVisibilityBounds: const TrapRect(16, -16, 36, 32),
    defaultTrigger: const TrapRect(40, -32, 180, 64),
    damage100: dartDamage100,
    muzzle: const Vec2(22, -2),
    // Row 0 emerges during the configured wind-up; row 4 lowers after recovery.
    // The shared crop retains the low stem and rising smear but excludes flying
    // darts. Its origin/anchor keep the raised launcher and muzzle stationary.
    frames: [
      for (var i = 0; i < 3; i++)
        TrapFrame(
          source: RenderFrameRect(i * 128 + 32, 48, 54, 80),
          durationMs: i < 2 ? 200 : 100,
        ),
      for (var i = 3; i < 5; i++)
        TrapFrame(
          source: RenderFrameRect(i * 128 + 32, 176, 54, 80),
          durationMs: 100,
          firesDart: i == 3,
        ),
      const TrapFrame(
        source: RenderFrameRect(32, 304, 54, 80),
        durationMs: 100,
      ),
      const TrapFrame(
        source: RenderFrameRect(32, 432, 54, 80),
        durationMs: 100,
      ),
      const TrapFrame(
        source: RenderFrameRect(288, 432, 54, 80),
        durationMs: 100,
      ),
      for (var i = 0; i < 6; i++)
        TrapFrame(
          source: RenderFrameRect(i * 128 + 32, 560, 54, 80),
          durationMs: 100,
        ),
    ],
  );
}
