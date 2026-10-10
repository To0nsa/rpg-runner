/// Releases the event loop without changing the order of speculative work.
/// Browser message events avoid the nested-timer delay imposed on setTimeout.
library;

export 'cooperative_work_yield_native.dart'
    if (dart.library.js_interop) 'cooperative_work_yield_web.dart';
