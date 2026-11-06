/// AWS Signature Version 4, as S3-compatible stores (Cloudflare R2, MinIO,
/// AWS) expect it in the `Authorization` header.
///
/// The path is encoded once, as S3 wants, not twice as other AWS services
/// do. See https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sigv-create-signed-request.html
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// SHA-256 of an empty body, in hex.
const emptyPayloadHash =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

/// Access key pair of one account.
typedef AwsCredentials = ({String accessKeyId, String secretAccessKey});

/// Signs requests for one [region] and [service] (`s3` for a bucket).
class SigV4Signer {
  const SigV4Signer({
    required this.credentials,
    required this.region,
    this.service = 's3',
  });

  final AwsCredentials credentials;
  final String region;
  final String service;

  /// Headers to add to a request so it is signed: `x-amz-date`,
  /// `x-amz-content-sha256` when [signContentHash], and `Authorization`.
  ///
  /// [headers] are the other headers sent, `host` included; every one is
  /// signed. [path] is the raw, unencoded path, starting with `/`.
  /// [payloadHash] is the hex SHA-256 of the body.
  Map<String, String> sign({
    required String method,
    required String path,
    Map<String, String> query = const {},
    required Map<String, String> headers,
    required String payloadHash,
    required DateTime now,
    bool signContentHash = true,
  }) {
    final amzDate = formatAmzDate(now);
    final day = amzDate.substring(0, 8);
    final added = <String, String>{
      'x-amz-date': amzDate,
      if (signContentHash) 'x-amz-content-sha256': payloadHash,
    };
    final all = <String, String>{
      for (final entry in headers.entries)
        entry.key.toLowerCase(): entry.value.trim().replaceAll(
              RegExp(r'\s+'),
              ' ',
            ),
      ...added,
    };
    final names = all.keys.toList()..sort();
    final signedHeaders = names.join(';');
    final canonicalRequest = [
      method,
      canonicalPath(path),
      canonicalQuery(query),
      for (final name in names) '$name:${all[name]}',
      '',
      signedHeaders,
      payloadHash,
    ].join('\n');
    final scope = '$day/$region/$service/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');
    List<int> key = utf8.encode('AWS4${credentials.secretAccessKey}');
    for (final part in [day, region, service, 'aws4_request']) {
      key = Hmac(sha256, key).convert(utf8.encode(part)).bytes;
    }
    final signature =
        Hmac(sha256, key).convert(utf8.encode(stringToSign)).toString();
    return {
      ...added,
      'Authorization': 'AWS4-HMAC-SHA256 '
          'Credential=${credentials.accessKeyId}/$scope, '
          'SignedHeaders=$signedHeaders, Signature=$signature',
    };
  }
}

/// [time] in UTC as `YYYYMMDD'T'HHMMSS'Z'`.
String formatAmzDate(DateTime time) {
  final utc = time.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
      '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

/// [value] percent-encoded as SigV4 wants: every byte but `A-Z a-z 0-9 - _ . ~`,
/// and `/` too unless [keepSlash].
String uriEncode(String value, {bool keepSlash = false}) {
  final buffer = StringBuffer();
  for (final byte in utf8.encode(value)) {
    final unreserved = (byte >= 0x41 && byte <= 0x5a) ||
        (byte >= 0x61 && byte <= 0x7a) ||
        (byte >= 0x30 && byte <= 0x39) ||
        byte == 0x2d ||
        byte == 0x5f ||
        byte == 0x2e ||
        byte == 0x7e ||
        (keepSlash && byte == 0x2f);
    if (unreserved) {
      buffer.writeCharCode(byte);
    } else {
      buffer.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return buffer.toString();
}

/// The raw [path] encoded once, slashes kept.
String canonicalPath(String path) =>
    path.isEmpty ? '/' : uriEncode(path, keepSlash: true);

/// [query] sorted by encoded name, as `name=value&…`.
String canonicalQuery(Map<String, String> query) {
  final pairs = [
    for (final entry in query.entries)
      (uriEncode(entry.key), uriEncode(entry.value)),
  ]..sort((a, b) {
      final byName = a.$1.compareTo(b.$1);
      return byName != 0 ? byName : a.$2.compareTo(b.$2);
    });
  return pairs.map((pair) => '${pair.$1}=${pair.$2}').join('&');
}
