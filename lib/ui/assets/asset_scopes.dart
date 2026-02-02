/// Asset lifetimes scoped to UI usage.
enum AssetScope {
  /// Menu/hub previews that can persist between routes.
  hub,

  /// Run-specific assets that should be purged on exit.
  run,
}
