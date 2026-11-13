import '../../entity_id.dart';
import '../../sparse_set.dart';
import '../../../snapshots/enums.dart';

/// Ordinary campaign markers retain their actor and home across disengagement.
enum CampaignEnemyPhase { waiting, engaged, returning }

final class CampaignEnemyStore extends SparseSet {
  final List<double> homeX = [], homeY = [];
  final List<Facing> homeFacing = [];
  final List<bool> returnWhenPlayerRetreats = [];
  final List<CampaignEnemyPhase> phase = [];
  final List<int> provokedUntilTick = [];

  void add(
    EntityId entity, {
    required double x,
    required double y,
    required Facing facing,
    required bool returns,
  }) {
    final i = addEntity(entity);
    homeX[i] = x;
    homeY[i] = y;
    homeFacing[i] = facing;
    returnWhenPlayerRetreats[i] = returns;
    phase[i] = CampaignEnemyPhase.waiting;
    provokedUntilTick[i] = -1;
  }

  bool canFight(EntityId actor) {
    final i = tryIndexOf(actor);
    return i == null || phase[i] == CampaignEnemyPhase.engaged;
  }

  bool isReturning(EntityId actor) {
    final i = tryIndexOf(actor);
    return i != null && phase[i] == CampaignEnemyPhase.returning;
  }

  @override
  void onDenseAdded(int denseIndex) {
    homeX.add(0);
    homeY.add(0);
    homeFacing.add(Facing.left);
    returnWhenPlayerRetreats.add(true);
    phase.add(CampaignEnemyPhase.waiting);
    provokedUntilTick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    homeX[removeIndex] = homeX[lastIndex];
    homeY[removeIndex] = homeY[lastIndex];
    homeFacing[removeIndex] = homeFacing[lastIndex];
    returnWhenPlayerRetreats[removeIndex] = returnWhenPlayerRetreats[lastIndex];
    phase[removeIndex] = phase[lastIndex];
    provokedUntilTick[removeIndex] = provokedUntilTick[lastIndex];
    homeX.removeLast();
    homeY.removeLast();
    homeFacing.removeLast();
    returnWhenPlayerRetreats.removeLast();
    phase.removeLast();
    provokedUntilTick.removeLast();
  }
}
