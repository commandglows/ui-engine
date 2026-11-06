import 'package:flutter/foundation.dart';
import 'package:shipglows_sync_core/shipglows_sync_core.dart';

/// Lets Flutter listen to a [SyncObservable] from the pure core.
extension SyncObservableListenable on SyncObservable {
  Listenable get asListenable {
    final self = this;
    return self is Listenable ? self : _ObservableListenable(self);
  }
}

class _ObservableListenable implements Listenable {
  const _ObservableListenable(this.source);

  final SyncObservable source;

  @override
  void addListener(VoidCallback listener) => source.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => source.removeListener(listener);

  @override
  bool operator ==(Object other) =>
      other is _ObservableListenable && identical(other.source, source);

  @override
  int get hashCode => identityHashCode(source);
}
