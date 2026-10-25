import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'store_file_stub.dart' if (dart.library.io) 'store_file_io.dart';
import 'tray_config.dart';

/// Something the app opened (a document, a project, a song…), listed under
/// « Récent » in the Jump List of its taskbar button. Windows lets the user
/// pin it (« Épinglé ») or remove it there.
///
/// Choosing it starts the app with [ShipglowsJumpList.argumentFor] [id]:
/// read it with [ShipglowsJumpList.itemIdFrom] from `main`'s arguments, or
/// from `ShipglowsTraySecondInstance.openedItemId` while the app runs.
@immutable
class ShipglowsJumpListItem {
  const ShipglowsJumpListItem(
    this.id,
    this.title, {
    this.description,
    this.icon,
  });

  /// Stable id the app finds the item back with. A pinned item keeps it
  /// after the item is gone from the app: handle unknown ids.
  final String id;

  final String title;

  /// Tooltip, for example the item's path.
  final String? description;

  /// The executable's icon when null.
  final ShipglowsTrayImage? icon;

  static ShipglowsJumpListItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final title = json['title'];
    if (id is! String || id.isEmpty || title is! String) return null;
    final description = json['description'];
    return ShipglowsJumpListItem(
      id,
      title,
      description: description is String ? description : null,
      icon: _imageFrom(json['icon']),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    if (description != null) 'description': description,
    if (icon != null) 'icon': icon!.toMap(),
  };

  Map<String, Object?> _toNative() => {
    'title': title,
    'description': description,
    'arguments': [ShipglowsJumpList.argumentFor(id)],
    'icon': icon?.toMap(),
  };

  @override
  bool operator ==(Object other) =>
      other is ShipglowsJumpListItem &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      mapEquals(other.icon?.toMap(), icon?.toMap());

  @override
  int get hashCode => Object.hash(id, title, description);
}

/// A fixed action of the Jump List (« Tâches »): the app started with
/// [arguments], for example `['--capture=image']`.
@immutable
class ShipglowsJumpListTask {
  const ShipglowsJumpListTask(
    this.title,
    this.arguments, {
    this.description,
    this.icon,
  });

  final String title;
  final List<String> arguments;
  final String? description;
  final ShipglowsTrayImage? icon;

  Map<String, Object?> _toNative() => {
    'title': title,
    'description': description,
    'arguments': arguments,
    'icon': icon?.toMap(),
  };
}

/// The Jump List of the app's taskbar button (right click on it): recent
/// items Windows lets the user pin, and fixed tasks.
///
/// Windows only; elsewhere every call does nothing.
class ShipglowsJumpList {
  ShipglowsJumpList._();

  static final instance = ShipglowsJumpList._();

  static const _channel = MethodChannel('shipglows_tray');
  static const _openSwitch = '--shipglows-open=';

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// The command line argument that opens the item [id].
  static String argumentFor(String id) => '$_openSwitch$id';

  /// The item a launch from the Jump List asks to open, or null. The
  /// arguments come from any local process: look the id up before acting.
  static String? itemIdFrom(List<String> arguments) {
    if (arguments.length != 1) return null;
    final argument = arguments.single;
    if (!argument.startsWith(_openSwitch)) return null;
    final id = argument.substring(_openSwitch.length);
    return id.isEmpty ? null : id;
  }

  /// Replaces the whole list: [recent] most recent first (Windows shows as
  /// many as its setting allows, 10 by default), then [tasks]. Pinned items
  /// stay; Windows keeps them.
  ///
  /// [recentTitle] defaults to « Récent » (« Recent » outside French).
  /// [appUserModelId] is needed when the runner gives the taskbar button an
  /// explicit one (`SetCurrentProcessExplicitAppUserModelID`) from another
  /// process; the process's own is used otherwise.
  ///
  /// Returns the ids of the items the user removed from the list since the
  /// last update: they are left out, and the app should forget them.
  Future<Set<String>> update({
    List<ShipglowsJumpListItem> recent = const [],
    List<ShipglowsJumpListTask> tasks = const [],
    String? recentTitle,
    String? appUserModelId,
  }) async {
    if (!isSupported) return const {};
    try {
      final result = await _channel
          .invokeMapMethod<Object?, Object?>('jumpList', {
            'recent': [for (final item in recent) item._toNative()],
            'tasks': [for (final task in tasks) task._toNative()],
            'recentTitle': recentTitle ?? '',
            'appUserModelId': appUserModelId ?? '',
          });
      final removed = result?['removed'];
      return {
        if (removed is List)
          for (final arguments in removed)
            if (arguments is List)
              if (itemIdFrom([for (final a in arguments) '$a']) case final id?)
                id,
      };
    } on MissingPluginException {
      return const {};
    }
  }

  /// Empties the list; pinned items stay.
  Future<void> clear({String? appUserModelId}) =>
      update(appUserModelId: appUserModelId);
}

/// The app's recently opened items, kept in
/// `%APPDATA%\<appFolder>\jump_list.json` and shown in its Jump List.
///
/// ```dart
/// final recents = ShipglowsJumpListRecents(appFolder: 'BeatGlows');
/// await recents.load();
/// // Each time a song opens:
/// await recents.opened(ShipglowsJumpListItem(song.id, song.title));
/// ```
class ShipglowsJumpListRecents {
  ShipglowsJumpListRecents({
    this.appFolder,
    this.maxItems = 10,
    this.tasks = const [],
    this.recentTitle,
    this.appUserModelId,
  });

  /// Folder under `%APPDATA%`; kept for the session only when null.
  final String? appFolder;
  final int maxItems;
  final List<ShipglowsJumpListTask> tasks;
  final String? recentTitle;
  final String? appUserModelId;

  static const _fileName = 'jump_list.json';

  final _items = ValueNotifier<List<ShipglowsJumpListItem>>(const []);
  Future<void> _queue = Future.value();

  /// Most recent first, for an in-app « Récents » menu.
  ValueListenable<List<ShipglowsJumpListItem>> get items => _items;

  /// Reads the saved items and shows them in the Jump List.
  Future<void> load() => _run(() async {
    final folder = appFolder;
    if (folder != null) {
      final document = await readTrayDocument(folder, fileName: _fileName);
      final saved = document is Map ? document['recent'] : null;
      if (saved is List) {
        _items.value = [
          for (final json in saved)
            if (ShipglowsJumpListItem.fromJson(json) case final item?) item,
        ].take(maxItems).toList();
      }
    }
    await _publish(save: false);
  });

  /// Puts [item] first, for example each time it is opened.
  Future<void> opened(ShipglowsJumpListItem item) => _run(() async {
    _items.value = [
      item,
      ..._items.value.where((other) => other.id != item.id),
    ].take(maxItems).toList();
    await _publish();
  });

  /// Forgets [id], for example once the item is deleted. A pin stays.
  Future<void> remove(String id) => _run(() async {
    _items.value = [
      for (final item in _items.value)
        if (item.id != id) item,
    ];
    await _publish();
  });

  Future<void> clear() => _run(() async {
    _items.value = const [];
    await _publish();
  });

  Future<void> _run(Future<void> Function() step) =>
      _queue = _queue.then((_) => step()).catchError((Object error) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            library: 'shipglows_tray',
            context: ErrorDescription('while updating the Jump List'),
          ),
        );
      });

  Future<void> _publish({bool save = true}) async {
    final removed = await ShipglowsJumpList.instance.update(
      recent: _items.value,
      tasks: tasks,
      recentTitle: recentTitle,
      appUserModelId: appUserModelId,
    );
    if (removed.isNotEmpty) {
      _items.value = [
        for (final item in _items.value)
          if (!removed.contains(item.id)) item,
      ];
      save = true;
    }
    final folder = appFolder;
    if (!save || folder == null) return;
    await writeTrayDocument(folder, {
      'version': 1,
      'recent': [for (final item in _items.value) item.toJson()],
    }, fileName: _fileName);
  }
}

ShipglowsTrayImage? _imageFrom(Object? map) {
  if (map is! Map) return null;
  final path = map['path'];
  return switch (map['kind']) {
    'app' => ShipglowsTrayImage.app,
    'asset' when path is String => ShipglowsTrayImage.asset(path),
    'file' when path is String => ShipglowsTrayImage.file(path),
    _ => null,
  };
}
