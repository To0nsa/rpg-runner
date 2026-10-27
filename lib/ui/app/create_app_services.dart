/// Selects the standalone host's services without importing native clients on web.
library;

export 'practice_app_services.dart'
    if (dart.library.io) 'firebase_app_services.dart'
    show createAppServices;
