// window_manager stays on 0.5: from 0.6 it calls the window through synchronous
// FFI. A resize from Dart then runs Flutter's message pump, which re-enters
// Dart and crashes the app in `Dart_InvokeClosure` (seen on Windows when a
// maximized window is restored, Flutter 3.47).

export 'package:screen_retriever/screen_retriever.dart'
    show Display, screenRetriever;
export 'package:window_manager/window_manager.dart'
    show
        DragToMoveArea,
        DragToResizeArea,
        ResizeEdge,
        TitleBarStyle,
        WindowListener,
        windowManager;
