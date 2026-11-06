/// Something that tells its listeners when it changes.
///
/// Same shape as Flutter's `Listenable`, so a `ChangeNotifier` that implements
/// a host below satisfies it as is. `shipglows_sync` adapts it for widgets.
abstract interface class SyncObservable {
  void addListener(void Function() listener);
  void removeListener(void Function() listener);
}
