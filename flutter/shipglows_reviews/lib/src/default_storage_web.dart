import 'dart:convert';

import 'package:shipglows_settings/shipglows_settings.dart';
import 'package:web/web.dart' as web;

/// The browser's `localStorage`, one `shipglows.<bucket>` key per bucket.
Future<SettingsStorage> defaultReviewStorage() async =>
    const LocalStorageReviewStorage();

/// A bucket per `localStorage` key: survives reloads, stays on this browser
/// and this origin. A private window or a full storage loses the state; the
/// reviews then start afresh, never fail.
class LocalStorageReviewStorage implements SettingsStorage {
  const LocalStorageReviewStorage({this.prefix = 'shipglows.'});

  final String prefix;

  @override
  Future<Map<String, Object?>?> read(String bucket) async {
    final text = web.window.localStorage.getItem('$prefix$bucket');
    if (text == null || text.trim().isEmpty) return null;
    final data = jsonDecode(text);
    return data is Map ? data.cast<String, Object?>() : null;
  }

  @override
  Future<void> write(String bucket, Map<String, Object?> data) async =>
      web.window.localStorage.setItem('$prefix$bucket', jsonEncode(data));

  @override
  Future<void> delete(String bucket) async =>
      web.window.localStorage.removeItem('$prefix$bucket');
}
