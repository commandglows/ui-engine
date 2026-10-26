import 'dart:async';

import 'notification_item.dart';

/// Where the notifications live: a backend table, a local database, memory.
/// The app plugs its own in; the center never stores anything itself.
abstract interface class NotificationStore {
  /// The latest notifications, newest first, again on every change. An
  /// error event shows the error state; the stream may go on after it.
  Stream<List<NotificationItem>> watch();

  /// Loads again after an error (a backend query invalidated). The new list
  /// comes through [watch].
  Future<void> refresh();

  Future<void> markRead(String id);

  /// Marks read every notification in [ids] (the unread ones shown); a
  /// backend may as well mark all of the account's.
  Future<void> markAllRead(List<String> ids);

  /// Whether [delete] works: the center hides the delete buttons otherwise.
  bool get canDelete;

  Future<void> delete(String id);

  /// Whether [deleteAll] works: « Delete all » is hidden otherwise.
  bool get canDeleteAll;

  /// Deletes every notification in [ids] (the ones shown, never one that
  /// arrived after the confirmation).
  Future<void> deleteAll(List<String> ids);

  /// Whether older notifications are left to load: the list then ends with
  /// a loader that calls [loadMore] once it scrolls into view.
  bool get hasMore;

  /// Loads the next older page. The longer list comes through [watch].
  Future<void> loadMore();
}

/// Plugs an existing client in (a backend subscription, a provider) without
/// a dependency in this package. Without [delete] the delete buttons are
/// hidden; without [deleteAll], « Delete all » deletes one by one through
/// [delete]. With [hasMore] and [loadMore], the list loads older pages as
/// it scrolls.
class CallbackNotificationStore implements NotificationStore {
  const CallbackNotificationStore({
    required Stream<List<NotificationItem>> Function() watch,
    required Future<void> Function(String id) markRead,
    required Future<void> Function(List<String> ids) markAllRead,
    Future<void> Function()? refresh,
    Future<void> Function(String id)? delete,
    Future<void> Function(List<String> ids)? deleteAll,
    bool Function()? hasMore,
    Future<void> Function()? loadMore,
  }) : _watch = watch,
       _markRead = markRead,
       _markAllRead = markAllRead,
       _refresh = refresh,
       _delete = delete,
       _deleteAll = deleteAll,
       _hasMore = hasMore,
       _loadMore = loadMore;

  final Stream<List<NotificationItem>> Function() _watch;
  final Future<void> Function(String id) _markRead;
  final Future<void> Function(List<String> ids) _markAllRead;
  final Future<void> Function()? _refresh;
  final Future<void> Function(String id)? _delete;
  final Future<void> Function(List<String> ids)? _deleteAll;
  final bool Function()? _hasMore;
  final Future<void> Function()? _loadMore;

  @override
  Stream<List<NotificationItem>> watch() => _watch();

  @override
  Future<void> refresh() async => _refresh?.call();

  @override
  Future<void> markRead(String id) => _markRead(id);

  @override
  Future<void> markAllRead(List<String> ids) => _markAllRead(ids);

  @override
  bool get canDelete => _delete != null;

  @override
  Future<void> delete(String id) {
    final delete = _delete;
    if (delete == null) throw UnsupportedError('delete');
    return delete(id);
  }

  @override
  bool get canDeleteAll => _deleteAll != null || _delete != null;

  @override
  Future<void> deleteAll(List<String> ids) async {
    final deleteAll = _deleteAll;
    if (deleteAll != null) return deleteAll(ids);
    final delete = _delete;
    if (delete == null) throw UnsupportedError('deleteAll');
    for (final id in ids) {
      await delete(id);
    }
  }

  @override
  bool get hasMore => _loadMore != null && (_hasMore?.call() ?? false);

  @override
  Future<void> loadMore() async => _loadMore?.call();
}

/// In memory only: tests, previews, demo mode, a device-only log. Newest
/// first, at most [capacity] kept (the oldest dropped).
class MemoryNotificationStore implements NotificationStore {
  MemoryNotificationStore({
    Iterable<NotificationItem> initial = const [],
    this.capacity = 50,
  }) : _items = [...initial] {
    _sortAndTrim();
  }

  final int capacity;
  final List<NotificationItem> _items;
  final StreamController<List<NotificationItem>> _changes =
      StreamController.broadcast();

  /// Set to make every action fail, as when offline.
  Object? failWith;

  List<NotificationItem> get items => List.unmodifiable(_items);

  /// Adds [item], or replaces the one with its id.
  void add(NotificationItem item) {
    _items
      ..removeWhere((it) => it.id == item.id)
      ..add(item);
    _sortAndTrim();
    _emit();
  }

  void _sortAndTrim() {
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_items.length > capacity) _items.removeRange(capacity, _items.length);
  }

  void _emit() => _changes.add(items);

  void _check() {
    if (failWith case final error?) throw error;
  }

  @override
  Stream<List<NotificationItem>> watch() async* {
    yield items;
    yield* _changes.stream;
  }

  @override
  Future<void> refresh() async => _emit();

  @override
  Future<void> markRead(String id) async {
    _check();
    final index = _items.indexWhere((it) => it.id == id);
    if (index < 0 || _items[index].read) return;
    _items[index] = _items[index].copyWith(read: true);
    _emit();
  }

  @override
  Future<void> markAllRead(List<String> ids) async {
    _check();
    final wanted = ids.toSet();
    for (var i = 0; i < _items.length; i++) {
      if (wanted.contains(_items[i].id)) {
        _items[i] = _items[i].copyWith(read: true);
      }
    }
    _emit();
  }

  @override
  bool get canDelete => true;

  @override
  Future<void> delete(String id) async {
    _check();
    _items.removeWhere((it) => it.id == id);
    _emit();
  }

  @override
  bool get canDeleteAll => true;

  @override
  Future<void> deleteAll(List<String> ids) async {
    _check();
    final wanted = ids.toSet();
    _items.removeWhere((it) => wanted.contains(it.id));
    _emit();
  }

  /// Everything is in memory: nothing more to load.
  @override
  bool get hasMore => false;

  @override
  Future<void> loadMore() async {}

  /// Closes the change stream; the store is not used after.
  Future<void> close() => _changes.close();
}
