/// [text] as an S3 endpoint URL, such as
/// `https://<compte>.r2.cloudflarestorage.com`. Plain http is allowed only
/// for this computer, for a local MinIO; anything else must be https.
///
/// Throws a [FormatException] with a French message otherwise.
Uri parseS3Endpoint(String text) {
  final uri = Uri.tryParse(text.trim());
  final local = uri != null &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1');
  if (uri == null ||
      uri.host.isEmpty ||
      !(uri.scheme == 'https' || (uri.scheme == 'http' && local)) ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
      'Point de terminaison invalide : une adresse https:// est attendue.',
    );
  }
  return uri;
}
