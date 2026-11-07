import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_undo_trash/shipglows_undo_trash.dart';

class _Target extends ChangeNotifier implements UndoTarget {
  @override
  bool get canUndo => false;
  @override
  bool get canRedo => false;
  @override
  void undo() {}
  @override
  void redo() {}
}

void main() {
  test('release after dispose does nothing', () {
    final registry = UndoRegistry();
    final target = _Target();
    addTearDown(target.dispose);
    registry.activate(target);
    registry.dispose();

    expect(() => registry.release(target), returnsNormally);
  });
}
