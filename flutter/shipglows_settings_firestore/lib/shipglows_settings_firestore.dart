/// Firestore remote for `shipglows_settings`: one document per account
/// (`users/{uid}/settings/profile`), one field per setting, merged writes and
/// a server `updatedAt`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shipglows_settings/shipglows_settings.dart';

class FirestoreSettingsRemote implements SettingsRemote {
  FirestoreSettingsRemote(this.document, {this.decorate});

  /// The account's settings document.
  final DocumentReference<Map<String, dynamic>> document;

  /// Adds derived fields to a push (`retentionHours` next to
  /// `retentionPolicy` for the security rules).
  final Map<String, Object?> Function(Map<String, Object?> changes)? decorate;

  static const updatedAtField = 'updatedAt';

  @override
  Future<RemoteSettings?> fetch() async {
    try {
      return _read(await document.get());
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<RemoteSettings?> push(Map<String, Object?> changes) async {
    final data = <String, Object?>{
      for (final entry in changes.entries)
        entry.key: entry.value ?? FieldValue.delete(),
      ...?decorate?.call(changes),
      updatedAtField: FieldValue.serverTimestamp(),
    };
    try {
      await document.set(data, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
    // The watch stream brings the server copy back.
    return null;
  }

  @override
  Stream<RemoteSettings?>? watch() => document
      .snapshots()
      // Local echoes carry no server time yet and would only repeat our push.
      .where((snapshot) => !snapshot.metadata.hasPendingWrites)
      .map(_read);

  static RemoteSettings? _read(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    final updatedAt = _date(data[updatedAtField]);
    return RemoteSettings(
      values: {
        for (final entry in data.entries)
          if (entry.key != updatedAtField) entry.key: _plain(entry.value),
      },
      updatedAt: updatedAt,
      revision: updatedAt?.microsecondsSinceEpoch.toString(),
    );
  }

  /// Timestamps become ISO text, as `SettingCodec.dateTime` stores them.
  static Object? _plain(Object? value) => switch (value) {
    final Timestamp timestamp => timestamp.toDate().toUtc().toIso8601String(),
    final List<Object?> list => list.map(_plain).toList(),
    final Map<Object?, Object?> map => {
      for (final entry in map.entries) '${entry.key}': _plain(entry.value),
    },
    _ => value,
  };

  static DateTime? _date(Object? value) => switch (value) {
    final Timestamp timestamp => timestamp.toDate().toUtc(),
    final String text => DateTime.tryParse(text)?.toUtc(),
    _ => null,
  };

  static Object _translate(FirebaseException error) =>
      error.code == 'permission-denied' || error.code == 'unauthenticated'
      ? SettingsRemoteAuthException(error.message ?? error.code)
      : error;
}
