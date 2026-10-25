import 'app_version.dart';

/// One published release, read from the Android manifest (`android.json`):
///
/// ```json
/// {
///   "version": "1.2.3+45",
///   "url": "https://github.com/dianedef/shipglows-releases/releases/download/<app>-v1.2.3-45/<App>-1.2.3-45.apk",
///   "sha256": "<64 hex>",
///   "size": 31457280,
///   "publishedAt": "2026-10-25T12:00:00Z",
///   "notesUrl": "https://…"
/// }
/// ```
///
/// The same shape as the `latest.json` written next to a Windows appcast.
final class ShipglowsRelease {
  const ShipglowsRelease({
    required this.version,
    required this.url,
    required this.sha256,
    this.size,
    this.publishedAt,
    this.notesUrl,
  });

  /// Throws a [FormatException] for a missing field, a non-HTTPS URL or a
  /// digest that is not 64 hexadecimal characters.
  factory ShipglowsRelease.fromJson(Map<String, Object?> json) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing "$key" in the update manifest');
      }
      return value.trim();
    }

    final url = Uri.tryParse(text('url'));
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw const FormatException('The update URL must be https');
    }
    final sha256 = text('sha256').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const FormatException('Bad sha256 in the update manifest');
    }
    final size = json['size'];
    final publishedAt = json['publishedAt'];
    final notesUrl = json['notesUrl'];
    return ShipglowsRelease(
      version: AppVersion.parse(text('version')),
      url: url,
      sha256: sha256,
      size: size is int && size > 0 ? size : null,
      publishedAt: publishedAt is String
          ? DateTime.tryParse(publishedAt)
          : null,
      notesUrl: notesUrl is String ? Uri.tryParse(notesUrl) : null,
    );
  }

  final AppVersion version;
  final Uri url;

  /// Lowercase hexadecimal SHA-256 of the file at [url].
  final String sha256;
  final int? size;
  final DateTime? publishedAt;
  final Uri? notesUrl;
}
