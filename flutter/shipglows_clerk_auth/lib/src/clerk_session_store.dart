import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'clerk_session.dart';

/// Where the session survives app restarts.
abstract interface class ClerkSessionStore {
  Future<ClerkSession?> read();
  Future<void> write(ClerkSession session);
  Future<void> clear();
}

/// Keystore-backed on Android, DPAPI-backed on Windows. One entry per
/// OAuth client, so two products on one device never share a session.
class SecureClerkSessionStore implements ClerkSessionStore {
  SecureClerkSessionStore({
    required String clientId,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _key = 'shipglows_clerk_session.$clientId',
       _storage = storage;

  final String _key;
  final FlutterSecureStorage _storage;

  @override
  Future<ClerkSession?> read() async {
    String? raw;
    try {
      raw = await _storage.read(key: _key);
    } on PlatformException {
      // The Keystore or DPAPI can no longer open the entry: drop it and sign in again.
      await clear();
      return null;
    }
    if (raw == null) {
      return null;
    }
    try {
      return ClerkSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      await clear();
      return null;
    } on TypeError {
      // An entry written by an older shape: drop it, the user signs in again.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(ClerkSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  /// Best effort: a delete the platform refuses leaves the entry behind. The
  /// refresh token is revoked on sign-out, so the next restore refuses it and
  /// clears the entry again.
  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on PlatformException {
      // Ignored on purpose: callers clear local state and must not throw.
    }
  }
}

/// For tests and previews.
class MemoryClerkSessionStore implements ClerkSessionStore {
  ClerkSession? _session;

  @override
  Future<ClerkSession?> read() async => _session;

  @override
  Future<void> write(ClerkSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
