import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/models/note_document.dart';

NoteBlock block(
  NoteBlockKind kind, {
  String text = '',
  bool checked = false,
  double number = 0,
  String unit = '',
}) =>
    NoteBlock.empty(kind).copyWith(
      text: text,
      isChecked: checked,
      numberValue: number,
      unit: unit,
    );

void main() {
  group('NoteBlock', () {
    test('empty blocks get unique ids', () {
      final ids = {
        for (var i = 0; i < 200; i++) NoteBlock.empty(NoteBlockKind.paragraph).id,
      };
      expect(ids, hasLength(200));
    });

    test('copyWith keeps the id', () {
      final original = NoteBlock.empty(NoteBlockKind.paragraph);
      expect(original.copyWith(text: 'x').id, original.id);
    });

    test('json round trip keeps every field', () {
      final original = NoteBlock.empty(NoteBlockKind.heading).copyWith(
        text: 'Titre',
        headingLevel: 4,
        isChecked: true,
        numberValue: 2.5,
        unit: 'kg',
        textColor: 0xFF123456,
        highlightColor: 0xFF654321,
        isBold: true,
        isItalic: true,
        isUnderlined: true,
        isStruckThrough: true,
      );
      final copy = NoteBlock.fromJson(original.toJson());
      expect(copy.toJson(), original.toJson());
    });

    test('fromJson clamps heading levels and defaults unknown kinds', () {
      final tooBig = NoteBlock.fromJson({'kind': 'heading', 'headingLevel': 9});
      expect(tooBig.headingLevel, 6);
      final tooSmall =
          NoteBlock.fromJson({'kind': 'heading', 'headingLevel': 1});
      expect(tooSmall.headingLevel, 2);
      expect(NoteBlock.fromJson({'kind': 'video'}).kind, NoteBlockKind.paragraph);
    });

    test('fromJson fills missing fields', () {
      final parsed = NoteBlock.fromJson({});
      expect(parsed.id, isNotEmpty);
      expect(parsed.kind, NoteBlockKind.paragraph);
      expect(parsed.text, '');
      expect(parsed.isChecked, isFalse);
      expect(parsed.numberValue, 0);
    });
  });

  group('NoteDocument.decode', () {
    test('empty input gives a single empty paragraph', () {
      for (final input in ['', '   ', '\n']) {
        final document = NoteDocument.decode(input);
        expect(document.blocks, hasLength(1));
        expect(document.blocks.single.kind, NoteBlockKind.paragraph);
        expect(document.blocks.single.text, '');
      }
    });

    test('imports legacy plain text line by line', () {
      final document = NoteDocument.decode('Ligne 1\nLigne 2');
      expect(document.blocks.map((b) => b.text), ['Ligne 1', 'Ligne 2']);
      expect(
        document.blocks.every((b) => b.kind == NoteBlockKind.paragraph),
        isTrue,
      );
    });

    test('json that is not a document is treated as text', () {
      expect(NoteDocument.decode('42').blocks.single.text, '42');
      expect(
        NoteDocument.decode('{"blocks": "nope"}').blocks.single.text,
        '{"blocks": "nope"}',
      );
    });

    test('a document without blocks becomes an empty document', () {
      final document = NoteDocument.decode(jsonEncode({'blocks': []}));
      expect(document.blocks, hasLength(1));
    });

    test('ignores malformed block entries', () {
      final document = NoteDocument.decode(jsonEncode({
        'blocks': [
          'text',
          {'kind': 'checkbox', 'text': 'ok'},
        ],
      }));
      expect(document.blocks, hasLength(1));
      expect(document.blocks.single.kind, NoteBlockKind.checkbox);
    });

    test('encode then decode keeps the blocks', () {
      final document = NoteDocument([
        block(NoteBlockKind.heading, text: 'Courses'),
        block(NoteBlockKind.checkbox, text: 'Pain', checked: true),
        block(NoteBlockKind.number, text: 'Poids', number: 3, unit: 'kg'),
      ]);
      final decoded = NoteDocument.decode(document.encode());
      expect(
        decoded.blocks.map((b) => b.toJson()).toList(),
        document.blocks.map((b) => b.toJson()).toList(),
      );
    });

    test('encoded documents carry a version', () {
      final json = jsonDecode(NoteDocument.empty().encode());
      expect(json['version'], 1);
    });
  });

  group('NoteDocument.plainText', () {
    test('renders every kind of block', () {
      final document = NoteDocument([
        block(NoteBlockKind.heading, text: 'Titre'),
        block(NoteBlockKind.paragraph, text: 'Texte'),
        block(NoteBlockKind.checkbox, text: 'Fait', checked: true),
        block(NoteBlockKind.checkbox, text: 'À faire'),
        block(NoteBlockKind.unorderedList, text: 'Puce'),
        block(NoteBlockKind.number, text: 'Eau', number: 1.5, unit: 'L'),
      ]);
      expect(
        document.plainText,
        'Titre\nTexte\n☑ Fait\n☐ À faire\n• Puce\nEau : 1.5 L',
      );
    });

    test('numbers ordered lists and restarts after another block', () {
      final document = NoteDocument([
        block(NoteBlockKind.orderedList, text: 'a'),
        block(NoteBlockKind.orderedList, text: 'b'),
        block(NoteBlockKind.paragraph, text: 'pause'),
        block(NoteBlockKind.orderedList, text: 'c'),
      ]);
      expect(document.plainText, '1. a\n2. b\npause\n1. c');
    });

    test('skips blank lines', () {
      final document = NoteDocument([
        block(NoteBlockKind.paragraph, text: 'a'),
        block(NoteBlockKind.paragraph, text: '   '),
        block(NoteBlockKind.paragraph, text: 'b'),
      ]);
      expect(document.plainText, 'a\nb');
    });

    test('number blocks without label show only the measure', () {
      expect(
        NoteDocument([block(NoteBlockKind.number, number: 12)]).plainText,
        '12',
      );
      expect(
        NoteDocument([block(NoteBlockKind.number, number: 2.25, unit: '€')])
            .plainText,
        '2.25 €',
      );
    });
  });
}
