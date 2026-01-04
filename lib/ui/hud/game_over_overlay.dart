import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/enemies/enemy_id.dart';
import '../../core/events/game_event.dart';
import '../../core/projectiles/projectile_id.dart';
// import '../../core/spells/spell_id.dart';

class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({
    super.key,
    required this.visible,
    required this.onRestart,
    required this.onExit,
    required this.showExitButton,
    required this.runEndedEvent,
    required this.baseScore,
    required this.collectibles,
    required this.collectibleScore,
  });

  final bool visible;
  final VoidCallback onRestart;
  final VoidCallback? onExit;
  final bool showExitButton;
  final RunEndedEvent? runEndedEvent;

  final int baseScore;
  final int collectibles;
  final int collectibleScore;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  static const double _collectiblesPerSecond = 40.0;

  late int _displayScore;
  late int _collectibles;
  late int _remainingCollectibles;
  late int _remainingBonus;
  late int _perCollectibleValue;
  late bool _feeding;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  double _collectibleCarry = 0.0;

  @override
  void initState() {
    super.initState();
    _displayScore = widget.baseScore;
    _collectibles = widget.collectibles;
    _remainingCollectibles = widget.collectibles;
    _remainingBonus = widget.collectibleScore;
    _perCollectibleValue = _computePerCollectibleValue(
      collectibles: widget.collectibles,
      collectibleScore: widget.collectibleScore,
    );
    _feeding = _remainingCollectibles > 0 && _remainingBonus > 0;
    if (_feeding) _startTicker();
  }

  static int _computePerCollectibleValue({
    required int collectibles,
    required int collectibleScore,
  }) {
    if (collectibles <= 0) return 50;
    if (collectibleScore <= 0) return 50;

    final derived = collectibleScore ~/ collectibles;
    if (derived > 0) return derived;
    return 50;
  }

  void _startTicker() {
    _ticker?.dispose();
    _lastElapsed = Duration.zero;
    _collectibleCarry = 0.0;
    _ticker = createTicker(_onTick)..start();
  }

  void _stopTicker() {
    final ticker = _ticker;
    if (ticker == null) return;
    ticker.stop();
    ticker.dispose();
    _ticker = null;
  }

  void _onTick(Duration elapsed) {
    if (!_feeding) return;

    final dt =
        (elapsed - _lastElapsed).inMicroseconds.toDouble() / 1000000.0;
    _lastElapsed = elapsed;

    _collectibleCarry += dt * _collectiblesPerSecond;
    final rawToConsume = _collectibleCarry.floor();
    if (rawToConsume <= 0) return;
    _collectibleCarry -= rawToConsume;

    var toConsume = rawToConsume;
    if (toConsume > _remainingCollectibles) {
      toConsume = _remainingCollectibles;
    }
    _remainingCollectibles -= toConsume;

    var gained = _perCollectibleValue * toConsume;
    if (gained > _remainingBonus) gained = _remainingBonus;
    _remainingBonus -= gained;
    _displayScore += gained;

    if (_remainingCollectibles == 0 || _remainingBonus == 0) {
      _displayScore += _remainingBonus;
      _remainingBonus = 0;
      _remainingCollectibles = 0;
      _feeding = false;
      _stopTicker();
    }

    if (mounted) setState(() {});
  }

  void _skipFeed() {
    if (!_feeding) return;

    _displayScore = widget.baseScore + widget.collectibleScore;
    _remainingCollectibles = 0;
    _remainingBonus = 0;
    _feeding = false;
    _stopTicker();
    setState(() {});
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final subtitle = _buildSubtitle(widget.runEndedEvent);

    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0x88000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Game Over',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Score: $_displayScore',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Collectibles: $_collectibles -> $_remainingBonus',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OverlayButton(
                    label: 'Restart',
                    onPressed: widget.onRestart,
                  ),
                  if (_feeding) ...[
                    const SizedBox(width: 12),
                    _OverlayButton(label: 'Skip', onPressed: _skipFeed),
                  ],
                  if (widget.showExitButton) ...[
                    const SizedBox(width: 12),
                    _OverlayButton(label: 'Exit', onPressed: widget.onExit),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _buildSubtitle(RunEndedEvent? event) {
  if (event == null) return null;
  switch (event.reason) {
    case RunEndReason.gaveUp:
      return 'You gave up the run.';
    case RunEndReason.fellBehindCamera:
      return 'You fell behind.';
    case RunEndReason.playerDied:
      return _buildDeathSubtitle(event.deathInfo);
  }
}

String _buildDeathSubtitle(DeathInfo? info) {
  if (info == null) return 'You died.';
  switch (info.kind) {
    case DeathSourceKind.projectile:
      return _buildProjectileDeath(info);
    case DeathSourceKind.meleeHitbox:
      return _buildMeleeDeath(info);
    case DeathSourceKind.unknown:
      return 'You died.';
  }
}

String _buildProjectileDeath(DeathInfo info) {
  final projectileId = info.projectileId;
  if (projectileId == null) return 'You died.';
  final projectileName = _projectileName(projectileId);
  /* final spellName =
      info.spellId == null ? null : _spellName(info.spellId!); */
  final enemyName =
      info.enemyId == null ? null : _enemyName(info.enemyId!);

  final buffer = StringBuffer('Killed by $projectileName');
/*   if (spellName != null) {
    buffer.write(' ($spellName)');
  } */
  if (enemyName != null) {
    buffer.write(' from $enemyName.');
  } else {
    buffer.write('.');
  }
  return buffer.toString();
}

String _buildMeleeDeath(DeathInfo info) {
  if (info.enemyId == null) return 'You died.';
  return 'Killed by a melee strike from a ${_enemyName(info.enemyId!)}.';
}

String _enemyName(EnemyId id) {
  switch (id) {
    case EnemyId.flyingEnemy:
      return 'Flying enemy';
    case EnemyId.groundEnemy:
      return 'Ground enemy';
  }
}

String _projectileName(ProjectileId id) {
  switch (id) {
    case ProjectileId.iceBolt:
      return 'Ice Bolt';
    case ProjectileId.lightningBolt:
      return 'Lightning Bolt';
  }
}

/* String _spellName(SpellId id) {
  switch (id) {
    case SpellId.iceBolt:
      return 'Ice Bolt';
    case SpellId.lightning:
      return 'Lightning';
  }
} */

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFFFFFFF),
        backgroundColor: const Color(0xAA000000),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFFFFFFF)),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
