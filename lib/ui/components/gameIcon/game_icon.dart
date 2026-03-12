import 'package:flutter/material.dart';

import '../../../core/abilities/ability_def.dart';
import '../../../core/meta/gear_slot.dart';
import '../../../core/projectiles/projectile_id.dart';
import 'ability_skill_icon.dart';
import 'gear_icon.dart';
import 'projectile_icon_frame.dart';

enum _GameIconKind { gear, ability, projectile }

/// Unified facade for game entity icons used across UI surfaces.
///
/// This keeps call sites consistent while preserving specialized renderers:
/// - [GearIcon] for gear atlas/image resolution
/// - [AbilitySkillIcon] for authored skill icon assets
/// - [ProjectileIconFrame] for projectile idle-frame extraction
class GameIcon extends StatelessWidget {
  const GameIcon.gear({
    super.key,
    required GearSlot slot,
    required Object id,
    this.size = 24,
  }) : _kind = _GameIconKind.gear,
       _gearSlot = slot,
       _gearId = id,
       _abilityId = null,
       _projectileId = null,
       fit = BoxFit.contain,
       filterQuality = FilterQuality.medium;

  const GameIcon.ability({
    super.key,
    required AbilityKey? abilityId,
    required this.size,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.medium,
  }) : _kind = _GameIconKind.ability,
       _gearSlot = null,
       _gearId = null,
       _abilityId = abilityId,
       _projectileId = null;

  const GameIcon.projectile({
    super.key,
    required ProjectileId projectileId,
    this.size = 24,
  }) : _kind = _GameIconKind.projectile,
       _gearSlot = null,
       _gearId = null,
       _abilityId = null,
       _projectileId = projectileId,
       fit = BoxFit.contain,
       filterQuality = FilterQuality.medium;

  final _GameIconKind _kind;
  final GearSlot? _gearSlot;
  final Object? _gearId;
  final AbilityKey? _abilityId;
  final ProjectileId? _projectileId;
  final double size;
  final BoxFit fit;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    return switch (_kind) {
      _GameIconKind.gear => GearIcon(
        slot: _gearSlot!,
        id: _gearId!,
        size: size,
      ),
      _GameIconKind.ability => AbilitySkillIcon(
        abilityId: _abilityId,
        size: size,
        fit: fit,
        filterQuality: filterQuality,
      ),
      _GameIconKind.projectile => ProjectileIconFrame(
        projectileId: _projectileId!,
        size: size,
      ),
    };
  }
}
