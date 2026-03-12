/// Opaque identifier for entities in the Core simulation.
///
/// An [EntityId] is a simple integer that uniquely identifies an entity within
/// the [EcsWorld]. It serves as a key to access components associated with
/// the entity across different [SparseSet] stores.
///
/// Entity IDs are managed by the [EcsWorld]. When an entity is destroyed, its
/// ID is recycled and may be assigned to a new entity in the future to keep the
/// range of active IDs compact, which benefits the performance of sparse sets.
typedef EntityId = int;
