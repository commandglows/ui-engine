// window_manager is desktop only, so the package reaches it only on targets
// with `dart:ffi`; the web gets inert stand-ins with the same surface.
export 'window_backend_stub.dart'
    if (dart.library.ffi) 'window_backend_native.dart';
