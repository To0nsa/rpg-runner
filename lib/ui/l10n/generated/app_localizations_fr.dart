// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get tutorialNext => 'Suivant';

  @override
  String tutorialStepProgress({required int step, required int total}) {
    return 'Étape $step/$total';
  }

  @override
  String get characterTrainingTab => 'Entraînement';

  @override
  String get characterSelected => 'Sélectionné';

  @override
  String characterSelect({required String name}) {
    return 'Choisir $name';
  }

  @override
  String get characterActiveBuild => 'Active';

  @override
  String get characterUseBuild => 'Utiliser cette configuration';

  @override
  String characterSelectBuildSemantics({
    required String build,
    required String character,
  }) {
    return 'Utiliser $build avec $character';
  }

  @override
  String characterEditBuildSemantics({
    required String build,
    required String character,
  }) {
    return 'Modifier $build pour $character';
  }

  @override
  String characterBuildUnlockLevel({required int level}) {
    return 'Se débloque au niveau $level';
  }

  @override
  String get characterNextRun => 'Sélection pour la prochaine partie';

  @override
  String characterBuildSummary({
    required String character,
    required String build,
  }) {
    return '$character · $build';
  }

  @override
  String get characterRenameBuild => 'Renommer';

  @override
  String get characterBuildSaved => 'Enregistré';

  @override
  String get characterBuildSaveFailed =>
      'Impossible d’enregistrer tes modifications. Réessaie.';

  @override
  String get appTitle => 'Lothringen: The Long Run';

  @override
  String get languageName => 'Français';

  @override
  String get languageLabel => 'Langue';

  @override
  String get languageSaveFailed =>
      'Impossible d’enregistrer la langue. Réessaie.';

  @override
  String get optionsTitle => 'Options';

  @override
  String get optionsSettingsTab => 'PARAMÈTRES';

  @override
  String get optionsControlsTab => 'COMMANDES';

  @override
  String get movementTitle => 'Déplacement';

  @override
  String get movementArrows => 'Flèches';

  @override
  String get movementFloatingJoystick => 'Joystick flottant';

  @override
  String get movementFixedJoystick => 'Joystick fixe';

  @override
  String get movementHelp =>
      'Choisis comment avancer et reculer. La vitesse de déplacement est identique pour toutes les commandes.';

  @override
  String get movementArrowsHelp =>
      'Maintiens une flèche pour te déplacer dans cette direction.';

  @override
  String get movementFloatingHelp =>
      'Le joystick suit ton doigt dans le tiers gauche de l’écran.';

  @override
  String get movementFixedHelp =>
      'Le joystick reste dans le coin inférieur gauche. Fais glisser son levier à gauche ou à droite pour te déplacer.';

  @override
  String get controlsSaveFailed =>
      'Impossible d’enregistrer les commandes. Réessaie.';

  @override
  String get developerModeTitle => 'Mode développeur';

  @override
  String get developerModeHelp =>
      'Profil local avec tous les équipements et toutes les compétences. Entraînement et campagne, sans récompenses de compte.';

  @override
  String get developerPracticeHelp =>
      'Entraînement développeur : joue en local avec tous les équipements et toutes les compétences. Les fonctions du compte sont indisponibles dans cette version.';

  @override
  String get developerModeFailed =>
      'Impossible d’ouvrir le mode développeur. Réessaie.';

  @override
  String get accountLoadFailed =>
      'Impossible de charger ton compte. Vérifie ta connexion et réessaie.';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get contactSupport => 'Contacter l’assistance';

  @override
  String openLinkFailed({required String url}) {
    return 'Impossible d’ouvrir $url. Tu peux l’ouvrir manuellement.';
  }

  @override
  String get rewardsCorrected =>
      'Les récompenses de cette course n’ont pas pu être confirmées. Tes totaux ont été mis à jour.';

  @override
  String get desktopStartHint => 'Clique ou appuie sur Entrée pour commencer';

  @override
  String get touchStartHint => 'Touche l’écran pour commencer';

  @override
  String get survivalGoal => 'Survis aussi longtemps que possible';

  @override
  String get exitRunQuestion => 'Quitter la course ?';

  @override
  String get commonResume => 'Reprendre';

  @override
  String get commonExit => 'Quitter';

  @override
  String get terrainPreparing => 'Préparation du chemin…';

  @override
  String get terrainFailed => 'Impossible de préparer le chemin';

  @override
  String get terrainRetryHelp =>
      'Ta course est en attente. Réessaie pour continuer.';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get riposteReady => 'Riposte prête · relâche pour contre-attaquer';

  @override
  String get commonPlay => 'Jouer';

  @override
  String get commonPause => 'Pause';

  @override
  String get exitGameTooltip => 'Quitter la partie';

  @override
  String get gameOverTitle => 'Fin de la course';

  @override
  String get keyJump => 'Espace / W / Haut';

  @override
  String get keyMobility => 'Maj';

  @override
  String get keyPrimary => 'Clic gauche / J';

  @override
  String get keySecondary => 'Q';

  @override
  String get keyProjectile => 'Clic droit / K';

  @override
  String get keySpell => 'E / L';

  @override
  String get abilityUnavailable => 'Indisponible';

  @override
  String get abilityLowResource => 'Ressources insuffisantes';

  @override
  String get abilityFollowUp => 'Enchaînement';

  @override
  String get abilityReady => 'Prêt';

  @override
  String get desktopControlsHelp =>
      'A / D ou flèches : déplacement | Souris : visée | Échap / P : pause | Entrée : reprendre';

  @override
  String get regenerationIncreased => 'Régénération augmentée';

  @override
  String get forestBlessingName => 'Bénédiction des Dames de la forêt';

  @override
  String get bossEncounterEnded => 'Affrontement terminé';

  @override
  String bossAwakens({required String enemy}) {
    return '$enemy s’éveille';
  }

  @override
  String bossHealthSemantics({required String caption, required int health}) {
    final intl.NumberFormat healthNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String healthString = healthNumberFormat.format(health);

    return '$caption, $healthString points de santé';
  }

  @override
  String bossRestorationSemantics({
    required String caption,
    required int percent,
  }) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$caption, $percentString pour cent de santé, de mana et d’endurance restaurés';
  }

  @override
  String bossRestoration({required int percent}) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '+$percentString % santé · mana · endurance';
  }

  @override
  String get regenerationBlessingSemantics =>
      'Bénédiction des Dames de la forêt : régénération de santé, de mana et d’endurance augmentée jusqu’à la fin du niveau';

  @override
  String riposteCountdown({required double seconds}) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String secondsString = secondsNumberFormat.format(seconds);

    return 'Riposte · $secondsString s';
  }

  @override
  String secondsShort({required double seconds}) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String secondsString = secondsNumberFormat.format(seconds);

    return '$secondsString s';
  }

  @override
  String scoreValue({required int score}) {
    final intl.NumberFormat scoreNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String scoreString = scoreNumberFormat.format(score);

    return 'Score : $scoreString';
  }

  @override
  String chargePercent({required int percent}) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Charge $percentString %';
  }

  @override
  String abilityBindingSemantics({
    required String ability,
    required String binding,
    required String status,
  }) {
    return '$ability, $binding, $status';
  }

  @override
  String get projectileWeapons => 'Armes';

  @override
  String get projectileSpellList => 'Liste des sorts';

  @override
  String get gearCompareEquipped => 'Cet équipement est déjà équipé.';

  @override
  String get gearCompareSame => 'Aucune différence de statistiques.';

  @override
  String get gearOnHit => 'À l’impact';

  @override
  String get gearOnCrit => 'Sur un coup critique';

  @override
  String get gearOnKill => 'À l’élimination';

  @override
  String get gearOnBlock => 'Au blocage';

  @override
  String get gearOnDamaged => 'En subissant des dégâts';

  @override
  String get gearOnLowHealth => 'Quand la santé est faible';

  @override
  String gearCompareLose({required String effects}) {
    return 'Perdu : $effects';
  }

  @override
  String gearCompareAdd({required String effects}) {
    return 'Ajouté : $effects';
  }

  @override
  String gearProcDot({
    required String status,
    required String damage,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return 'Inflige $status : $damage dégâts par seconde pendant $duration$_temp0';
  }

  @override
  String gearProcSlow({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return 'Inflige Ralentissement : vitesse de déplacement réduite de $amount pendant $duration$_temp0';
  }

  @override
  String gearProcStun({
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return 'Inflige Étourdissement pendant $duration$_temp0';
  }

  @override
  String gearProcSilence({
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return 'Inflige Silence pendant $duration$_temp0';
  }

  @override
  String gearProcVulnerable({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return 'Inflige Vulnérabilité : dégâts subis augmentés de $amount pendant $duration$_temp0';
  }

  @override
  String gearProcWeaken({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return 'Inflige Affaiblissement : dégâts infligés réduits de $amount pendant $duration$_temp0';
  }

  @override
  String gearProcDrench({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return 'Inflige Trempé : vitesse d’attaque et d’incantation réduite de $amount pendant $duration$_temp0';
  }

  @override
  String gearProcHaste({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return 'Confère Hâte : vitesse de déplacement augmentée de $amount pendant $duration$_temp0';
  }

  @override
  String gearProcDamageReduction({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return 'Confère Réduction des dégâts : dégâts directs subis réduits de $amount pendant $duration$_temp0';
  }

  @override
  String gearProcRestore({
    required String resource,
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return 'Restauration — $resource : $amount sur $duration$_temp0';
  }

  @override
  String gearProcRestoreInstant({
    required String resource,
    required String amount,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return 'Restauration — $resource : $amount immédiatement$_temp0';
  }

  @override
  String gearProcRestoreBoth({
    required String resource,
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return 'Restauration — $resource : $amount immédiatement, puis encore $amount sur $duration$_temp0';
  }

  @override
  String gearProcOffense({
    required String amount,
    required String crit,
    required String critKind,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(critKind, {
      'withCrit':
          'Confère un bonus offensif : puissance augmentée de $amount et chances de coup critique augmentées de $crit pendant $duration',
      'other':
          'Confère un bonus offensif : puissance augmentée de $amount pendant $duration',
    });
    String _temp1 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance de chances).',
    });
    return '$_temp0$_temp1';
  }

  @override
  String abilityMelee({
    required String aim,
    required String damage,
    required String dotKind,
    required String status,
    required String dotDamage,
    required String duration,
  }) {
    String _temp0 = intl.Intl.selectLogic(aim, {
      'aimed':
          'Donne un coup d’épée qui inflige $damage dégâts aux ennemis à portée dans la direction visée.',
      'other':
          'Lance une attaque qui inflige $damage dégâts à l’ennemi le plus proche et à tous ceux à portée.',
    });
    String _temp1 = intl.Intl.selectLogic(dotKind, {
      'withDot':
          ' Elle inflige $status : $dotDamage dégâts par seconde pendant $duration secondes.',
      'other': '',
    });
    return '$_temp0$_temp1';
  }

  @override
  String abilityGuard({
    required String reduction,
    required String riposteKind,
    required String riposte,
    required String riposteBonus,
  }) {
    String _temp0 = intl.Intl.selectLogic(riposteKind, {
      'withRiposte':
          ' Le premier coup paré confère $riposte : ta prochaine attaque de mêlée qui touche inflige +$riposteBonus % de dégâts. Ce bonus reste prêt tant que tu maintiens cette garde et expire 1 seconde après sa fin. Une attaque manquée ne le consomme pas.',
      'other': '',
    });
    return 'Maintiens ta garde pour réduire de $reduction % les dégâts directs venant de toute direction. Les dégâts sur la durée déjà actifs et les sorts au sol traversent le bouclier.$_temp0';
  }

  @override
  String abilityDoubleDash({required String window}) {
    return 'Fais une courte ruée. Appuie à nouveau dans les $window secondes après la première pour repartir dans la direction de ton choix. Chaque ruée consomme le coût indiqué ; le délai de récupération commence à la première. Ne confère pas d’invulnérabilité.';
  }

  @override
  String abilityCleave({
    required String tapDamage,
    required String chargeTime,
    required String fullDamage,
    required String crit,
    required String status,
    required String dotDamage,
    required String duration,
  }) {
    return 'Vise et relâche pour infliger $tapDamage dégâts. Maintiens pendant $chargeTime secondes pour infliger $fullDamage dégâts, gagner +$crit % de chances de coup critique et infliger $status ($dotDamage dégâts par seconde pendant $duration secondes). Seule une charge complète provoque ce saignement. Subir des dégâts peut interrompre cette attaque.';
  }

  @override
  String abilitySnap({
    required String source,
    required String projectileName,
    required String damage,
  }) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'spell': 'le projectile du sort sélectionné',
      'other': 'ton projectile équipé',
    });
    return 'Tire $_temp0$projectileName pour infliger $damage dégâts à l’ennemi le plus proche.';
  }

  @override
  String abilityQuick({
    required String source,
    required String projectileName,
    required String damage,
  }) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'spell': 'le projectile du sort sélectionné',
      'other': 'ton projectile équipé',
    });
    return 'Vise et tire $_temp0$projectileName. Il inflige $damage dégâts à une seule cible.';
  }

  @override
  String abilityOvercharge({
    required String source,
    required String projectileName,
    required String damage,
    required String damageBonus,
    required String critBonus,
    required String chargeTime,
  }) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'spell': 'le projectile du sort sélectionné',
      'other': 'ton projectile équipé',
    });
    return 'Charge et libère $_temp0$projectileName. Il inflige $damage dégâts à une seule cible. La charge augmente les dégâts (jusqu’à +$damageBonus %) et les chances de coup critique (jusqu’à +$critBonus %). La charge complète prend $chargeTime secondes. Subir des dégâts peut interrompre cette attaque.';
  }

  @override
  String abilitySkewer({
    required String source,
    required String projectileName,
    required String damage,
    required String maxHits,
  }) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'spell': 'le projectile du sort sélectionné',
      'other': 'ton projectile équipé',
    });
    return 'Tire $_temp0$projectileName à travers les ennemis sur sa trajectoire. Il inflige $damage dégâts et peut toucher jusqu’à $maxHits ennemis.';
  }

  @override
  String abilityRoll({required String status}) {
    return 'Effectue une roulade percutante. Les ennemis touchés subissent $status. Ne confère pas d’invulnérabilité.';
  }

  @override
  String get abilityStrike => 'Appuie pour frapper devant toi.';

  @override
  String get abilityCast =>
      'Maintiens puis relâche pour lancer un projectile à distance.';

  @override
  String get abilityJump => 'Appuie pour sauter.';

  @override
  String get abilityDoubleJump =>
      'Appuie pour sauter, puis à nouveau en l’air pour un second saut.';

  @override
  String get abilityUse => 'Appuie pour utiliser cette compétence.';

  @override
  String get abilityDash =>
      'Fais une ruée rapide vers l’avant. Ne confère pas d’invulnérabilité.';

  @override
  String get abilityCostFirstJump => 'Coût du premier saut : ';

  @override
  String get abilityCostSecondJump => 'Coût du second saut : ';

  @override
  String get abilityCostSecond => 'Coût par seconde : ';

  @override
  String get abilityCost => 'Coût : ';

  @override
  String get abilityBleed => 'Saignement';

  @override
  String get abilityBurn => 'Brûlure';

  @override
  String get abilityAcid => 'Acide';

  @override
  String get abilityStun => 'Étourdissement';

  @override
  String get abilityDamageOverTime => 'dégâts sur la durée';

  @override
  String get abilityControl => 'Contrôle';

  @override
  String get abilityHaste => 'Hâte';

  @override
  String get abilityWard => 'Protection arcanique';

  @override
  String get abilityHealthRegen => 'Régénération de santé';

  @override
  String get abilityManaRegen => 'Régénération de mana';

  @override
  String get abilityStaminaRegen => 'Régénération d’endurance';

  @override
  String get abilityResourceRegen => 'Régénération de ressources';

  @override
  String get abilityFocus => 'Concentration';

  @override
  String get abilityStatusEffect => 'Effet de statut';

  @override
  String get abilityMaxHealth => 'santé maximale';

  @override
  String get abilityMaxMana => 'mana maximal';

  @override
  String get abilityMaxStamina => 'endurance maximale';

  @override
  String get abilityMaxResource => 'ressource maximale';

  @override
  String get abilityBadgeDamage => 'DÉGÂTS';

  @override
  String get abilityBadgeDefense => 'DÉFENSE';

  @override
  String get abilityBadgeDash => 'RUÉE';

  @override
  String get abilityBadgeJump => 'SAUT';

  @override
  String get abilityBadgeHold => 'MAINTIEN';

  @override
  String get abilityBadgeUtility => 'UTILITAIRE';

  @override
  String get abilityBadgeControl => 'CONTRÔLE';

  @override
  String get abilityBadgeCharged => 'CHARGÉ';

  @override
  String get abilityBadgeAutoAim => 'VISÉE AUTO';

  @override
  String get abilityBadgeAim => 'VISÉE';

  @override
  String abilitySelfHaste({
    required String speedBonus,
    required String duration,
  }) {
    return 'Augmente ta vitesse de déplacement de $speedBonus % pendant $duration secondes.';
  }

  @override
  String abilitySelfWard({
    required String mitigation,
    required String duration,
  }) {
    return 'Réduis les dégâts directs de $mitigation % et annule les effets de dégâts sur la durée pendant $duration secondes.';
  }

  @override
  String abilityRestoreBoth({
    required String restorePct,
    required String resourceLabel,
    required String duration,
  }) {
    return 'Restaure immédiatement $restorePct % de ta valeur de $resourceLabel, puis encore $restorePct % sur $duration secondes.';
  }

  @override
  String abilityRestoreInstant({
    required String restorePct,
    required String resourceLabel,
  }) {
    return 'Restaure immédiatement $restorePct % de ta valeur de $resourceLabel.';
  }

  @override
  String abilityRestore({
    required String restorePct,
    required String resourceLabel,
    required String duration,
  }) {
    return 'Restaure $restorePct % de ta valeur de $resourceLabel sur $duration secondes.';
  }

  @override
  String abilitySelfFocus({
    required String powerBonus,
    required String critBonus,
    required String duration,
  }) {
    return 'Augmente ta puissance de $powerBonus % et tes chances de coup critique de $critBonus % pendant $duration secondes.';
  }

  @override
  String abilitySelfStatus({
    required String statusLabel,
    required String duration,
  }) {
    return 'Applique $statusLabel pendant $duration secondes.';
  }

  @override
  String get abilityCleanse =>
      'Dissipe tous les effets négatifs actifs : étourdissement, silence, ralentissement, vulnérabilité, affaiblissement, trempé et dégâts sur la durée.';

  @override
  String get cleanseStun => 'étourdissement';

  @override
  String get cleanseSilence => 'silence';

  @override
  String get cleanseSlow => 'ralentissement';

  @override
  String get cleanseVulnerability => 'vulnérabilité';

  @override
  String get cleanseWeaken => 'affaiblissement';

  @override
  String get cleanseDrench => 'trempé';

  @override
  String get cleanseDamageOverTime => 'dégâts sur la durée';

  @override
  String abilityBaseDamage({required String parts}) {
    return 'Dégâts de base : $parts.';
  }

  @override
  String abilityCostValue({required String value, required String resource}) {
    return '$value $resource';
  }

  @override
  String get abilityRiposte => 'Riposte';

  @override
  String hunterBomb({
    required num range,
    required String fuse,
    required String damage,
    required num radius,
    required String effect,
  }) {
    final intl.NumberFormat rangeNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String rangeString = rangeNumberFormat.format(range);
    final intl.NumberFormat radiusNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String radiusString = radiusNumberFormat.format(radius);

    String _temp0 = intl.Intl.selectLogic(effect, {
      'bleed': ' Les survivants saignent.',
      'burn': ' Les survivants brûlent.',
      'stun': ' Étourdit les ennemis sensibles à cet effet.',
      'other': '',
    });
    return 'Lance une bombe en cloche vers l’ennemi atteignable le plus éloigné dans un rayon de $rangeString unités, ou devant toi en l’absence de cible. Elle explose au contact d’un ennemi ou du terrain, ou $fuse secondes après le lancer, et inflige $damage dégâts dans un rayon de $radiusString unités.$_temp0 Le terrain solide bloque l’explosion. Utilise des provisions qui se régénèrent.';
  }

  @override
  String hunterMark({
    required num range,
    required num duration,
    required num bonus,
  }) {
    final intl.NumberFormat rangeNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String rangeString = rangeNumberFormat.format(range);
    final intl.NumberFormat durationNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String durationString = durationNumberFormat.format(duration);
    final intl.NumberFormat bonusNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String bonusString = bonusNumberFormat.format(bonus);

    return 'Marque l’ennemi visible le plus proche dans un rayon de $rangeString unités pendant $durationString secondes. Tes attaques directes lui infligent $bonusString % de dégâts supplémentaires. Sans cible, aucun coût ni délai de récupération.';
  }

  @override
  String hunterShot({
    required String aim,
    required String damage,
    required int pellets,
    required String piercing,
    required int maxHits,
    required String charged,
    required num minDamage,
    required num maxDamage,
    required num crit,
    required int chargeHits,
  }) {
    final intl.NumberFormat pelletsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pelletsString = pelletsNumberFormat.format(pellets);
    final intl.NumberFormat maxHitsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String maxHitsString = maxHitsNumberFormat.format(maxHits);
    final intl.NumberFormat minDamageNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minDamageString = minDamageNumberFormat.format(minDamage);
    final intl.NumberFormat maxDamageNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String maxDamageString = maxDamageNumberFormat.format(maxDamage);
    final intl.NumberFormat critNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String critString = critNumberFormat.format(crit);
    final intl.NumberFormat chargeHitsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String chargeHitsString = chargeHitsNumberFormat.format(chargeHits);

    String _temp0 = intl.Intl.selectLogic(aim, {
      'automatic': 'Vise automatiquement et tire sur un ennemi proche.',
      'other': 'Vise, puis relâche pour tirer.',
    });
    String _temp1 = intl.Intl.pluralLogic(
      pellets,
      locale: localeName,
      other: ' répartis entre $pelletsString projectiles',
      one: '',
    );
    String _temp2 = intl.Intl.selectLogic(piercing, {
      'yes': ' Chaque projectile peut toucher jusqu’à $maxHitsString ennemis.',
      'other': '',
    });
    String _temp3 = intl.Intl.selectLogic(charged, {
      'yes':
          ' La charge fait passer les dégâts de $minDamageString % à $maxDamageString %, ajoute jusqu’à $critString % de chances de coup critique et traverse jusqu’à $chargeHitsString ennemis à pleine charge. Subir des dégâts interrompt la charge.',
      'other': '',
    });
    return '$_temp0 Inflige $damage dégâts de base$_temp1.$_temp2$_temp3 Utilise des provisions qui se régénèrent.';
  }

  @override
  String hunterLunge({required String damage}) {
    return 'Prépare brièvement ta lame, puis fonce automatiquement vers l’avant en frappant. Chaque ennemi sur le passage de la lame subit une fois $damage dégâts de base. Une courte récupération suit. Les obstacles solides arrêtent la charge. Tu restes vulnérable pendant toute l’action.';
  }

  @override
  String hunterMelee({required int swings, required String damage}) {
    final intl.NumberFormat swingsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String swingsString = swingsNumberFormat.format(swings);

    String _temp0 = intl.Intl.pluralLogic(
      swings,
      locale: localeName,
      other: '$swingsString fois',
      one: 'une fois',
    );
    return 'Frappe devant toi $_temp0, en infligeant $damage dégâts par coup. Chaque coup peut toucher une fois chaque ennemi à portée.';
  }

  @override
  String get hunterDoubleJump =>
      'Saute, puis appuie à nouveau en l’air pour un second saut.';

  @override
  String hunterBlink({required num width}) {
    final intl.NumberFormat widthNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String widthString = widthNumberFormat.format(width);

    return 'Téléporte-toi vers l’avant, au sol ou en l’air, à travers un obstacle proche d’au plus $widthString unités de large. Il faut un espace libre de l’autre côté. Une sortie bloquée ne coûte rien. Tu es intouchable uniquement pendant la disparition ; les dégâts interrompent la préparation et la récupération.';
  }

  @override
  String hunterDoubleDash({required String window}) {
    return 'Fais une ruée au sol ou en l’air, puis appuie à nouveau dans les $window secondes après la première pour en effectuer une seconde. Tu peux changer de direction entre les deux. Chaque ruée consomme le coût indiqué ; le délai de récupération commence à la première. Ne confère pas d’invulnérabilité.';
  }

  @override
  String get hunterDash =>
      'Fais une ruée vers l’avant au sol ou en l’air. Ne confère pas d’invulnérabilité.';

  @override
  String get gearStatusSlow => 'Ralentissement';

  @override
  String get gearStatusStun => 'Étourdissement';

  @override
  String get gearStatusSilence => 'Silence';

  @override
  String get gearStatusVulnerable => 'Vulnérabilité';

  @override
  String get gearStatusWeaken => 'Affaiblissement';

  @override
  String get gearStatusDrench => 'Trempé';

  @override
  String get gearStatusHaste => 'Hâte';

  @override
  String get gearStatusDamageReduction => 'Réduction des dégâts';

  @override
  String get gearStatusOffenseBuff => 'bonus offensif';

  @override
  String get abilityMaxSupplies => 'provisions maximales';

  @override
  String get uiChooseYourName => 'Choisis ton nom';

  @override
  String get uiThisIsRequiredYouCanChangeItLaterInProfile =>
      'Ce nom est obligatoire. Tu pourras le modifier plus tard dans ton profil.';

  @override
  String get uiDisplayName => 'Nom affiché';

  @override
  String get uiConfirm => 'Confirmer';

  @override
  String get uiSomethingWentWrong => 'Une erreur est survenue.';

  @override
  String get uiEdit => 'Modifier';

  @override
  String get uiSave => 'Enregistrer';

  @override
  String get uiCancel => 'Annuler';

  @override
  String get uiRank => 'Rang';

  @override
  String get uiName => 'Nom';

  @override
  String get uiLvl => 'Niv.';

  @override
  String get uiCharacter => 'Personnage';

  @override
  String get uiScore => 'Score';

  @override
  String get uiDistance => 'Distance';

  @override
  String get uiTime => 'Temps';

  @override
  String get uiUnknown => 'Inconnu';

  @override
  String get uiNewActivity => 'Nouvelle activité';

  @override
  String get uiComingSoon => 'Bientôt disponible';

  @override
  String get uiHealth => 'Santé';

  @override
  String get uiMana => 'Mana';

  @override
  String get uiSupplies => 'Provisions';

  @override
  String get uiStamina => 'Endurance';

  @override
  String get uiWallet => 'Solde : ';

  @override
  String get uiRunReward => 'Récompense : +';

  @override
  String get uiSavingReplayKeepThisScreenOpenUntilItIsSaved =>
      'Enregistrement de la partie. Garde cet écran ouvert jusqu’à la fin de l’enregistrement.';

  @override
  String
  get uiReplayCouldNotBeSavedRetryBeforeLeavingOrExitWithoutAVerifiedReward =>
      'Impossible d’enregistrer la partie. Réessaie avant de quitter ou quitte sans récompense vérifiée.';

  @override
  String get uiSavingReplay => 'Enregistrement de la partie';

  @override
  String get uiReplaySaveFailed => 'Échec de l’enregistrement';

  @override
  String get uiRetrySaving => 'Réessayer l’enregistrement';

  @override
  String get uiVerification => 'Vérification : ';

  @override
  String get uiVerificationDelayed => 'Vérification retardée';

  @override
  String get uiCollectScore => 'Collecter le score';

  @override
  String get uiSkip => 'Passer';

  @override
  String get uiRestart => 'Recommencer';

  @override
  String get uiExit => 'Quitter';

  @override
  String get uiExitWithoutReward => 'Quitter sans récompense';

  @override
  String get uiSavingReplayLabel => 'Enregistrement de la partie';

  @override
  String get uiLoadingRankSummary => 'Chargement du classement…';

  @override
  String get uiPractice => 'Entraînement';

  @override
  String get uiCompetitive => 'Compétitif';

  @override
  String get uiWeekly => 'Hebdomadaire';

  @override
  String get uiLoadingLeaderboard => 'Chargement du classement…';

  @override
  String get uiNoRunsYet => 'Aucune course pour le moment.';

  @override
  String get uiActualRankUnavailableRightNow =>
      'Classement actuel momentanément indisponible.';

  @override
  String get uiActualRankUnavailable => 'Classement actuel indisponible.';

  @override
  String get uiUnranked => 'Non classé';

  @override
  String get uiUnableToLoadAchievementsReopenThisPageToRetry =>
      'Impossible de charger les succès. Rouvre cette page pour réessayer.';

  @override
  String get uiUnableToClaimRewardsPleaseTryAgain =>
      'Impossible de récupérer les récompenses. Réessaie.';

  @override
  String get uiHallOfHonour => 'Hall d’honneur';

  @override
  String get uiAchievementsAreUnavailableInDeveloperPractice =>
      'Les succès sont indisponibles dans l’entraînement développeur.';

  @override
  String get uiLoadingAchievements => 'Chargement des succès…';

  @override
  String get uiAchievementsAreNotAvailableYet =>
      'Les succès ne sont pas encore disponibles.';

  @override
  String get uiClaimAll => 'Tout récupérer';

  @override
  String get uiClaim => 'Récupérer';

  @override
  String get uiCompleted => 'Terminé';

  @override
  String get uiBronze => 'Bronze';

  @override
  String get uiSilver => 'Argent';

  @override
  String get uiGold => 'Or';

  @override
  String get uiClaimed => 'Récupéré';

  @override
  String get uiAvailable => 'Disponible';

  @override
  String get uiNotReached => 'Non atteint';

  @override
  String get uiTown => 'Ville';

  @override
  String get uiProfile => 'Profil';

  @override
  String get uiTop => 'Classement';

  @override
  String get uiMessages => 'Messages';

  @override
  String get uiUnreadMessagesOrUnclaimedGifts =>
      'Messages non lus ou cadeaux à récupérer';

  @override
  String get uiOptions => 'Options';

  @override
  String get uiCharacterSelection => 'CHOIX DU PERSONNAGE';

  @override
  String get uiLevelSelection => 'CHOIX DU NIVEAU RUNNER';

  @override
  String get uiLeaderboard => 'Classement';

  @override
  String get uiUnableToNavigateToRunStartRightNowTryAgain =>
      'Impossible de lancer la course pour le moment. Réessaie.';

  @override
  String get uiGuest => 'Invité';

  @override
  String get uiPracticeHeading => 'ENTRAÎNEMENT';

  @override
  String get uiCompetitiveHeading => 'COMPÉTITIF';

  @override
  String get uiWeeklyHeading => 'HEBDOMADAIRE';

  @override
  String get uiDeveloperModePracticeOnly =>
      'MODE DÉVELOPPEUR • Jeu local uniquement';

  @override
  String get uiWeeklyUnavailableInThisBuild =>
      'HEBDOMADAIRE • Indisponible dans cette version';

  @override
  String get uiPreparingRun => 'Préparation de la course…';

  @override
  String get uiRetrying => 'Nouvelle tentative…';

  @override
  String get uiRetry => 'Réessayer';

  @override
  String get uiLoading => 'Chargement…';

  @override
  String get uiFailedToLoadLeaderboard =>
      'Impossible de charger le classement.';

  @override
  String get uiLoadingOnlineLeaderboard => 'Chargement du classement en ligne.';

  @override
  String get uiNoLeaderboardData => 'Aucune donnée de classement.';

  @override
  String get uiNoValidatedRunsYet => 'Aucune course validée pour le moment.';

  @override
  String get uiVsGhost => 'Contre un fantôme';

  @override
  String get uiRaceThisGhost => 'Affronte ce fantôme.';

  @override
  String get uiGhostUnavailableForThisRun =>
      'Fantôme indisponible pour cette course.';

  @override
  String get uiNoRankedPlayersYet => 'Aucun joueur classé pour le moment.';

  @override
  String get uiYouAreNotRankedOnThisBoardYet =>
      'Tu n’es pas encore classé dans ce tableau.';

  @override
  String get uiYourRank => 'Ton rang : ';

  @override
  String get uiNoActiveLeaderboardBoardForThisModeAndLevel =>
      'Aucun classement actif pour ce mode et ce niveau.';

  @override
  String get uiLeaderboardBoardIsNotAvailableRightNow =>
      'Ce classement est momentanément indisponible.';

  @override
  String get uiFailedToLoadOnlineLeaderboard =>
      'Impossible de charger le classement en ligne.';

  @override
  String get uiBestiary => 'Bestiaire';

  @override
  String get uiBestiaryBoss => 'Bestiaire • Boss';

  @override
  String get uiFieldNotes => 'Notes de terrain';

  @override
  String get uiEntryLocked => 'Entrée verrouillée';

  @override
  String get uiLocations => 'Lieux';

  @override
  String get uiSummonedCreature => 'Créature invoquée';

  @override
  String get uiBehaviour => 'Comportement';

  @override
  String get uiAttacks => 'Attaques';

  @override
  String get uiResistances => 'Résistances';

  @override
  String get uiNoInnateDamageResistances =>
      'Aucune résistance innée aux dégâts.';

  @override
  String get uiWeaknesses => 'Faiblesses';

  @override
  String get uiNoInnateDamageWeaknesses => 'Aucune faiblesse innée aux dégâts.';

  @override
  String get uiOpen => 'Ouvrir';

  @override
  String get uiJournal => 'Journal';

  @override
  String get uiCloseLocation => 'Fermer le lieu';

  @override
  String get uiResetMap => 'Recentrer la carte';

  @override
  String get uiUnableToMarkThisMessageAsReadPleaseTryAgain =>
      'Impossible de marquer ce message comme lu. Réessaie.';

  @override
  String
  get uiUnableToConfirmTheClaimPleaseTryAgainYourGiftCanOnlyBeClaimedOnce =>
      'Impossible de confirmer la récupération. Réessaie. Tu ne peux récupérer ce cadeau qu’une seule fois.';

  @override
  String get uiUnableToConfirmDeletionPleaseTryAgain =>
      'Impossible de confirmer la suppression. Réessaie.';

  @override
  String get uiMessagesAreUnavailableInThisProfile =>
      'Les messages sont indisponibles pour ce profil.';

  @override
  String get uiGameMessages => 'Messages du jeu';

  @override
  String get uiRefreshMessages => 'Actualiser les messages';

  @override
  String get uiMoreMessagesAreAvailable =>
      'D’autres messages sont disponibles.';

  @override
  String get uiNoMessagesYet => 'Aucun message pour le moment.';

  @override
  String get uiYourMessagesWillAppearHere => 'Tes messages apparaîtront ici.';

  @override
  String get uiLoadMore => 'Charger la suite';

  @override
  String get uiLoadingLabel => 'Chargement…';

  @override
  String get uiSelectAMessageToReadIt => 'Sélectionne un message pour le lire.';

  @override
  String
  get uiClaimYourGoldBeforeDeletingThisMessageUnclaimedGoldDoesNotExpire =>
      'Récupère ton or avant de supprimer ce message. L’or non récupéré n’expire pas.';

  @override
  String
  get uiClaimYourGiftsBeforeDeletingThisMessageUnclaimedGiftsDoNotExpire =>
      'Récupère tes cadeaux avant de supprimer ce message. Les cadeaux non récupérés n’expirent pas.';

  @override
  String get uiAutomaticallyRemoved30DaysAfterClaiming =>
      'Suppression automatique 30 jours après récupération.';

  @override
  String get uiAutomaticallyRemoved30DaysAfterReading =>
      'Suppression automatique 30 jours après lecture.';

  @override
  String get uiAlreadyOwnedGiftsGrantNoDuplicateUnlockOrCompensation =>
      'Les cadeaux déjà possédés ne donnent aucun déblocage en double ni compensation.';

  @override
  String get uiRetryReading => 'Réessayer la lecture';

  @override
  String get uiPleaseWait => 'Patiente…';

  @override
  String get uiDeleteMessage => 'Supprimer le message';

  @override
  String get uiUnread => 'Non lu';

  @override
  String get uiGiftAvailable => 'Cadeau disponible';

  @override
  String get uiNameIsUnchanged => 'Le nom est inchangé.';

  @override
  String get uiNameUpdated => 'Nom mis à jour';

  @override
  String get uiAccountDeletionIsInProgress =>
      'La suppression du compte est en cours.';

  @override
  String get uiPleaseSignInAgainAndRetryAccountDeletion =>
      'Reconnecte-toi et réessaie de supprimer ton compte.';

  @override
  String get uiSessionExpiredPleaseRestartTheGameAndTryAgain =>
      'Ta session a expiré. Redémarre le jeu et réessaie.';

  @override
  String get uiAccountDeletionIsNotAvailableInThisEnvironment =>
      'La suppression du compte est indisponible dans cet environnement.';

  @override
  String get uiAccountDeletionFailedPleaseTryAgain =>
      'La suppression du compte a échoué. Réessaie.';

  @override
  String get uiAccountDeleted => 'Compte supprimé.';

  @override
  String get uiPlayGamesAccountLinked => 'Compte Play Games associé.';

  @override
  String get uiPlayGamesIsAlreadyLinked => 'Play Games est déjà associé.';

  @override
  String get uiPlayGamesSignInCanceled => 'Connexion à Play Games annulée.';

  @override
  String get uiPlayGamesSignInIsNotAvailableOnThisDevice =>
      'La connexion à Play Games est indisponible sur cet appareil.';

  @override
  String get uiCouldNotLinkPlayGamesAccountPleaseTryAgain =>
      'Impossible d’associer le compte Play Games. Réessaie.';

  @override
  String get uiDeleteAccountAndData => 'Supprimer le compte et les données ?';

  @override
  String get uiContinue => 'Continuer';

  @override
  String get uiFinalConfirmation => 'Confirmation finale';

  @override
  String get uiThisActionCannotBeUndoneDeleteThisAccountPermanently =>
      'Cette action est irréversible. Supprimer définitivement ce compte ?';

  @override
  String get uiKeepAccount => 'Conserver le compte';

  @override
  String get uiDeleteAccount => 'Supprimer le compte';

  @override
  String get uiAccountDeletionWasAcceptedDeviceCleanupNeedsAnotherAttempt =>
      'La suppression du compte a été acceptée. Le nettoyage de l’appareil nécessite une nouvelle tentative.';

  @override
  String get uiRetryCleanup => 'Réessayer le nettoyage';

  @override
  String get uiEnterName => 'Saisis un nom';

  @override
  String get uiPlayerStats => 'Statistiques du joueur';

  @override
  String get uiLifetimeXp => 'EXP totale';

  @override
  String get uiPracticeRunsPlayed => 'Courses d’entraînement jouées';

  @override
  String get uiCompetitiveRunsPlayed => 'Courses compétitives jouées';

  @override
  String get uiEnemiesDefeated => 'Ennemis vaincus';

  @override
  String get uiDamageDealt => 'Dégâts infligés';

  @override
  String get uiDamageTaken => 'Dégâts subis';

  @override
  String get uiDangerZone => 'Zone sensible';

  @override
  String get uiDeleteYourAccountAndAllLinkedPlayerDataPermanently =>
      'Supprime définitivement ton compte et toutes les données de joueur associées.';

  @override
  String get uiUpgradeGuestAccount => 'Associer le compte invité';

  @override
  String get uiLinkPlayGamesToKeepProgressAcrossDevices =>
      'Associe Play Games pour conserver ta progression sur tous tes appareils.';

  @override
  String get uiLinking => 'Association…';

  @override
  String get uiLinkPlayGames => 'Associer Play Games';

  @override
  String get uiRenameBuild => 'Renommer la configuration';

  @override
  String get uiEnterABuildName => 'Saisis un nom de configuration.';

  @override
  String get uiCouldNotSaveTheNamePleaseTryAgain =>
      'Impossible d’enregistrer le nom. Réessaie.';

  @override
  String get uiBuildName => 'Nom de la configuration';

  @override
  String get uiSaving => 'Enregistrement…';

  @override
  String get uiCouldNotSaveThisSelectionPleaseTryAgain =>
      'Impossible d’enregistrer cette sélection. Réessaie.';

  @override
  String get uiChooseYourCharacter => 'Choisis ton personnage';

  @override
  String get uiNoOptionsForThisSlot => 'Aucune option pour cet emplacement.';

  @override
  String get uiSelectAnItemToPreviewStats =>
      'Sélectionne un objet pour voir ses statistiques.';

  @override
  String get uiNoNonZeroStatBonuses => 'Aucun bonus de statistique non nul.';

  @override
  String get uiVisitTownStore => 'Visiter la boutique en ville ?';

  @override
  String get uiGoToTown => 'Aller en ville';

  @override
  String get uiEquip => 'Équiper';

  @override
  String get uiGear => 'Équipement';

  @override
  String get uiSkills => 'Compétences';

  @override
  String get uiTrainingField => 'Terrain d’entraînement';

  @override
  String get uiNoAbilityAvailableForThisSlot =>
      'Aucune compétence disponible pour cet emplacement.';

  @override
  String get uiNoAbilityDetailsAvailableRightNow =>
      'Les détails de la compétence sont momentanément indisponibles.';

  @override
  String get uiCooldown => 'Récupération : ';

  @override
  String get uiMaxDuration => 'Durée maximale : ';

  @override
  String get uiUnlockThisSkillInTownToViewFullDetails =>
      'Débloque cette compétence en ville pour voir tous ses détails.';

  @override
  String get uiFindInTown => 'Trouver en ville';

  @override
  String get uiSelectProjectile => 'Choisir un projectile';

  @override
  String get uiDamage => 'Dégâts : ';

  @override
  String get uiSelectProjectileSource => 'Choisir la source du projectile';

  @override
  String get uiClose => 'Fermer';

  @override
  String get uiSelectWeapon => 'Choisir une arme';

  @override
  String get uiChooseTrainingOpponent => 'Choisir un adversaire d’entraînement';

  @override
  String get uiReset => 'Réinitialiser';

  @override
  String get uiResume => 'Reprendre';

  @override
  String get uiRetryLoadingTrainingField =>
      'Réessayer de charger le terrain d’entraînement';

  @override
  String get uiTrainingOpponent => 'Adversaire d’entraînement';

  @override
  String get uiChooseAnOpponentForYourNextFight =>
      'Choisis un adversaire pour ton prochain combat.';

  @override
  String get uiUnlockEnemyEntriesInTheLibraryToPractiseAgainstThem =>
      'Débloque les entrées des ennemis dans la bibliothèque pour t’entraîner contre eux.';

  @override
  String get uiNone => 'Aucun';

  @override
  String get uiPractiseWithoutAnOpponent => 'Entraîne-toi sans adversaire.';

  @override
  String get uiSelectLevel => 'Choisir un niveau';

  @override
  String get uiYourGoldIsReady => 'Ton or est prêt';

  @override
  String get uiYourRewardsAreOnTheirWay => 'Tes récompenses arrivent';

  @override
  String get uiYourBalanceHasChanged => 'Ton solde a changé';

  @override
  String get uiYourRunRewardsAreConfirmedYouCanNowSpendYourGold =>
      'Les récompenses de ta course sont confirmées. Tu peux maintenant dépenser ton or.';

  @override
  String
  get uiWeReConfirmingYourLatestRunRewardsBeforeTheyCanBeSpentYouCanKeepPlayingWhileWeFinish =>
      'Nous vérifions les récompenses de ta dernière course avant que tu puisses les dépenser. Tu peux continuer à jouer pendant ce temps.';

  @override
  String
  get uiThereIsnTEnoughGoldForThisPurchaseReturnToTheStoreToSeeYourUpdatedBalance =>
      'Tu n’as pas assez d’or pour cet achat. Retourne à la boutique pour voir ton solde à jour.';

  @override
  String get uiBackToStore => 'Retour à la boutique';

  @override
  String get uiGotIt => 'Compris';

  @override
  String get uiStore => 'Boutique';

  @override
  String get uiLibrary => 'Bibliothèque';

  @override
  String get uiAchievementRewardsAvailable =>
      'Récompenses de succès disponibles';

  @override
  String get uiStoreMarker => 'Repère de la boutique';

  @override
  String get uiLibraryMarker => 'Repère de la bibliothèque';

  @override
  String get uiHallOfHonourMarker => 'Repère du hall d’honneur';

  @override
  String get uiTownStore => 'Boutique en ville';

  @override
  String get uiPurchaseFailedPleaseTryAgain => 'L’achat a échoué. Réessaie.';

  @override
  String get uiRefreshStore => 'Actualiser la boutique ?';

  @override
  String get uiRefreshingTheStoreCosts =>
      'Coût de l’actualisation de la boutique';

  @override
  String get uiCost => 'Coût';

  @override
  String get uiAreYouSureYouWantToRefreshTheStore =>
      'Veux-tu vraiment actualiser la boutique ?';

  @override
  String get uiRefresh => 'Actualiser';

  @override
  String get uiStoreRefreshed => 'Boutique actualisée.';

  @override
  String get uiRefreshFailedPleaseTryAgain =>
      'L’actualisation a échoué. Réessaie.';

  @override
  String get uiNotEnoughGoldForThatAction =>
      'Tu n’as pas assez d’or pour cette action.';

  @override
  String get uiThatOfferIsNoLongerAvailable =>
      'Cette offre n’est plus disponible.';

  @override
  String get uiYouAlreadyOwnThisUnlock => 'Tu possèdes déjà ce contenu.';

  @override
  String get uiDailyRefreshLimitReached =>
      'Limite quotidienne d’actualisation atteinte.';

  @override
  String get uiRefreshMethodIsNotAvailable =>
      'Cette méthode d’actualisation est indisponible.';

  @override
  String get uiNoOfferCanChangeRightNow =>
      'Aucune offre ne peut changer pour le moment.';

  @override
  String get uiRewardVerificationIsNotActiveYet =>
      'La vérification des récompenses n’est pas encore active.';

  @override
  String get uiRewardHasAlreadyBeenUsed =>
      'Cette récompense a déjà été utilisée.';

  @override
  String get uiRewardHasExpired => 'Cette récompense a expiré.';

  @override
  String get uiActionRejectedPleaseTryAgain => 'Action refusée. Réessaie.';

  @override
  String get uiRefreshing => 'Actualisation…';

  @override
  String get uiNoOffersAvailableRightNow =>
      'Aucune offre disponible pour le moment.';

  @override
  String get uiBuying => 'Achat…';

  @override
  String get uiBuy => 'Acheter';

  @override
  String get uiNoDetailsAvailableRightNow =>
      'Aucun détail disponible pour le moment.';

  @override
  String get bootstrapStartFailed => 'Impossible de démarrer le jeu';

  @override
  String get bootstrapAccountUnavailable => 'Compte de jeu indisponible';

  @override
  String get bootstrapSignInRequired => 'Connexion à Play Games requise';

  @override
  String get bootstrapDataFailed =>
      'Impossible de charger les données du joueur';

  @override
  String get bootstrapAccountDisabled =>
      'Ce compte de jeu est désactivé. Si tu viens de le supprimer, attends la fin de la suppression avant de te reconnecter. Cela peut prendre plusieurs heures. Tu pourras ensuite utiliser le même compte Play Games pour recommencer.';

  @override
  String get bootstrapUnsupported =>
      'Cette plateforme ne prend pas en charge les services nécessaires au jeu.';

  @override
  String get bootstrapServiceFailure =>
      'Les services du jeu n’ont pas pu démarrer. Vérifie ta connexion et réessaie.';

  @override
  String get bootstrapDataFailure =>
      'Tes données de joueur n’ont pas pu être chargées. Vérifie ta connexion et réessaie.';

  @override
  String get bootstrapRetry => 'Réessayer';

  @override
  String get bootstrapRetrySignIn => 'Réessayer la connexion à Play Games';

  @override
  String get bootstrapSignInBody => 'Connecte-toi à Play Games pour continuer.';

  @override
  String get bootstrapFailed => 'Échec du démarrage';

  @override
  String get loaderGameTitle => 'The Long Run';

  @override
  String get loaderWorldTitle => 'Lothringen';

  @override
  String get playButton => 'JOUER';

  @override
  String get runUpdateRequired =>
      'Mets le jeu à jour avant de lancer une nouvelle course. Ton compte et tes récompenses en attente restent disponibles.';

  @override
  String get runMaintenance =>
      'Le jeu est en maintenance. Réessaie plus tard. Tes courses et récompenses en attente seront récupérées.';

  @override
  String get runInvalidLoadout =>
      'Ajuste ton équipement et tes compétences avant de commencer.';

  @override
  String get runLevelUnavailable =>
      'Ce niveau est indisponible dans cette version. Retourne à l’accueil et choisis un niveau disponible.';

  @override
  String get runRequirementsChanged =>
      'Les conditions de départ ont changé. Retourne à l’accueil et réessaie.';

  @override
  String get runStartFailed =>
      'Impossible de lancer une course pour le moment. Vérifie ta connexion et réessaie.';

  @override
  String get runRecorderPreparing => 'Préparation de l’enregistrement…';

  @override
  String get runTerrainPreparing => 'Préparation du terrain…';

  @override
  String get runGhostPreparing => 'Préparation du fantôme…';

  @override
  String get runArtLoading => 'Chargement des graphismes…';

  @override
  String get runBuildingLevel => 'Construction du niveau…';

  @override
  String get runWorldFailed =>
      'Impossible de charger le niveau. Réessaie ou retourne à l’écran précédent.';

  @override
  String get runRecorderFailed =>
      'Impossible de préparer l’enregistrement. Vérifie l’espace de stockage disponible et réessaie.';

  @override
  String get nameRequired => 'Un nom est obligatoire.';

  @override
  String get nameCharacters =>
      'Seuls les lettres non accentuées, les chiffres, les espaces, « _ » et « - » sont autorisés.';

  @override
  String get nameReserved => 'Ce nom est réservé.';

  @override
  String get nameDisallowed => 'Ce nom n’est pas autorisé.';

  @override
  String get nameTaken => 'Ce nom est déjà pris.';

  @override
  String get nameSaveFailed => 'Impossible d’enregistrer le nom. Réessaie.';

  @override
  String get nameServerUnavailable =>
      'Impossible de joindre le serveur. Vérifie ta connexion et réessaie.';

  @override
  String get nameServiceUnavailable =>
      'Le service des noms est indisponible. Réessaie plus tard.';

  @override
  String get nameInvalid => 'Choisis un nom valide et réessaie.';

  @override
  String get updateRequiredTitle => 'Mise à jour requise';

  @override
  String get maintenanceTitle => 'Maintenance';

  @override
  String get openGooglePlay => 'Ouvrir Google Play';

  @override
  String get installCurrentBuild =>
      'Installe la version actuelle pour cet environnement.';

  @override
  String nameTooShort({required int min}) {
    final intl.NumberFormat minNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String minString = minNumberFormat.format(min);

    return 'Le nom doit contenir au moins $minString caractères.';
  }

  @override
  String nameTooLong({required int max}) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'Le nom doit contenir au plus $maxString caractères.';
  }

  @override
  String get achievementFirstSteps => 'Premiers pas';

  @override
  String get achievementMarathoner => 'Marathonien';

  @override
  String get achievementRoadWarrior => 'Vétéran des routes';

  @override
  String get achievementStillStanding => 'Toujours debout';

  @override
  String get achievementSlayer => 'Pourfendeur';

  @override
  String get achievementQualifying =>
      'Les courses vérifiées d’entraînement, compétitives et hebdomadaires comptent après 100 mètres ou 30 secondes et doivent se terminer naturellement. Abandonner ne compte pas.';

  @override
  String get achievementAllRuns =>
      'Les courses vérifiées d’entraînement, compétitives et hebdomadaires comptent, même si elles sont courtes ou abandonnées.';

  @override
  String achievementRuns({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString courses',
      one: '1 course',
    );
    return '$_temp0';
  }

  @override
  String achievementEnemies({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ennemis',
      one: '1 ennemi',
    );
    return '$_temp0';
  }

  @override
  String achievementDistance({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString m';
  }

  @override
  String achievementFinish({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString courses admissibles',
      one: '1 course admissible',
    );
    return 'Termine $_temp0.';
  }

  @override
  String achievementReach({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Atteins $countString mètres en une course.';
  }

  @override
  String achievementTravel({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Parcours $countString mètres au fil de tes courses.';
  }

  @override
  String achievementSurvive({required String duration}) {
    return 'Survis $duration au fil de tes courses.';
  }

  @override
  String achievementDefeat({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ennemis',
      one: '1 ennemi',
    );
    return 'Vaincs $_temp0 au fil de tes courses.';
  }

  @override
  String durationHours({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString h';
  }

  @override
  String durationMinutes({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString min';
  }

  @override
  String durationSeconds({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString s';
  }

  @override
  String dateUtc({required String date}) {
    return '$date (UTC)';
  }

  @override
  String achievementNextReward({required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return 'Prochaine récompense : $goldString or';
  }

  @override
  String achievementProgressSummary({
    required String progress,
    required int gold,
  }) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return '$progress · Prochain gain : $goldString or';
  }

  @override
  String achievementClaimAmount({required String scope, required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    String _temp0 = intl.Intl.selectLogic(scope, {
      'all': 'Tout récupérer : $goldString',
      'other': 'Récupérer $goldString',
    });
    return '$_temp0';
  }

  @override
  String achievementClaimGoldLabel({required String scope, required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    String _temp0 = intl.Intl.selectLogic(scope, {
      'all': 'Tout récupérer : $goldString or',
      'other': 'Récupérer $goldString or',
    });
    return '$_temp0';
  }

  @override
  String get achievementWhatCounts => 'Qu’est-ce qui compte ?';

  @override
  String achievementTierStatus({required String state}) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'claimed': 'Récupéré',
      'achieved': 'Disponible',
      'next': 'En cours',
      'other': 'Verrouillé',
    });
    return '$_temp0';
  }

  @override
  String achievementTierReward({required int gold, required String state}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    String _temp0 = intl.Intl.selectLogic(state, {
      'claimed': 'Récupéré',
      'achieved': 'Disponible',
      'next': 'En cours',
      'other': 'Verrouillé',
    });
    return '$goldString or · $_temp0';
  }

  @override
  String achievementAchievedDate({required String date}) {
    return 'Obtenu le $date';
  }

  @override
  String goldAmount({required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return '$goldString or';
  }

  @override
  String progressQuantities({required String current, required String target}) {
    return '$current / $target';
  }

  @override
  String get codexGrojibLore =>
      'Grojib réduit la distance sans hésiter. Un voyageur qui tient sa position après le premier coup risque de voir une nouvelle frappe déjà en route.';

  @override
  String get codexHashashLore =>
      'Hashash combat dans l’incertitude de la forêt, surgissant là où l’attention s’est déjà détournée. Dans ces bois, un chemin apparemment vide ne promet pas un passage sans danger.';

  @override
  String get codexDerfLore =>
      'L’apparence de Derf dissimule une transformation qui fait de ce lanceur de sorts à distance une menace tentaculaire lancée à ta poursuite.';

  @override
  String get codexUnocoLore =>
      'Les démons Unoco rencontrés au-dessus de la forêt portent la menace au-dessus des sentiers, là où les murs et le terrain accidenté protègent peu d’un sort lancé depuis les airs.';

  @override
  String get codexBringerLore =>
      'Le Porteur de mort barre le passage dans une clairière gagnée par les ténèbres. Sa faux et ses piliers jaillissants laissent peu de place à l’hésitation. Vaincre ce gardien ouvre la voie vers les profondeurs de la forêt.';

  @override
  String get codexGoddessLore =>
      'Le nom de Déesse née du Vide témoigne de la terreur de la rencontre, sans prouver une nature divine. Cette présence fait de la clairière elle-même une menace. Ce qui l’a menée dans la forêt reste inconnu.';

  @override
  String get codexShoggothLore =>
      'Shoggoth se trouve parmi les horreurs les plus profondes qui gardent la route. De petites créatures accompagnent ses assauts, transformant le combat en lutte pour garder un peu de terrain plutôt qu’en duel. Son origine lointaine n’a pas été consignée.';

  @override
  String get codexVoidcallerLore =>
      'La présence de l’Invocateur du Vide se manifeste par des rayons, des griffes jaillissantes et des tentacules invoqués. Son titre décrit ce qu’ont vu les voyageurs ; la nature de ce qui répond à son appel reste incertaine.';

  @override
  String get codexShoggothMinionLore =>
      'Ces petites créatures entrent dans le combat à l’appel de Shoggoth. Elles font partie de la même menace immédiate, pressant l’adversaire pendant que la grande créature prépare son prochain assaut. Leur apparition annonce que le terrain autour de Shoggoth ne restera pas dégagé.';

  @override
  String get codexVoidTentacleLore =>
      'Un tentacule appelé dans l’arène est une manifestation locale de la portée de l’Invocateur du Vide. Il rend dangereux un espace encore libre un instant auparavant. Le détruire supprime cette menace, mais il reste à affronter la puissance qui l’invoque.';

  @override
  String get codexGrojibTactics =>
      'Un poursuivant terrestre dont la seconde frappe de mêlée peut étourdir.';

  @override
  String get codexHashashTactics =>
      'Un assassin mobile qui tend des embuscades en se téléportant.';

  @override
  String get codexDerfTactics =>
      'Se transforme de lanceur de sorts en poursuivant de mêlée. Son tentacule allongé donne une portée inhabituelle à sa frappe.';

  @override
  String get codexUnocoTactics =>
      'Un lanceur de sorts volant qui peut aussi frapper de près.';

  @override
  String get codexBringerTactics =>
      'Un combattant à la faux qui fait jaillir des piliers de ténèbres.';

  @override
  String get codexGoddessTactics =>
      'Combine des coups de griffe, des orbes sombres et des éruptions au sol.';

  @override
  String get codexShoggothTactics =>
      'Utilise des tentacules, des orbes sombres et des créatures invoquées.';

  @override
  String get codexVoidcallerTactics =>
      'Utilise des rayons verticaux et diagonaux, des griffes de feu et des tentacules invoqués.';

  @override
  String get codexShoggothMinionTactics =>
      'Un petit attaquant terrestre invoqué par Shoggoth.';

  @override
  String get codexVoidTentacleTactics => 'Une menace de mêlée invoquée.';

  @override
  String get codexForestLore =>
      'À l’écart de Théodonis, dans une partie plus sombre de la forêt des Moyen-Ducs, l’avant-poste du Val rassemble une demi-douzaine de grandes tentes au sein d’un camp bien organisé et protégé. En temps calme, il maintient une présence sur la route et prépare les soldats aux rigueurs du combat et de la survie en forêt.\n\nLe capitaine Théo y commande vingt-quatre gardes forestiers d’élite, tandis qu’Hanna, médecin de terrain, soigne les blessés. Leur mission est de contenir l’expansion d’une tribu de gobelours qui a franchi la Vosga et de sécuriser les abords de la route. Les tensions reviennent par vagues : le poste doit les contenir avant qu’elles n’atteignent Théodonis.\n\nLe Val est aussi un relais vers la cité. Son capitaine peut y faire transmettre un message, et le camp offre un refuge aux voyageurs en difficulté : un repas chaud, une place propre où dormir, et quelques heures sous la garde des soldats. Au-delà des tentes, la forêt reste dangereuse.';

  @override
  String get codexFieldLore =>
      'La Ferme des Léonards est le plus grand domaine agricole des environs de Théodonis. Une puissante famille supervise ses champs et ses récoltes.';

  @override
  String get levelForestName => 'Avant-poste du Val';

  @override
  String get levelFieldName => 'Ferme des Léonards';

  @override
  String get levelDeprecatedName => 'Nouveau niveau';

  @override
  String get townName => 'Théodonis';

  @override
  String libraryTitle({required String section}) {
    return 'Bibliothèque · $section';
  }

  @override
  String codexUnlockEnemy({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Vaincs-en $countString pour révéler ses attaques, ses résistances et ses notes de terrain.';
  }

  @override
  String codexDefeatedProgress({required int current, required int target}) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat targetNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$currentString / $targetString vaincus.';
  }

  @override
  String codexUnlockLevel({required int count, required String level}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Atteins $countString points en une course compétitive sur $level pour révéler son histoire.';
  }

  @override
  String codexScoreProgress({required int current, required int target}) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat targetNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$currentString / $targetString pour le meilleur score compétitif.';
  }

  @override
  String codexResistance({required String type, required num percent}) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$type : $percentString % de dégâts en moins';
  }

  @override
  String codexWeakness({required String type, required num percent}) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$type : $percentString % de dégâts en plus';
  }

  @override
  String codexDamageMix({required String type, required int percent}) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$type $percentString %';
  }

  @override
  String codexAttack({
    required String ability,
    required String category,
    required String types,
  }) {
    return '$ability • $category\nDégâts : $types';
  }

  @override
  String codexEntrySemantics({required String title, required String state}) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'discovered': 'découvert',
      'other': 'verrouillé',
    });
    return '$title, $_temp0';
  }

  @override
  String codexDefeatToUnlock({required String progress}) {
    return 'Vaincs-en $progress pour débloquer';
  }

  @override
  String codexLocationSemantics({
    required String level,
    required String state,
  }) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'open': 'ouvert',
      'other': 'verrouillé',
    });
    return '$level, $_temp0';
  }

  @override
  String codexMapMarker({required String level}) {
    return 'Repère de $level sur la carte';
  }

  @override
  String get abilityCategoryMelee => 'mêlée';

  @override
  String get abilityCategoryRanged => 'distance';

  @override
  String get abilityCategoryMobility => 'mobilité';

  @override
  String get abilityCategoryDefense => 'défense';

  @override
  String get abilityCategoryUtility => 'utilitaire';

  @override
  String get runBossFailed => 'Combat de boss perdu';

  @override
  String get runGaveUp => 'Tu as abandonné la course.';

  @override
  String get runFellBehind => 'Tu as pris trop de retard.';

  @override
  String get runFellIntoGap => 'Tu es tombé dans un gouffre.';

  @override
  String get runDied => 'Tu as perdu la vie.';

  @override
  String get runPoisonTrap =>
      'Tu as succombé au poison d’un piège à fléchettes.';

  @override
  String get runSpikeTrap => 'Tu as succombé à un piège à pointes.';

  @override
  String get runAxeTrap => 'Tu as succombé à une hache pendulaire.';

  @override
  String get runPoisonDart => 'Tu as succombé à une fléchette empoisonnée.';

  @override
  String get runStatusDeath => 'Tu as succombé à un effet de statut.';

  @override
  String get runTrapDeath => 'Tu as succombé à un piège.';

  @override
  String get runSpellDeath => 'Tu as succombé à l’impact d’un sort.';

  @override
  String get runDerfDeath => 'Tu as été consumé par l’explosion de Derf.';

  @override
  String get impactBullet => 'Balle';

  @override
  String get impactCrossbow => 'Carreau d’arbalète';

  @override
  String get impactPellet => 'Plomb de chevrotine';

  @override
  String get scoreEnemy => 'Ennemi';

  @override
  String get practiceNoRewards =>
      'Entraînement développeur\nAucune récompense ni inscription au classement.';

  @override
  String runProjectileDeath({
    required String projectile,
    required String source,
    required String enemy,
  }) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'enemy': ' de $enemy.',
      'other': '.',
    });
    return 'Tu as succombé à $projectile$_temp0';
  }

  @override
  String runMeleeDeath({required String enemy}) {
    return 'Tu as succombé à une attaque de mêlée de $enemy.';
  }

  @override
  String runEnemySpellDeath({required String enemy}) {
    return 'Tu as succombé à un sort de $enemy.';
  }

  @override
  String get submissionQueued => 'En attente';

  @override
  String get submissionRequestingUploadGrant => 'Demande d’envoi';

  @override
  String get submissionUploading => 'Envoi de la partie';

  @override
  String get submissionFinalizing => 'Finalisation';

  @override
  String get submissionRetryScheduled => 'Nouvelle tentative prévue';

  @override
  String get submissionPendingValidation => 'En attente de vérification';

  @override
  String get submissionValidating => 'Vérification en cours';

  @override
  String get submissionSettlementPending => 'Attribution de la récompense';

  @override
  String get submissionValidated => 'Validé';

  @override
  String get submissionRejected => 'Refusé';

  @override
  String get submissionExpired => 'Expiré';

  @override
  String get submissionCancelled => 'Annulé';

  @override
  String get submissionInternalError => 'Erreur interne';

  @override
  String get submissionFailureBody =>
      'La vérification n’a pas pu aboutir. Retourne à l’accueil ou contacte l’assistance si le problème persiste.';

  @override
  String runRewardXp({required int xp}) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String xpString = xpNumberFormat.format(xp);

    return '+$xpString EXP';
  }

  @override
  String scoreRowDistance({required int count, required int points}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    return 'Distance : $countString m → $pointsString';
  }

  @override
  String scoreRowCollectibles({required int count, required int points}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    return 'Objets collectés : $countString → $pointsString';
  }

  @override
  String scoreRowRescue({required int count, required int points}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    return 'PNJ secourus : $countString → $pointsString';
  }

  @override
  String scoreRowTime({required String time, required int points}) {
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    return 'Temps : $time → $pointsString';
  }

  @override
  String scoreRowEnemy({
    required String enemy,
    required int count,
    required int points,
  }) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    return '$enemy ×$countString → $pointsString';
  }

  @override
  String levelMaximumSemantics({required int level}) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'Niveau $levelString, niveau maximal atteint';
  }

  @override
  String levelProgressSemantics({
    required int level,
    required int earned,
    required int needed,
  }) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);
    final intl.NumberFormat earnedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String earnedString = earnedNumberFormat.format(earned);
    final intl.NumberFormat neededNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String neededString = neededNumberFormat.format(needed);

    return 'Niveau $levelString, $earnedString EXP sur $neededString avant le niveau suivant';
  }

  @override
  String levelMaximumLabel({required int level}) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'NIVEAU $levelString  ·  NIVEAU MAX.';
  }

  @override
  String levelProgressLabel({
    required int level,
    required int earned,
    required int needed,
  }) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);
    final intl.NumberFormat earnedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String earnedString = earnedNumberFormat.format(earned);
    final intl.NumberFormat neededNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String neededString = neededNumberFormat.format(needed);

    return 'NIVEAU $levelString  ·  $earnedString / $neededString EXP';
  }

  @override
  String scoreDistance({required int meters}) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return 'Distance $metersString m';
  }

  @override
  String scoreCollectibles({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Objets collectés $countString';
  }

  @override
  String shortDistance({required int meters}) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return '$metersString m';
  }

  @override
  String healthPoints({required int hp}) {
    final intl.NumberFormat hpNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String hpString = hpNumberFormat.format(hp);

    return '$hpString PV';
  }

  @override
  String nameChangeCooldown({required int hours, required int minutes}) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return 'Tu pourras changer de nom dans $hoursString h $minutesString min.';
  }

  @override
  String get deleteAccountBody =>
      'Ton compte, ton profil et ta progression dans le cloud seront définitivement supprimés.\n\nLa suppression peut prendre plusieurs heures. Tu ne pourras pas créer de nouveau compte avec le même profil Play Games avant sa fin.';

  @override
  String characterLockedSemantics({required String name, required int level}) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return '$name, se débloque au niveau $levelString';
  }

  @override
  String requiredLevel({required int level}) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'Niveau $levelString';
  }

  @override
  String trainingOpponent({required String enemy}) {
    return 'Adversaire : $enemy';
  }

  @override
  String storePurchaseComplete({required String item}) {
    return 'Achat effectué : $item.';
  }

  @override
  String storeRefreshesLeft({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Actualisations restantes : $countString';
  }

  @override
  String storeBrowseLocked({required String slot}) {
    String _temp0 = intl.Intl.selectLogic(slot, {
      'mainWeapon': 'les armes principales verrouillées',
      'offhandWeapon': 'les équipements secondaires verrouillés',
      'spellBook': 'les grimoires verrouillés',
      'other': 'les accessoires verrouillés',
    });
    return 'Ouvrir la ville pour consulter $_temp0 ?';
  }

  @override
  String skillHeading({required String slot}) {
    String _temp0 = intl.Intl.selectLogic(slot, {
      'primary': 'COMPÉTENCES PRINCIPALES',
      'secondary': 'COMPÉTENCES SECONDAIRES',
      'projectile': 'COMPÉTENCES DE PROJECTILE',
      'mobility': 'COMPÉTENCES DE MOBILITÉ',
      'spell': 'COMPÉTENCES DE SORT',
      'jump': 'COMPÉTENCES DE SAUT',
      'other': 'COMPÉTENCES DE TERRAIN',
    });
    return '$_temp0';
  }

  @override
  String messageHeader({required String date}) {
    return 'Jeu · $date';
  }

  @override
  String messageGiftCount({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString cadeaux d’objets ou de compétences',
      one: '1 cadeau d’objet ou de compétence',
    );
    return '$_temp0';
  }

  @override
  String weeklyBadge({required String window}) {
    String _temp0 = intl.Intl.selectLogic(window, {
      'unknown': 'RUNNER HEBDOMADAIRE',
      'other': 'RUNNER HEBDOMADAIRE - $window',
    });
    return '$_temp0';
  }

  @override
  String scoreboardTitle({required String level, required String mode}) {
    return 'Classement $mode — $level';
  }

  @override
  String leaderboardTitle({required String level, required String mode}) {
    return 'CLASSEMENT $mode — $level';
  }

  @override
  String rankTotal({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return ' / $countString';
  }

  @override
  String rankSummary({
    required String rank,
    required String position,
    required String outcome,
  }) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': ' (1re place)',
      'second': ' (2e place, podium)',
      'third': ' (3e place, podium)',
      'topTen': ' (top 10)',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(outcome, {
      'unchanged': ' ; tu n’as pas fait mieux lors de cette course.',
      'other': '.',
    });
    return 'Rang actuel : $rank$_temp0$_temp1';
  }

  @override
  String controlFollowUp({required String label}) {
    return '$label, seconde action disponible';
  }

  @override
  String get controlSword => 'Épée';

  @override
  String get controlShield => 'Bouclier';

  @override
  String get controlProjectile => 'Projectile';

  @override
  String get controlMobility => 'Mobilité';

  @override
  String get controlJump => 'Saut';

  @override
  String get controlSpell => 'Sort';

  @override
  String get controlMoveLeft => 'Aller à gauche';

  @override
  String get controlMoveRight => 'Aller à droite';

  @override
  String get controlJoystick => 'Joystick de déplacement';

  @override
  String get controlBackward => 'Arrière';

  @override
  String get controlForward => 'Avant';

  @override
  String get controlNeutral => 'Neutre';

  @override
  String get runStartErrorTitle => 'Impossible de lancer la course';

  @override
  String get studioName => 'Luxis Games';

  @override
  String defaultBuildName({required int number}) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Configuration $numberString';
  }

  @override
  String offscreenDistance({required int meters}) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return '$metersString m';
  }

  @override
  String get offscreenNearby => '<1 m';

  @override
  String offscreenGroup({required int count, required String distance}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '×$countString · $distance';
  }

  @override
  String supportLinkFailed({required String email}) {
    return 'Impossible d’ouvrir le lien. Réessaie ou contacte $email.';
  }

  @override
  String resourceRatio({required int value, required int maximum}) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);
    final intl.NumberFormat maximumNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '$valueString / $maximumString';
  }

  @override
  String quotedDescription({required String description}) {
    return '« $description »';
  }

  @override
  String get developerAppTitle => 'rpg Runner (Dev)';

  @override
  String get developerMenu => 'Menu';

  @override
  String get routeRunUnavailableTitle => 'Impossible de lancer la partie';

  @override
  String get routeRunUnavailableBody =>
      'Retourne à l’accueil et relance la partie.';

  @override
  String get routeUnavailableTitle => 'Page indisponible';

  @override
  String get routeUnavailableBody =>
      'Impossible d’ouvrir cette page. Reviens en arrière et réessaie.';

  @override
  String get inboxLoadFailed => 'Impossible de charger les messages. Réessaie.';

  @override
  String get runCleanupFailed =>
      'Impossible de fermer la partie précédente. Quitte et réessaie.';

  @override
  String get developerIdentity => 'Développeur';

  @override
  String get townEquipment => 'Boutique d’équipement';

  @override
  String get townTraining => 'Salle d’entraînement';

  @override
  String get townEquipmentMarker => 'Repère de la boutique d’équipement';

  @override
  String get townTrainingMarker => 'Repère de la salle d’entraînement';

  @override
  String get townEquipmentIntro =>
      'Choisis ton équipement pour ta prochaine configuration. Tous les objets sont toujours disponibles.';

  @override
  String get townTrainingIntro =>
      'Apprends des techniques permanentes pour le personnage de ton choix.';

  @override
  String get townAllCategories => 'Toutes les catégories';

  @override
  String get townUnownedOnly => 'À débloquer';

  @override
  String townBuyAmount({required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return 'Acheter $goldString';
  }

  @override
  String townBuyGoldLabel({required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return 'Acheter pour $goldString pièces d’or';
  }

  @override
  String townLearnAmount({required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return 'Apprendre $goldString';
  }

  @override
  String townLearnGoldLabel({required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return 'Apprendre pour $goldString pièces d’or';
  }

  @override
  String get pickerEquipped => 'Équipé';

  @override
  String get townOwned => 'Possédé';

  @override
  String get townLearned => 'Apprise';

  @override
  String get townLearn => 'Apprendre';

  @override
  String get townCatalogueUnavailable =>
      'Le catalogue est indisponible. Retourne en ville et reconnecte-toi pour le charger.';

  @override
  String get townNoMatchingEntries =>
      'Aucune entrée ne correspond à ces filtres.';

  @override
  String townCategory({
    required String character,
    required String service,
    required String slot,
  }) {
    String _temp0 = intl.Intl.selectLogic(character, {
      'bountyHunter': 'Kits de bombes',
      'other': 'Boucliers',
    });
    String _temp1 = intl.Intl.selectLogic(character, {
      'bountyHunter': 'Kits de terrain',
      'other': 'Grimoires',
    });
    String _temp2 = intl.Intl.selectLogic(character, {
      'bountyHunter': 'Armes à distance',
      'other': 'Sorts à distance',
    });
    String _temp3 = intl.Intl.selectLogic(service, {
      'training': 'Techniques à distance',
      'other': '$_temp2',
    });
    String _temp4 = intl.Intl.selectLogic(character, {
      'bountyHunter': 'Techniques de terrain',
      'other': 'Sorts',
    });
    String _temp5 = intl.Intl.selectLogic(slot, {
      'mainWeapon': 'Armes',
      'offhandWeapon': '$_temp0',
      'spellBook': '$_temp1',
      'accessory': 'Accessoires',
      'primary': 'Principale',
      'secondary': 'Secondaire',
      'projectile': '$_temp3',
      'mobility': 'Mobilité',
      'jump': 'Saut',
      'spell': '$_temp4',
      'other': 'Équipement',
    });
    return '$_temp5';
  }

  @override
  String get runMissionCompleted => 'Mission accomplie';

  @override
  String get runMissionFailed => 'Mission échouée';

  @override
  String get campaignHeading => 'Campagne';

  @override
  String get campaignRegionalMap => 'Carte régionale';

  @override
  String get campaignChapterReward => 'Récompenses de fin de chapitre';

  @override
  String campaignFirstClearXp({required int xp}) {
    return 'Première réussite : $xp EXP';
  }

  @override
  String get campaignDoubleJumpReward => 'Débloque le double saut';

  @override
  String get campaignCollectedGold =>
      'Conserve l’or collecté à chaque tentative validée';

  @override
  String campaignBestScore({required int score}) {
    return 'Meilleur score : $score';
  }

  @override
  String get campaignLocked => 'Verrouillé';

  @override
  String get campaignComingSoon => 'À venir';

  @override
  String get campaignWillowLocked =>
      'Termine le chapitre de l’Avant-poste du Val pour débloquer Willow';

  @override
  String get campaignVerificationPending =>
      'Ta réussite et les récompenses de première réussite sont accordées après validation.';

  @override
  String get campaignNextMission => 'Mission suivante';

  @override
  String campaignObjectives({required int completed, required int required}) {
    return 'Objectifs : $completed/$required';
  }

  @override
  String get campaignReachExit => 'Rejoins la sortie';

  @override
  String get campaignEquipDoubleJump => 'Équipe le double saut pour Éloïse';

  @override
  String get campaignDoubleJumpEquipped => 'Double saut équipé';

  @override
  String get campaignEquipFailed =>
      'Impossible d’équiper le double saut. Réessaie.';

  @override
  String get campaignWillowUnlocked => 'Chapitre terminé — Willow débloqué';

  @override
  String campaignChapterRewardAmounts({required int xp, required int gold}) {
    return '$xp EXP · $gold pièces d’or';
  }

  @override
  String get campaignChapterRewardsGranted => 'Récompenses du chapitre reçues.';

  @override
  String campaignCollectCoin({required int collected}) {
    return 'Ramasse une pièce $collected/1';
  }

  @override
  String get codexCombatAdvice => 'Conseil de combat';

  @override
  String get codexInnateDefences => 'Défenses innées';

  @override
  String get codexBoss => 'Boss';

  @override
  String get codexNoInnateModifiers => 'Aucune';

  @override
  String codexAttackDetails({required String category, required String types}) {
    return '$category · Dégâts : $types';
  }

  @override
  String get codexGrojibRole => 'Poursuivant terrestre';

  @override
  String get codexGrojibAdvice =>
      'Garde de la place pour éviter ce deuxième coup.';

  @override
  String get codexHashashRole => 'Assassin téléporteur';

  @override
  String get codexHashashAdvice => 'Surveille son retour avant de t’engager.';

  @override
  String get codexDerfRole => 'Lanceur de sorts métamorphe';

  @override
  String get codexDerfAdvice =>
      'Garde tes distances avec son tentacule allongé.';

  @override
  String get codexUnocoRole => 'Lanceur de sorts volant';

  @override
  String get codexUnocoAdvice =>
      'Reste en mouvement pendant qu’il vise son projectile.';

  @override
  String get codexBringerRole => 'Combattant à la faux';

  @override
  String get codexBringerAdvice =>
      'Observe sa préparation et quitte les zones marquées au sol.';

  @override
  String get codexGoddessRole => 'Combattante aux griffes et aux orbes';

  @override
  String get codexGoddessAdvice =>
      'Repositionne-toi quand l’arène devient dangereuse.';

  @override
  String get codexShoggothRole => 'Invocateur à tentacules';

  @override
  String get codexShoggothAdvice =>
      'Gère les petites menaces tout en surveillant le boss.';

  @override
  String get codexVoidcallerRole => 'Lanceur de rayons';

  @override
  String get codexVoidcallerAdvice =>
      'Garde une issue lorsque les attaques se chevauchent.';

  @override
  String get codexShoggothMinionRole => 'Attaquant terrestre invoqué';

  @override
  String get codexShoggothMinionAdvice =>
      'Évite de te laisser encercler pendant les attaques du boss.';

  @override
  String get codexVoidTentacleRole => 'Attaquant de mêlée invoqué';

  @override
  String get hubRunnerHeading => 'Runner';

  @override
  String get hubRunnerPlay => 'Jouer au Runner';

  @override
  String get hubCampaignPlay => 'Jouer la campagne';

  @override
  String get hubChangeBuild => 'Changer de configuration';

  @override
  String get hubLocalPractice => 'Entraînement local';

  @override
  String get hubWeeklyPlay => 'Jouer';

  @override
  String get codexVoidTentacleAdvice =>
      'Sors de portée de son fouet avant de te retourner pour l’attaquer.';

  @override
  String campaignReceiveBlessing({required int received}) {
    return 'Recevoir une bénédiction $received/1';
  }

  @override
  String get journalEmpty => 'Aucune entrée dans le journal pour le moment.';
}
