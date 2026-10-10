/// Defers continuation to the event queue, allowing other tasks to run.
Future<void> yieldCooperativeWork() => Future<void>.delayed(Duration.zero);
