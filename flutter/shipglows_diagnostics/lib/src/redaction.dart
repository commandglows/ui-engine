/// Masks secrets in diagnostic text before it is kept, written or copied.
///
/// Covers the shapes the apps actually log: Google API keys, Supabase keys,
/// JWTs, `sk-` keys, `Bearer` headers and `key=value` / `key: value` pairs
/// whose name says token, secret, password or API key. Line breaks are kept
/// so that stack traces stay readable.
String redactSecrets(String text) {
  var result = text;
  for (final pattern in _valuePatterns) {
    result = result.replaceAll(pattern, redactedPlaceholder);
  }
  return result.replaceAllMapped(
    _namedValue,
    (match) => '${match[1]}${match[2]}$redactedPlaceholder',
  );
}

/// What a masked secret is replaced with.
const redactedPlaceholder = '<redacted>';

final _valuePatterns = [
  RegExp(r'AIza[0-9A-Za-z_-]{20,}'),
  RegExp(r'sb_[0-9A-Za-z_-]{12,}'),
  RegExp(r'eyJ[0-9A-Za-z_.-]{20,}'),
  RegExp(r'sk-[0-9A-Za-z_-]{12,}'),
  RegExp(r'Bearer\s+[0-9A-Za-z_.~+/=-]{12,}', caseSensitive: false),
];

// Keeps the name, masks the value: "token=abc" becomes "token=<redacted>".
final _namedValue = RegExp(
  r'((?:api|anon|publishable|secret|access|refresh|client)?[_-]?(?:key|token|secret|password|passwd|id[_-]?token))'
  r'(\s*[:=]\s*)(?!<redacted>)[^,\s;|&"]+',
  caseSensitive: false,
);
