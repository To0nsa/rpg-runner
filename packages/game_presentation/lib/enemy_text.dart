import 'package:runner_core/enemies/enemy_id.dart';

import 'game_localization.dart';

/// Player-facing enemy names are independent of Core diagnostic labels.
String enemyDisplayName(EnemyId id, {required GameLocalizations strings}) =>
    switch (id) {
      EnemyId.unocoDemon => strings.enemyUnocoDemonName,
      EnemyId.grojib => strings.enemyGrojibName,
      EnemyId.hashash => strings.enemyHashashName,
      EnemyId.derf => strings.enemyDerfName,
      EnemyId.bringerOfDeath => strings.enemyBringerOfDeathName,
      EnemyId.voidbornGoddess => strings.enemyVoidbornGoddessName,
      EnemyId.shoggoth => strings.enemyShoggothName,
      EnemyId.voidcaller => strings.enemyVoidcallerName,
      EnemyId.shoggothMinion => strings.enemyShoggothMinionName,
      EnemyId.voidTentacle => strings.enemyVoidTentacleName,
    };
