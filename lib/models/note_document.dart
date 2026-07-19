import 'dart:convert';

enum NoteBlockKind {
  paragraph,
  heading,
  checkbox,
  number,
  unorderedList,
  orderedList,
}

class NoteBlock {
  const NoteBlock({
    required this.id,
    required this.kind,
    this.text = '',
    this.headingLevel = 2,
    this.isChecked = false,
    this.numberValue = 0,
    this.unit = '',
    this.textColor = 0,
    this.highlightColor = 0,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderlined = false,
    this.isStruckThrough = false,
  });

  final String id;
  final NoteBlockKind kind;
  final String text;
  final int headingLevel;
  final bool isChecked;
  final double numberValue;
  final String unit;
  final int textColor;
  final int highlightColor;
  final bool isBold;
  final bool isItalic;
  final bool isUnderlined;
  final bool isStruckThrough;

  static int _idCounter = 0;

  factory NoteBlock.empty(NoteBlockKind kind) => NoteBlock(
        id: '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
        kind: kind,
        headingLevel: kind == NoteBlockKind.heading ? 2 : 2,
      );

  factory NoteBlock.fromJson(Map<String, Object?> json) {
    final kindName = json['kind'] as String?;
    return NoteBlock(
      id: json['id'] as String? ??
          '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
      kind: NoteBlockKind.values.firstWhere(
        (kind) => kind.name == kindName,
        orElse: () => NoteBlockKind.paragraph,
      ),
      text: json['text'] as String? ?? '',
      headingLevel: (json['headingLevel'] as num?)?.toInt().clamp(2, 6) ?? 2,
      isChecked: json['isChecked'] as bool? ?? false,
      numberValue: (json['numberValue'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '',
      textColor: (json['textColor'] as num?)?.toInt() ?? 0,
      highlightColor: (json['highlightColor'] as num?)?.toInt() ?? 0,
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
      isUnderlined: json['isUnderlined'] as bool? ?? false,
      isStruckThrough: json['isStruckThrough'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'text': text,
        'headingLevel': headingLevel,
        'isChecked': isChecked,
        'numberValue': numberValue,
        'unit': unit,
        'textColor': textColor,
        'highlightColor': highlightColor,
        'isBold': isBold,
        'isItalic': isItalic,
        'isUnderlined': isUnderlined,
        'isStruckThrough': isStruckThrough,
      };

  NoteBlock copyWith({
    NoteBlockKind? kind,
    String? text,
    int? headingLevel,
    bool? isChecked,
    double? numberValue,
    String? unit,
    int? textColor,
    int? highlightColor,
    bool? isBold,
    bool? isItalic,
    bool? isUnderlined,
    bool? isStruckThrough,
  }) =>
      NoteBlock(
        id: id,
        kind: kind ?? this.kind,
        text: text ?? this.text,
        headingLevel: headingLevel ?? this.headingLevel,
        isChecked: isChecked ?? this.isChecked,
        numberValue: numberValue ?? this.numberValue,
        unit: unit ?? this.unit,
        textColor: textColor ?? this.textColor,
        highlightColor: highlightColor ?? this.highlightColor,
        isBold: isBold ?? this.isBold,
        isItalic: isItalic ?? this.isItalic,
        isUnderlined: isUnderlined ?? this.isUnderlined,
        isStruckThrough: isStruckThrough ?? this.isStruckThrough,
      );
}

class NoteDocument {
  const NoteDocument(this.blocks);

  final List<NoteBlock> blocks;

  factory NoteDocument.empty() => NoteDocument([
        NoteBlock.empty(NoteBlockKind.paragraph),
      ]);

  /// Decodes the block document and transparently imports legacy plain notes.
  factory NoteDocument.decode(String encoded) {
    if (encoded.trim().isEmpty) return NoteDocument.empty();

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic> && decoded['blocks'] is List) {
        final blocks = (decoded['blocks'] as List)
            .whereType<Map>()
            .map(
              (block) => NoteBlock.fromJson(
                block.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              ),
            )
            .toList();
        return blocks.isEmpty ? NoteDocument.empty() : NoteDocument(blocks);
      }
    } catch (_) {
      // The value is a note created before the rich block editor.
    }

    final lines = encoded.split('\n');
    return NoteDocument([
      for (final line in lines)
        NoteBlock.empty(NoteBlockKind.paragraph).copyWith(text: line),
    ]);
  }

  String encode() => jsonEncode({
        'version': 1,
        'blocks': blocks.map((block) => block.toJson()).toList(),
      });

  String get plainText {
    final buffer = StringBuffer();
    var orderedIndex = 0;

    for (final block in blocks) {
      if (block.kind == NoteBlockKind.orderedList) {
        orderedIndex++;
      } else {
        orderedIndex = 0;
      }

      final line = switch (block.kind) {
        NoteBlockKind.checkbox =>
          '${block.isChecked ? '☑' : '☐'} ${block.text}',
        NoteBlockKind.number => _numberLine(block),
        NoteBlockKind.unorderedList => '• ${block.text}',
        NoteBlockKind.orderedList => '$orderedIndex. ${block.text}',
        _ => block.text,
      };
      if (line.trim().isNotEmpty) buffer.writeln(line.trimRight());
    }
    return buffer.toString().trim();
  }

  static String _numberLine(NoteBlock block) {
    final value = block.numberValue == block.numberValue.roundToDouble()
        ? block.numberValue.toInt().toString()
        : block.numberValue.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    final measurement =
        [value, block.unit.trim()].where((part) => part.isNotEmpty).join(' ');
    return block.text.trim().isEmpty
        ? measurement
        : '${block.text.trim()} : $measurement';
  }
}
