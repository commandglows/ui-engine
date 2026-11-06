import 'dart:convert';
import 'dart:typed_data';

/// Resource limits enforced by [parseSafeXml].
///
/// The defaults are conservative bounds that apply to any XML document read
/// by the app, whatever its format.
class SafeXmlLimits {
  /// Creates limits; every value is an inclusive upper bound.
  const SafeXmlLimits({
    this.maxBytes = 32 * 1024 * 1024,
    this.maxDepth = 96,
    this.maxNodes = 250000,
    this.maxTextLength = 1024 * 1024,
    this.maxNameLength = 128,
    this.maxAttributes = 64,
    this.maxAttributeValueLength = 4096,
  });

  /// Largest accepted input, in bytes (UTF-16 code units for a String input).
  final int maxBytes;

  /// Deepest allowed element nesting.
  final int maxDepth;

  /// Maximum number of start tags in one document.
  final int maxNodes;

  /// Maximum accumulated character data and CDATA kept per element.
  final int maxTextLength;

  /// Longest allowed element name, in code units.
  final int maxNameLength;

  /// Maximum number of attributes on one element.
  final int maxAttributes;

  /// Longest allowed raw attribute value, before entity decoding.
  final int maxAttributeValueLength;
}

/// Thrown by [parseSafeXml] when the input is malformed, unsafe, or over a
/// limit.
class SafeXmlException implements Exception {
  /// Creates an exception carrying a user-displayable [message].
  const SafeXmlException(this.message);

  /// Human-readable reason in French, safe to show to the user as is.
  final String message;

  @override
  String toString() => message;
}

/// An element produced by [parseSafeXml].
class SafeXmlNode {
  /// Creates a node; [parseSafeXml] is the normal way to obtain one.
  SafeXmlNode(this.name, this.attributes, this.parent);

  /// Qualified name exactly as written, including any namespace prefix.
  final String name;

  /// Attribute values with the predefined and numeric entities decoded.
  final Map<String, String> attributes;

  /// Enclosing element, or null for the root.
  final SafeXmlNode? parent;

  /// Child elements in document order.
  final List<SafeXmlNode> children = [];

  final StringBuffer _text = StringBuffer();

  /// [name] without its namespace prefix.
  String get localName => name.contains(':') ? name.split(':').last : name;

  /// Trimmed character data and CDATA directly inside this element.
  String get text => _text.toString().trim();

  /// The first child whose [localName] equals [name], or null.
  SafeXmlNode? child(String name) =>
      children.where((element) => element.localName == name).firstOrNull;

  /// Every child whose [localName] equals [name], in document order.
  Iterable<SafeXmlNode> childrenNamed(String name) =>
      children.where((element) => element.localName == name);

  /// Every descendant whose [localName] equals [name], depth-first.
  Iterable<SafeXmlNode> descendants(String name) sync* {
    for (final child in children) {
      if (child.localName == name) yield child;
      yield* child.descendants(name);
    }
  }
}

/// Parses [input] into an element tree, refusing anything that could fetch,
/// expand, or nest without bound.
///
/// [input] is a [Uint8List] of UTF-8 bytes or a [String]; any other type
/// throws [ArgumentError]. Comments, processing instructions and CDATA are
/// accepted. Every other `<!` declaration is rejected, including `<!ENTITY`.
/// When [allowDoctype] is true, a single `<!DOCTYPE>` before the root is also
/// accepted, but only in the forms `name`, `name SYSTEM "sysid"` or
/// `name PUBLIC "pubid" "sysid"`; an internal subset (`[`) is rejected. The
/// declaration is skipped, never fetched or interpreted.
///
/// Throws [SafeXmlException] for malformed input or input over [limits].
SafeXmlNode parseSafeXml(
  Object input, {
  SafeXmlLimits limits = const SafeXmlLimits(),
  bool allowDoctype = false,
}) {
  final String source;
  if (input is Uint8List) {
    if (input.length > limits.maxBytes) {
      throw const SafeXmlException('Document XML trop volumineux.');
    }
    source = utf8.decode(input, allowMalformed: false);
  } else if (input is String) {
    if (input.length > limits.maxBytes) {
      throw const SafeXmlException('Document XML trop volumineux.');
    }
    source = input;
  } else {
    throw ArgumentError.value(
        input, 'input', 'must be a Uint8List or a String');
  }
  return _SafeXmlParser(source, limits, allowDoctype).parse();
}

final _doctypePattern = RegExp(
  r"""^DOCTYPE\s+[A-Za-z_][\w.\-:]*(\s+(PUBLIC\s+"[^"<>]*"\s+"[^"<>]*"|PUBLIC\s+'[^'<>]*'\s+'[^'<>]*'|SYSTEM\s+"[^"<>]*"|SYSTEM\s+'[^'<>]*'))?\s*$""",
);

class _SafeXmlParser {
  _SafeXmlParser(this._source, this._limits, this._allowDoctype);

  final String _source;
  final SafeXmlLimits _limits;
  final bool _allowDoctype;
  final List<SafeXmlNode> _stack = [];
  SafeXmlNode? _root;
  bool _doctypeSeen = false;
  int _nodeCount = 0;

  SafeXmlNode parse() {
    final source = _source;
    var cursor = 0;
    while (cursor < source.length) {
      if (source.codeUnitAt(cursor) != 60) {
        final end = source.indexOf('<', cursor);
        final limit = end == -1 ? source.length : end;
        if (_stack.isNotEmpty) {
          _appendText(_decodeXmlText(source.substring(cursor, limit)));
        }
        cursor = limit;
        continue;
      }
      if (source.startsWith('<!--', cursor)) {
        cursor = _afterTerminator(source, cursor + 4, '-->');
        continue;
      }
      if (source.startsWith('<![CDATA[', cursor)) {
        final end = source.indexOf(']]>', cursor + 9);
        if (end == -1 || _stack.isEmpty) {
          throw const SafeXmlException(
              'Document XML invalide : bloc CDATA incorrect.');
        }
        _appendText(source.substring(cursor + 9, end));
        cursor = end + 3;
        continue;
      }
      if (source.startsWith('<!DOCTYPE', cursor) &&
          _allowDoctype &&
          !_doctypeSeen &&
          _root == null &&
          _stack.isEmpty) {
        cursor = _skipDoctype(source, cursor);
        _doctypeSeen = true;
        continue;
      }
      // Covers every other declaration, including <!ENTITY, which is never
      // accepted.
      if (source.startsWith('<!', cursor)) {
        throw const SafeXmlException(
            'Document XML invalide : déclaration externe interdite.');
      }
      if (source.startsWith('<?', cursor)) {
        cursor = _afterTerminator(source, cursor + 2, '?>');
        continue;
      }
      final end = _findTagEnd(source, cursor + 1);
      if (end == -1) {
        throw const SafeXmlException(
            'Document XML invalide : balise incomplète.');
      }
      var body = source.substring(cursor + 1, end).trim();
      if (body.startsWith('/')) {
        final name = body.substring(1).trim();
        if (_stack.isEmpty || _stack.last.name != name) {
          throw const SafeXmlException(
              'Document XML invalide : balises incohérentes.');
        }
        _stack.removeLast();
        cursor = end + 1;
        continue;
      }
      final selfClosing = body.endsWith('/');
      if (selfClosing) body = body.substring(0, body.length - 1).trimRight();
      final parsed = _parseStartTag(body, _limits);
      if (++_nodeCount > _limits.maxNodes ||
          _stack.length >= _limits.maxDepth) {
        throw const SafeXmlException('Document XML trop complexe.');
      }
      final node = SafeXmlNode(parsed.$1, parsed.$2, _stack.lastOrNull);
      if (_stack.isEmpty) {
        if (_root != null) {
          throw const SafeXmlException(
              'Document XML invalide : plusieurs racines.');
        }
        _root = node;
      } else {
        _stack.last.children.add(node);
      }
      if (!selfClosing) _stack.add(node);
      cursor = end + 1;
    }
    final root = _root;
    if (_stack.isNotEmpty || root == null) {
      throw const SafeXmlException(
          'Document XML invalide : élément non fermé ou racine absente.');
    }
    return root;
  }

  void _appendText(String value) {
    final node = _stack.last;
    if (node._text.length + value.length > _limits.maxTextLength) {
      throw const SafeXmlException(
          'Document XML trop volumineux : texte d’un élément trop long.');
    }
    node._text.write(value);
  }

  /// Validates the `<!DOCTYPE>` starting at [start] and returns the index
  /// just past its closing `>`.
  int _skipDoctype(String source, int start) {
    String? quote;
    var end = -1;
    for (var index = start + 1; index < source.length; index++) {
      final char = source[index];
      if (quote != null) {
        if (char == quote) quote = null;
      } else if (char == '"' || char == "'") {
        quote = char;
      } else if (char == '[') {
        throw const SafeXmlException(
            'Document XML invalide : déclaration externe interdite.');
      } else if (char == '>') {
        end = index;
        break;
      }
    }
    if (end == -1) {
      throw const SafeXmlException(
          'Document XML invalide : commentaire ou déclaration incomplet.');
    }
    final declaration = source.substring(start + 2, end);
    if (!_doctypePattern.hasMatch(declaration)) {
      throw const SafeXmlException(
          'Document XML invalide : déclaration externe interdite.');
    }
    return end + 1;
  }
}

int _afterTerminator(String source, int start, String terminator) {
  final end = source.indexOf(terminator, start);
  if (end == -1) {
    throw const SafeXmlException(
        'Document XML invalide : commentaire ou déclaration incomplet.');
  }
  return end + terminator.length;
}

int _findTagEnd(String source, int start) {
  String? quote;
  for (var index = start; index < source.length; index++) {
    final char = source[index];
    if (quote != null) {
      if (char == quote) quote = null;
    } else if (char == '"' || char == "'") {
      quote = char;
    } else if (char == '>') {
      return index;
    }
  }
  return -1;
}

(String, Map<String, String>) _parseStartTag(
    String body, SafeXmlLimits limits) {
  var cursor = 0;
  while (cursor < body.length && !_space(body.codeUnitAt(cursor))) {
    cursor++;
  }
  final name = body.substring(0, cursor);
  if (name.isEmpty || name.length > limits.maxNameLength) {
    throw const SafeXmlException(
        'Document XML invalide : nom de balise invalide ou trop long.');
  }
  final attributes = <String, String>{};
  while (cursor < body.length) {
    while (cursor < body.length && _space(body.codeUnitAt(cursor))) {
      cursor++;
    }
    if (cursor >= body.length) break;
    final start = cursor;
    while (cursor < body.length &&
        !_space(body.codeUnitAt(cursor)) &&
        body.codeUnitAt(cursor) != 61) {
      cursor++;
    }
    final key = body.substring(start, cursor);
    while (cursor < body.length && _space(body.codeUnitAt(cursor))) {
      cursor++;
    }
    if (key.isEmpty ||
        cursor >= body.length ||
        body.codeUnitAt(cursor++) != 61) {
      throw const SafeXmlException(
          'Document XML invalide : attribut mal formé.');
    }
    while (cursor < body.length && _space(body.codeUnitAt(cursor))) {
      cursor++;
    }
    if (cursor >= body.length || (body[cursor] != '"' && body[cursor] != "'")) {
      throw const SafeXmlException(
          'Document XML invalide : valeur d’attribut non délimitée.');
    }
    final quote = body[cursor++];
    final valueStart = cursor;
    while (cursor < body.length && body[cursor] != quote) {
      cursor++;
    }
    if (cursor >= body.length ||
        cursor - valueStart > limits.maxAttributeValueLength ||
        attributes.containsKey(key)) {
      throw const SafeXmlException(
          'Document XML invalide : attribut invalide, dupliqué ou trop long.');
    }
    attributes[key] = _decodeXmlText(body.substring(valueStart, cursor));
    cursor++;
    if (attributes.length > limits.maxAttributes) {
      throw const SafeXmlException(
          'Document XML trop complexe : trop d’attributs.');
    }
  }
  return (name, attributes);
}

bool _space(int value) =>
    value == 32 || value == 9 || value == 10 || value == 13;

String _decodeXmlText(String value) => value.replaceAllMapped(
      RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);'),
      (match) {
        final token = match.group(1)!;
        if (token == 'amp') return '&';
        if (token == 'lt') return '<';
        if (token == 'gt') return '>';
        if (token == 'quot') return '"';
        if (token == 'apos') return "'";
        final hex = token.startsWith('#x');
        final scalar =
            int.tryParse(token.substring(hex ? 2 : 1), radix: hex ? 16 : 10);
        if (scalar == null ||
            scalar < 0 ||
            scalar > 0x10ffff ||
            scalar >= 0xd800 && scalar <= 0xdfff) {
          throw const SafeXmlException(
              'Document XML invalide : entité numérique incorrecte.');
        }
        return String.fromCharCode(scalar);
      },
    );
