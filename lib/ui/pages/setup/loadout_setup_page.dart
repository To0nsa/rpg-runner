import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../../core/projectiles/projectile_item_id.dart';
import '../../app/ui_routes.dart';
import '../../components/menu_button.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app_state.dart';

class LoadoutSetupPage extends StatelessWidget {
  const LoadoutSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final loadout = appState.selection.equippedLoadout;

    return MenuScaffold(
      title: 'Setup Loadout',
      child: MenuLayout(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Loadout',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            _LoadoutSummary(loadout: loadout),
            const SizedBox(height: 24),
            const Text(
              'Quick Presets',
              style: TextStyle(color: Colors.white70, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                MenuButton(
                  label: 'Default',
                  onPressed: () => appState.setLoadout(const EquippedLoadoutDef()),
                ),
                MenuButton(
                  label: 'Fire Bolt',
                  onPressed: () => appState.setLoadout(
                    _withProjectile(loadout, ProjectileItemId.fireBolt, 'eloise.fire_bolt'),
                  ),
                ),
                MenuButton(
                  label: 'Thunder Bolt',
                  onPressed: () => appState.setLoadout(
                    _withProjectile(
                      loadout,
                      ProjectileItemId.thunderBolt,
                      'eloise.thunder_bolt',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                MenuButton(
                  label: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
                MenuButton(
                  label: 'Level',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(UiRoutes.setupLevel),
                ),
                const SizedBox(width: 12),
                MenuButton(
                  label: 'Try Lab',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(UiRoutes.loadoutLab),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

EquippedLoadoutDef _withProjectile(
  EquippedLoadoutDef base,
  ProjectileItemId projectileItemId,
  String abilityProjectileId,
) {
  return EquippedLoadoutDef(
    mask: base.mask,
    mainWeaponId: base.mainWeaponId,
    offhandWeaponId: base.offhandWeaponId,
    projectileItemId: projectileItemId,
    abilityPrimaryId: base.abilityPrimaryId,
    abilitySecondaryId: base.abilitySecondaryId,
    abilityProjectileId: abilityProjectileId,
    abilityBonusId: base.abilityBonusId,
    abilityMobilityId: base.abilityMobilityId,
    abilityJumpId: base.abilityJumpId,
  );
}

class _LoadoutSummary extends StatelessWidget {
  const _LoadoutSummary({required this.loadout});

  final EquippedLoadoutDef loadout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Primary: ${loadout.abilityPrimaryId}',
              style: const TextStyle(color: Colors.white70)),
          Text('Secondary: ${loadout.abilitySecondaryId}',
              style: const TextStyle(color: Colors.white70)),
          Text('Projectile: ${loadout.abilityProjectileId}',
              style: const TextStyle(color: Colors.white70)),
          Text('Mobility: ${loadout.abilityMobilityId}',
              style: const TextStyle(color: Colors.white70)),
          Text('Bonus: ${loadout.abilityBonusId}',
              style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
