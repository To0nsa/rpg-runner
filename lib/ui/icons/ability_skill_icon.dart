import 'package:flutter/material.dart';

import '../../core/abilities/ability_def.dart';

const Map<AbilityKey, String> abilitySkillIconAssets = <AbilityKey, String>{
  'eloise.aegis_riposte': 'assets/images/icons/skills-icons/aegis_riposte.png',
  'eloise.arcane_haste': 'assets/images/icons/skills-icons/arcane_haste.png',
  'eloise.arcane_ward': 'assets/images/icons/skills-icons/arcane_ward.png',
  'eloise.bloodletter_cleave':
      'assets/images/icons/skills-icons/bloodletter_cleave.png',
  'eloise.bloodletter_slash':
      'assets/images/icons/skills-icons/bloodletter_slash.png',
  'eloise.concussive_bash':
      'assets/images/icons/skills-icons/concussive_bash.png',
  'eloise.concussive_breaker':
      'assets/images/icons/skills-icons/concussive_breaker.png',
  'eloise.dash': 'assets/images/icons/skills-icons/dash.png',
  'eloise.double_jump': 'assets/images/icons/skills-icons/double_jump.png',
  'eloise.jump': 'assets/images/icons/skills-icons/jump.png',
  'eloise.mana_infusion': 'assets/images/icons/skills-icons/mana_infusion.png',
  'eloise.overcharge_shot':
      'assets/images/icons/skills-icons/overcharge_shot.png',
  'eloise.quick_shot': 'assets/images/icons/skills-icons/quick_shot.png',
  'eloise.riposte_guard': 'assets/images/icons/skills-icons/riposte_guard.png',
  'eloise.roll': 'assets/images/icons/skills-icons/roll.png',
  'eloise.second_wind': 'assets/images/icons/skills-icons/second_wind.png',
  'eloise.seeker_bash': 'assets/images/icons/skills-icons/seeker_bash.png',
  'eloise.seeker_slash': 'assets/images/icons/skills-icons/seeker_slash.png',
  'eloise.shield_block': 'assets/images/icons/skills-icons/shield_block.png',
  'eloise.skewer_shot': 'assets/images/icons/skills-icons/skewer_shot.png',
  'eloise.snap_shot': 'assets/images/icons/skills-icons/snap_shot.png',
  'eloise.vital_surge': 'assets/images/icons/skills-icons/vital_surge.png',
};

/// Displays the authored skill icon for [abilityId].
///
/// If the id is null, unknown, or the asset fails to load, this renders
/// an empty box with the requested [size].
class AbilitySkillIcon extends StatelessWidget {
  const AbilitySkillIcon({
    super.key,
    required this.abilityId,
    required this.size,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.medium,
  });

  final AbilityKey? abilityId;
  final double size;
  final BoxFit fit;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final id = abilityId;
    if (id == null) return SizedBox(width: size, height: size);
    final iconAsset = abilitySkillIconAssets[id];
    if (iconAsset == null) return SizedBox(width: size, height: size);
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        iconAsset,
        fit: fit,
        filterQuality: filterQuality,
        errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
      ),
    );
  }
}
