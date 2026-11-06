// Web stand-ins for the window_manager / screen_retriever surface used by this
// package. A browser tab has no native window: every call is a no-op and the
// drag areas only render their child. `ShipglowsWindow.isSupported` keeps the
// custom chrome off the web, so these are never reached in practice.
import 'package:flutter/widgets.dart';

enum TitleBarStyle { normal, hidden }

enum ResizeEdge {
  top,
  left,
  right,
  bottom,
  topLeft,
  bottomLeft,
  topRight,
  bottomRight,
}

mixin WindowListener {
  void onWindowMaximize() {}
  void onWindowUnmaximize() {}
  void onWindowRestore() {}
  void onWindowEnterFullScreen() {}
  void onWindowLeaveFullScreen() {}
  void onWindowMoved() {}
  void onWindowResized() {}
}

final WindowManagerStub windowManager = WindowManagerStub._();

class WindowManagerStub {
  WindowManagerStub._();

  void addListener(WindowListener listener) {}
  void removeListener(WindowListener listener) {}
  Future<void> ensureInitialized() async {}
  Future<void> setTitleBarStyle(
    TitleBarStyle style, {
    bool windowButtonVisibility = true,
  }) async {}
  Future<void> setMinimumSize(Size size) async {}
  Future<int> getId() async => 0;
  Future<void> setAsFrameless() async {}
  Future<void> setBackgroundColor(Color color) async {}
  Future<bool> isMaximized() async => false;
  Future<bool> isMinimized() async => false;
  Future<bool> isFullScreen() async => false;
  Future<void> minimize() async {}
  Future<void> maximize() async {}
  Future<void> unmaximize() async {}
  Future<void> close() async {}
  Future<void> startDragging() async {}
  Future<void> startResizing(ResizeEdge edge) async {}
  Future<void> setBounds(Rect bounds) async {}
  Future<Rect> getBounds() async => Rect.zero;
}

class Display {
  const Display({required this.size, this.visiblePosition, this.visibleSize});

  final Size size;
  final Offset? visiblePosition;
  final Size? visibleSize;
}

final ScreenRetrieverStub screenRetriever = ScreenRetrieverStub._();

class ScreenRetrieverStub {
  ScreenRetrieverStub._();

  Future<List<Display>> getAllDisplays() async => const [];
}

class DragToMoveArea extends StatelessWidget {
  const DragToMoveArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class DragToResizeArea extends StatelessWidget {
  const DragToResizeArea({
    super.key,
    required this.child,
    this.resizeEdgeSize = 8,
  });

  final Widget child;
  final double resizeEdgeSize;

  @override
  Widget build(BuildContext context) => child;
}
