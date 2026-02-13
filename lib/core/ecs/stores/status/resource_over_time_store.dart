import '../../../combat/status/status.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class ResourceOverTimeDef {
  const ResourceOverTimeDef({
    required this.resourceType,
    required this.ticksLeft,
    required this.periodTicks,
    required this.amountBp,
  }) : periodTicksLeft = periodTicks;

  final StatusResourceType resourceType;
  final int ticksLeft;
  final int periodTicks;
  final int periodTicksLeft;

  /// Basis points restored per pulse (`100 = 1%` of max resource).
  final int amountBp;
}

/// Active periodic resource restoration keyed by target entity.
///
/// A target can host multiple channels at once as long as they use different
/// resource types (health/mana/stamina).
class ResourceOverTimeStore extends SparseSet {
  final List<List<StatusResourceType>> resourceTypes =
      <List<StatusResourceType>>[];
  final List<List<int>> ticksLeft = <List<int>>[];
  final List<List<int>> periodTicks = <List<int>>[];
  final List<List<int>> periodTicksLeft = <List<int>>[];
  final List<List<int>> amountBp = <List<int>>[];

  void add(EntityId entity, ResourceOverTimeDef def) {
    final entityIndex = addEntity(entity);
    final channelIndex = _channelIndexFor(entityIndex, def.resourceType);
    if (channelIndex == null) {
      _addChannel(entityIndex, def);
      return;
    }
    _setChannel(entityIndex, channelIndex, def);
  }

  int? channelIndexFor(EntityId entity, StatusResourceType resourceType) {
    final entityIndex = tryIndexOf(entity);
    if (entityIndex == null) return null;
    return _channelIndexFor(entityIndex, resourceType);
  }

  int? channelIndexForEntityIndex(int entityIndex, StatusResourceType resourceType) {
    return _channelIndexFor(entityIndex, resourceType);
  }

  void addChannel(EntityId entity, ResourceOverTimeDef def) {
    final entityIndex = addEntity(entity);
    _addChannel(entityIndex, def);
  }

  void setChannel(EntityId entity, int channelIndex, ResourceOverTimeDef def) {
    final entityIndex = indexOf(entity);
    _setChannel(entityIndex, channelIndex, def);
  }

  void removeChannelAtEntityIndex(int entityIndex, int channelIndex) {
    _removeChannelAt(entityIndex, channelIndex);
  }

  bool hasNoChannelsEntityIndex(int entityIndex) {
    return resourceTypes[entityIndex].isEmpty;
  }

  int? _channelIndexFor(int entityIndex, StatusResourceType resourceType) {
    final channels = resourceTypes[entityIndex];
    for (var i = 0; i < channels.length; i += 1) {
      if (channels[i] == resourceType) return i;
    }
    return null;
  }

  void _addChannel(int entityIndex, ResourceOverTimeDef def) {
    resourceTypes[entityIndex].add(def.resourceType);
    ticksLeft[entityIndex].add(def.ticksLeft);
    periodTicks[entityIndex].add(def.periodTicks);
    periodTicksLeft[entityIndex].add(def.periodTicksLeft);
    amountBp[entityIndex].add(def.amountBp);
  }

  void _setChannel(int entityIndex, int channelIndex, ResourceOverTimeDef def) {
    resourceTypes[entityIndex][channelIndex] = def.resourceType;
    ticksLeft[entityIndex][channelIndex] = def.ticksLeft;
    periodTicks[entityIndex][channelIndex] = def.periodTicks;
    periodTicksLeft[entityIndex][channelIndex] = def.periodTicksLeft;
    amountBp[entityIndex][channelIndex] = def.amountBp;
  }

  void _removeChannelAt(int entityIndex, int channelIndex) {
    resourceTypes[entityIndex].removeAt(channelIndex);
    ticksLeft[entityIndex].removeAt(channelIndex);
    periodTicks[entityIndex].removeAt(channelIndex);
    periodTicksLeft[entityIndex].removeAt(channelIndex);
    amountBp[entityIndex].removeAt(channelIndex);
  }

  @override
  void onDenseAdded(int denseIndex) {
    resourceTypes.add(<StatusResourceType>[]);
    ticksLeft.add(<int>[]);
    periodTicks.add(<int>[]);
    periodTicksLeft.add(<int>[]);
    amountBp.add(<int>[]);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    resourceTypes[removeIndex] = resourceTypes[lastIndex];
    ticksLeft[removeIndex] = ticksLeft[lastIndex];
    periodTicks[removeIndex] = periodTicks[lastIndex];
    periodTicksLeft[removeIndex] = periodTicksLeft[lastIndex];
    amountBp[removeIndex] = amountBp[lastIndex];

    resourceTypes.removeLast();
    ticksLeft.removeLast();
    periodTicks.removeLast();
    periodTicksLeft.removeLast();
    amountBp.removeLast();
  }
}

