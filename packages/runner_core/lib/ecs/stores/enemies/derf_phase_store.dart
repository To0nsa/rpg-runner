import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Derf's one-way awakening lifecycle; death remains in DeathStateStore.
enum DerfPhase { caster, transforming, twisted }

/// Retains the first visibility tick independently of hit and stun reactions.
class DerfPhaseStore extends SparseSet {
  final List<DerfPhase> phase = [];
  final List<int> transformationStartTick = [];

  void add(EntityId entity) {
    final i = addEntity(entity);
    phase[i] = DerfPhase.caster;
    transformationStartTick[i] = -1;
  }

  @override
  void onDenseAdded(int denseIndex) {
    phase.add(DerfPhase.caster);
    transformationStartTick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    phase[removeIndex] = phase[lastIndex];
    transformationStartTick[removeIndex] = transformationStartTick[lastIndex];
    phase.removeLast();
    transformationStartTick.removeLast();
  }
}
