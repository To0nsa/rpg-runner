import 'package:flutter/material.dart';

import 'package:runner_core/abilities/ability_def.dart';

const Map<AbilityKey, String> abilitySkillIconAssets = <AbilityKey, String>{
  'eloise.bloodletter_slash':
      'assets/images/icons/skills-icons/eloise/bloodletter_slash.png',
  'eloise.bloodletter_cleave':
      'assets/images/icons/skills-icons/eloise/bloodletter_cleave.png',
  'eloise.seeker_slash':
      'assets/images/icons/skills-icons/eloise/seeker_slash.png',
  'eloise.aegis_riposte':
      'assets/images/icons/skills-icons/eloise/aegis_riposte.png',
  'eloise.shield_block':
      'assets/images/icons/skills-icons/eloise/shield_block.png',
  'eloise.snap_shot': 'assets/images/icons/skills-icons/eloise/snap_shot.png',
  'eloise.quick_shot': 'assets/images/icons/skills-icons/eloise/quick_shot.png',
  'eloise.skewer_shot':
      'assets/images/icons/skills-icons/eloise/skewer_shot.png',
  'eloise.overcharge_shot':
      'assets/images/icons/skills-icons/eloise/overcharge_shot.png',
  'eloise.arcane_haste':
      'assets/images/icons/skills-icons/eloise/arcane_haste.png',
  'eloise.focus': 'assets/images/icons/skills-icons/eloise/focus.png',
  'eloise.arcane_ward':
      'assets/images/icons/skills-icons/eloise/arcane_ward.png',
  'eloise.cleanse': 'assets/images/icons/skills-icons/eloise/cleanse.png',
  'eloise.vital_surge':
      'assets/images/icons/skills-icons/eloise/vital_surge.png',
  'eloise.mana_infusion':
      'assets/images/icons/skills-icons/eloise/mana_infusion.png',
  'eloise.second_wind':
      'assets/images/icons/skills-icons/eloise/second_wind.png',
  'eloise.jump': 'assets/images/icons/skills-icons/eloise/jump.png',
  'eloise.double_jump':
      'assets/images/icons/skills-icons/eloise/double_jump.png',
  'eloise.dash': 'assets/images/icons/skills-icons/eloise/dash.png',
  'eloise.double_dash':
      'assets/images/icons/skills-icons/eloise/double_dash.png',
  'eloise.roll': 'assets/images/icons/skills-icons/eloise/roll.png',
  'bounty_hunter.quick_cut':
      'assets/images/icons/skills-icons/willow/quick_cut.png',
  'bounty_hunter.twin_cut':
      'assets/images/icons/skills-icons/willow/twin_cut.png',
  'bounty_hunter.lunge_slash':
      'assets/images/icons/skills-icons/willow/lunge_slash.png',
  'bounty_hunter.blast_bomb':
      'assets/images/icons/skills-icons/willow/blast_bomb.png',
  'bounty_hunter.shrapnel_bomb':
      'assets/images/icons/skills-icons/willow/shrapnel_bomb.png',
  'bounty_hunter.fire_bomb':
      'assets/images/icons/skills-icons/willow/fire_bomb.png',
  'bounty_hunter.concussion_bomb':
      'assets/images/icons/skills-icons/willow/concussion_bomb.png',
  'bounty_hunter.snap_shot':
      'assets/images/icons/skills-icons/willow/snap_shot.png',
  'bounty_hunter.quick_shot':
      'assets/images/icons/skills-icons/willow/quick_shot.png',
  'bounty_hunter.piercing_shot':
      'assets/images/icons/skills-icons/willow/piercing_shot.png',
  'bounty_hunter.scatter_shot':
      'assets/images/icons/skills-icons/willow/scatter_shot.png',
  'bounty_hunter.charged_shot':
      'assets/images/icons/skills-icons/willow/charged_shot.png',
  'bounty_hunter.blink_dash':
      'assets/images/icons/skills-icons/willow/blink_dash.png',
  'bounty_hunter.dash': 'assets/images/icons/skills-icons/willow/dash.png',
  'bounty_hunter.double_dash':
      'assets/images/icons/skills-icons/willow/double_dash.png',
  'bounty_hunter.jump': 'assets/images/icons/skills-icons/willow/jump.png',
  'bounty_hunter.double_jump':
      'assets/images/icons/skills-icons/willow/double_jump.png',
  'bounty_hunter.hunters_focus':
      'assets/images/icons/skills-icons/willow/hunters_focus.png',
  'bounty_hunter.mark_quarry':
      'assets/images/icons/skills-icons/willow/mark_quarry.png',
  'bounty_hunter.forced_march':
      'assets/images/icons/skills-icons/willow/forced_march.png',
  'bounty_hunter.field_dressing':
      'assets/images/icons/skills-icons/willow/field_dressing.png',
  'bounty_hunter.antidote':
      'assets/images/icons/skills-icons/willow/antidote.png',
  'bounty_hunter.second_wind':
      'assets/images/icons/skills-icons/willow/second_wind.png',
  'bounty_hunter.prepare_charges':
      'assets/images/icons/skills-icons/willow/prepare_charges.png',
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
    this.filterQuality = FilterQuality.none,
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
