import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_xml/shipglows_xml.dart';

Uint8List _bytes(String xml) => Uint8List.fromList(utf8.encode(xml));

void main() {
  group('parseSafeXml basics', () {
    test('builds the element tree with names, attributes and text', () {
      final root = parseSafeXml(_bytes(
        '<?xml version="1.0"?><!-- c --><lib:Root id="r1">'
        '<Item n="a">first</Item><Item n="b"> second </Item><Other/>'
        '</lib:Root>',
      ));
      expect(root.name, 'lib:Root');
      expect(root.localName, 'Root');
      expect(root.attributes['id'], 'r1');
      expect(root.childrenNamed('Item').map((node) => node.text),
          ['first', 'second']);
      expect(root.child('Other'), isNotNull);
      expect(root.child('Missing'), isNull);
      expect(root.child('Item')!.parent, same(root));
    });

    test('descendants walks the whole subtree depth-first', () {
      final root = parseSafeXml(_bytes('<a><b><c>1</c></b><c>2</c></a>'));
      expect(root.descendants('c').map((node) => node.text), ['1', '2']);
    });

    test('accepts a String as well as UTF-8 bytes', () {
      final fromString = parseSafeXml('<a>é</a>');
      final fromBytes = parseSafeXml(_bytes('<a>é</a>'));
      expect(fromString.text, 'é');
      expect(fromBytes.text, 'é');
    });

    test('rejects an input that is neither bytes nor a String', () {
      expect(() => parseSafeXml(42), throwsArgumentError);
    });
  });

  group('entities and CDATA', () {
    test('decodes predefined and numeric entities in text and attributes', () {
      final root = parseSafeXml(_bytes(
        '<a v="&lt;&amp;&quot;&apos;&#65;&#x42;">&gt;&amp;&#x1F3B5;</a>',
      ));
      expect(root.attributes['v'], '<&"\'AB');
      expect(root.text, '>&\u{1F3B5}');
    });

    test('rejects an invalid numeric entity', () {
      expect(
        () => parseSafeXml(_bytes('<a>&#xD800;</a>')),
        throwsA(isA<SafeXmlException>()),
      );
    });

    test('keeps CDATA content verbatim', () {
      final root = parseSafeXml(_bytes('<a><![CDATA[1 < 2 & <b>&amp;]]></a>'));
      expect(root.text, '1 < 2 & <b>&amp;');
    });
  });

  group('limits', () {
    test('rejects input over maxBytes', () {
      expect(
        () => parseSafeXml(_bytes('<a/>'),
            limits: const SafeXmlLimits(maxBytes: 3)),
        throwsA(isA<SafeXmlException>()),
      );
    });

    test('rejects nesting deeper than maxDepth', () {
      expect(
        () => parseSafeXml(_bytes('<a><b><c/></b></a>'),
            limits: const SafeXmlLimits(maxDepth: 2)),
        throwsA(isA<SafeXmlException>()),
      );
    });

    test('rejects more start tags than maxNodes', () {
      expect(
        () => parseSafeXml(_bytes('<a><b/><c/></a>'),
            limits: const SafeXmlLimits(maxNodes: 2)),
        throwsA(isA<SafeXmlException>()),
      );
    });

    test('rejects element text longer than maxTextLength', () {
      expect(
        () => parseSafeXml(_bytes('<a>abcdef</a>'),
            limits: const SafeXmlLimits(maxTextLength: 5)),
        throwsA(isA<SafeXmlException>()),
      );
    });

    test('rejects too many attributes and over-long values', () {
      expect(
        () => parseSafeXml(_bytes('<a x="1" y="2"/>'),
            limits: const SafeXmlLimits(maxAttributes: 1)),
        throwsA(isA<SafeXmlException>()),
      );
      expect(
        () => parseSafeXml(_bytes('<a x="12345"/>'),
            limits: const SafeXmlLimits(maxAttributeValueLength: 4)),
        throwsA(isA<SafeXmlException>()),
      );
    });

    test('rejects element names over maxNameLength', () {
      expect(
        () => parseSafeXml(_bytes('<abcdef/>'),
            limits: const SafeXmlLimits(maxNameLength: 3)),
        throwsA(isA<SafeXmlException>()),
      );
    });
  });

  group('DOCTYPE and declarations', () {
    test('rejects a DOCTYPE by default', () {
      expect(
        () => parseSafeXml(_bytes('<!DOCTYPE GPIF><GPIF/>')),
        throwsA(isA<SafeXmlException>()),
      );
    });

    test('accepts DOCTYPE PUBLIC with allowDoctype and never fetches it', () {
      final root = parseSafeXml(
        _bytes('<!DOCTYPE GPIF PUBLIC "-//GP//DTD//EN" '
            '"http://example.invalid/gpif.dtd"><GPIF>ok</GPIF>'),
        allowDoctype: true,
      );
      expect(root.name, 'GPIF');
      expect(root.text, 'ok');
    });

    test('accepts DOCTYPE SYSTEM and bare DOCTYPE with allowDoctype', () {
      expect(
        parseSafeXml(
          _bytes("<!DOCTYPE GPIF SYSTEM 'file:///nonexistent.dtd'><GPIF/>"),
          allowDoctype: true,
        ).name,
        'GPIF',
      );
      expect(
        parseSafeXml(_bytes('<!DOCTYPE GPIF><GPIF/>'), allowDoctype: true).name,
        'GPIF',
      );
    });

    test('rejects an internal subset even with allowDoctype', () {
      expect(
        () => parseSafeXml(
          _bytes('<!DOCTYPE GPIF [<!ENTITY x "y">]><GPIF>&x;</GPIF>'),
          allowDoctype: true,
        ),
        throwsA(isA<SafeXmlException>()),
      );
    });

    test('rejects an ENTITY declaration in every mode', () {
      const xml = '<!ENTITY x SYSTEM "file:///secret"><GPIF>&x;</GPIF>';
      expect(() => parseSafeXml(_bytes(xml)), throwsA(isA<SafeXmlException>()));
      expect(() => parseSafeXml(_bytes(xml), allowDoctype: true),
          throwsA(isA<SafeXmlException>()));
    });

    test('rejects a DOCTYPE that is malformed or not before the root', () {
      expect(
        () => parseSafeXml(_bytes('<!DOCTYPE GPIF PUBLIC "x"><GPIF/>'),
            allowDoctype: true),
        throwsA(isA<SafeXmlException>()),
      );
      expect(
        () =>
            parseSafeXml(_bytes('<GPIF/><!DOCTYPE GPIF>'), allowDoctype: true),
        throwsA(isA<SafeXmlException>()),
      );
      expect(
        () => parseSafeXml(_bytes('<!DOCTYPE A><!DOCTYPE B><A/>'),
            allowDoctype: true),
        throwsA(isA<SafeXmlException>()),
      );
    });
  });
}
