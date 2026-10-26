/// Convex remote for `shipglows_settings`: one settings row per account
/// (`commandglowsAppSettings`), changed fields only, server-side time.
///
/// There is no realtime feed. The controller pulls on resume and on its retry
/// timer, since [ConvexSettingsRemote.watch] returns `null`.
library;

import 'package:shipglows_convex/shipglows_convex.dart';
import 'package:shipglows_settings/shipglows_settings.dart';

/// Server codes that mean the account cannot read or write its settings.
const _authFailureCodes = <String>{
  'commandglows_app_unauthenticated',
  'commandglows_app_entitlement_required',
  'commandglows_app_not_found',
  'unauthenticated',
};

class ConvexSettingsRemote implements SettingsRemote {
  ConvexSettingsRemote(this.client);

  /// The deployment client, signed in with the Clerk token.
  final ConvexHttpClient client;

  @override
  Future<RemoteSettings?> fetch() async {
    try {
      return _read(await client.query('commandglowsAppSettings:get'));
    } on ConvexException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<RemoteSettings?> push(Map<String, Object?> changes) async {
    try {
      // A `null` value removes the key on the server.
      return _read(
        await client.mutation('commandglowsAppSettings:push', {
          'changes': changes,
        }),
      );
    } on ConvexException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Stream<RemoteSettings?>? watch() => null;

  static RemoteSettings? _read(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final values = raw['values'];
    return RemoteSettings(
      values: values is Map
          ? Map<String, Object?>.from(values)
          : const <String, Object?>{},
      revision: raw['revision'] as String?,
      updatedAt: convexMillisToDateTime(raw['updatedAt']).toUtc(),
    );
  }

  /// Auth failures become [SettingsRemoteAuthException]. The server may send
  /// the code as the error data or only inside the message, so both are read.
  static Never _rethrow(ConvexException error) {
    final isAuthFailure =
        _authFailureCodes.contains(error.code) ||
        _authFailureCodes.any(error.message.contains);
    if (isAuthFailure) {
      throw SettingsRemoteAuthException(error.message);
    }
    throw error;
  }
}
