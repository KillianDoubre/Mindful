import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/models/note_document.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/providers/productivity/productivity_items_provider.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/mindful_background.dart';

const _noteColors = <int>[
  0,
  0xFFFFD9DE,
  0xFFFFE1C7,
  0xFFFFF0B8,
  0xFFD9F2DF,
  0xFFD7EBFF,
  0xFFE9DDFB,
];

const _textColors = <int>[
  0,
  0xFFD32F2F,
  0xFFF57C00,
  0xFF388E3C,
  0xFF1976D2,
  0xFF7B1FA2,
  0xFF455A64,
];

const _highlightColors = <int>[
  0,
  0xFFFFF59D,
  0xFFFFCCBC,
  0xFFC8E6C9,
  0xFFBBDEFB,
  0xFFE1BEE7,
];

/// A full-screen, always-editable note canvas (Google Keep style).
///
/// Reading and editing share the exact same surface: there is no separate
/// read-only mode. The whole note is a single uniform block — a tinted glass
/// card holding a borderless title and full-width, background-free text blocks.
/// A single persistent toolbar at the bottom drives block type, formatting,
/// adding and deleting blocks.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.note,
  });

  final ProductivityItem? note;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late List<NoteBlock> _blocks;
  late int _noteColorValue;

  String? _activeBlockId;
  String? _focusBlockId;
  bool _isDirty = false;
  bool _isSaving = false;

  NoteBlock? get _activeBlock {
    final id = _activeBlockId;
    if (id == null) return _blocks.firstOrNull;
    return _blocks.where((block) => block.id == id).firstOrNull ??
        _blocks.firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title);
    _blocks = NoteDocument.decode(widget.note?.details ?? '').blocks.toList();
    _noteColorValue = widget.note?.colorValue ?? 0;
    _activeBlockId = _blocks.firstOrNull?.id;
    _titleController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_markDirty)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final activeBlock = _activeBlock;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: colors.surface.withValues(alpha: 0.96),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Retour',
            onPressed: _requestClose,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(widget.note == null ? 'Nouvelle note' : 'Note'),
          actions: [
            _ColorMenu(
              tooltip: 'Couleur de la note',
              icon: Icons.palette_outlined,
              values: _noteColors,
              selectedValue: _noteColorValue,
              onSelected: (value) {
                setState(() => _noteColorValue = value);
                _markDirty();
              },
            ),
            if (widget.note != null)
              IconButton(
                tooltip: 'Supprimer la note',
                onPressed: _confirmDelete,
                icon: Icon(Icons.delete_outline_rounded, color: colors.error),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 4),
              child: FilledButton.icon(
                onPressed: (_isSaving || !_isDirty) ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 19),
                label: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MindfulBackground(),
            Column(
              children: [
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    // Keep the keyboard (and any active text selection) alive
                    // while scrolling — onDrag would dismiss both.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      GlassSurface(
                        color: _resolveNoteColor(theme, _noteColorValue),
                        borderRadius: BorderRadius.circular(28),
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTitleField(theme),
                            const SizedBox(height: 4),
                            for (var index = 0;
                                index < _blocks.length;
                                index++)
                              _NoteBlockEditor(
                                key: ValueKey(_blocks[index].id),
                                block: _blocks[index],
                                orderedNumber: _orderedNumberAt(index),
                                requestFocus: _blocks[index].id == _focusBlockId,
                                onFocused: () => setState(
                                  () {
                                    _activeBlockId = _blocks[index].id;
                                    _focusBlockId = null;
                                  },
                                ),
                                onChanged: _replaceBlock,
                                onListBreak: _handleListBreak,
                                onListShortcut: _applyListShortcut,
                                onBackspaceEmpty: _handleBackspaceEmpty,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (activeBlock != null)
                  _BottomEditingBar(
                    block: activeBlock,
                    onTypeChanged: _changeActiveBlockType,
                    onBlockChanged: _replaceBlock,
                    onAdd: _insertBlock,
                    onDelete: () => _removeBlock(activeBlock),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField(ThemeData theme) => TextField(
        controller: _titleController,
        textCapitalization: TextCapitalization.sentences,
        maxLines: null,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        decoration: const InputDecoration(
          hintText: 'Titre',
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
        ),
      );

  int _orderedNumberAt(int index) {
    var number = 0;
    for (var current = index; current >= 0; current--) {
      if (_blocks[current].kind != NoteBlockKind.orderedList) break;
      number++;
    }
    return number;
  }

  void _replaceBlock(NoteBlock updated) {
    final index = _blocks.indexWhere((block) => block.id == updated.id);
    if (index < 0) return;
    setState(() {
      _blocks[index] = updated;
      _activeBlockId = updated.id;
    });
    _markDirty();
  }

  void _changeActiveBlockType(NoteBlockKind kind, [int headingLevel = 2]) {
    final block = _activeBlock;
    if (block == null) return;
    _replaceBlock(block.copyWith(kind: kind, headingLevel: headingLevel));
  }

  void _insertBlock(NoteBlockKind kind, [int headingLevel = 2]) {
    final block = NoteBlock.empty(kind).copyWith(headingLevel: headingLevel);
    final activeIndex =
        _blocks.indexWhere((current) => current.id == _activeBlockId);
    final insertionIndex = activeIndex < 0 ? _blocks.length : activeIndex + 1;
    setState(() {
      _blocks.insert(insertionIndex, block);
      _activeBlockId = block.id;
      _focusBlockId = block.id;
    });
    _markDirty();
  }

  /// Google-Keep-style markdown shortcut: `- ` / `* ` starts a bullet list and
  /// `1. ` / `1) ` starts a numbered list. The prefix is consumed by the caller.
  void _applyListShortcut(NoteBlock block, NoteBlockKind kind) {
    _replaceBlock(block.copyWith(kind: kind, text: ''));
  }

  /// Handles Enter inside a list/checkbox block: continue the list with a fresh
  /// sibling of the same kind, or — when Enter is pressed on an already empty
  /// item (a second line break) — end the list by turning it into a paragraph.
  void _handleListBreak(NoteBlock block, String before, String after) {
    final index = _blocks.indexWhere((current) => current.id == block.id);
    if (index < 0) return;

    if (before.isEmpty && after.isEmpty) {
      setState(() {
        _blocks[index] = block.copyWith(
          kind: NoteBlockKind.paragraph,
          text: '',
        );
        _activeBlockId = block.id;
      });
      _markDirty();
      return;
    }

    final sibling = NoteBlock.empty(block.kind).copyWith(
      headingLevel: block.headingLevel,
      text: after,
    );
    setState(() {
      _blocks[index] = block.copyWith(text: before);
      _blocks.insert(index + 1, sibling);
      _activeBlockId = sibling.id;
      _focusBlockId = sibling.id;
    });
    _markDirty();
  }

  /// Backspace on an empty block: a list/checkbox item drops its marker and
  /// becomes a paragraph; an empty paragraph merges into the previous block.
  void _handleBackspaceEmpty(NoteBlock block) {
    final index = _blocks.indexWhere((current) => current.id == block.id);
    if (index < 0) return;

    if (block.kind != NoteBlockKind.paragraph) {
      setState(() {
        _blocks[index] = block.copyWith(kind: NoteBlockKind.paragraph);
        _activeBlockId = block.id;
        _focusBlockId = block.id;
      });
      _markDirty();
      return;
    }

    if (index > 0) {
      final previous = _blocks[index - 1];
      setState(() {
        _blocks.removeAt(index);
        _activeBlockId = previous.id;
        _focusBlockId = previous.id;
      });
      _markDirty();
    }
  }

  void _removeBlock(NoteBlock block) {
    setState(() {
      if (_blocks.length == 1) {
        final replacement = NoteBlock.empty(NoteBlockKind.paragraph);
        _blocks[0] = replacement;
        _activeBlockId = replacement.id;
        _focusBlockId = replacement.id;
      } else {
        final index = _blocks.indexWhere((current) => current.id == block.id);
        if (index < 0) return;
        _blocks.removeAt(index);
        final nextIndex = index.clamp(0, _blocks.length - 1);
        _activeBlockId = _blocks[nextIndex].id;
      }
    });
    _markDirty();
  }

  void _markDirty() {
    if (!_isDirty && mounted) {
      setState(() => _isDirty = true);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Ajoutez un titre à la note.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final document = NoteDocument(_blocks);
      await ref
          .read(productivityItemsProvider(ProductivityItemType.note).notifier)
          .save(
            ProductivityItemDraft(
              title: title,
              details: document.encode(),
              colorValue: _noteColorValue,
            ),
            id: widget.note?.id,
          );
      if (!mounted) return;
      if (widget.note == null) {
        setState(() => _isDirty = false);
        await Future<void>.delayed(Duration.zero);
        if (mounted) Navigator.pop(context);
      } else {
        setState(() {
          _isDirty = false;
          _isSaving = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La note n'a pas pu être enregistrée.")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _requestClose() async {
    if (!_isDirty) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.edit_note_rounded),
        title: const Text('Abandonner les modifications ?'),
        content: const Text('Les changements non enregistrés seront perdus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continuer à écrire'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _isDirty = false);
      await Future<void>.delayed(Duration.zero);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _confirmDelete() async {
    final note = widget.note;
    if (note == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Supprimer cette note ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(productivityItemsProvider(ProductivityItemType.note).notifier)
        .delete(note);
    if (!mounted) return;
    setState(() => _isDirty = false);
    await Future<void>.delayed(Duration.zero);
    if (mounted) Navigator.pop(context);
  }

  Color _resolveNoteColor(ThemeData theme, int value) {
    final colors = theme.colorScheme;
    if (value == 0) return colors.surfaceContainerHigh;
    return Color.lerp(
      colors.surfaceContainerHigh,
      Color(value),
      theme.brightness == Brightness.dark ? 0.20 : 0.58,
    )!;
  }
}

TextStyle _noteBlockTextStyle(BuildContext context, NoteBlock block) {
  final colors = Theme.of(context).colorScheme;
  final headingSize = switch (block.headingLevel) {
    2 => 28.0,
    3 => 24.0,
    4 => 21.0,
    5 => 19.0,
    _ => 17.0,
  };
  final decorations = <TextDecoration>[
    if (block.isUnderlined) TextDecoration.underline,
    if (block.isStruckThrough) TextDecoration.lineThrough,
  ];
  return TextStyle(
    fontSize: block.kind == NoteBlockKind.heading ? headingSize : 16,
    fontWeight: block.kind == NoteBlockKind.heading || block.isBold
        ? FontWeight.w700
        : FontWeight.w400,
    fontStyle: block.isItalic ? FontStyle.italic : FontStyle.normal,
    color: block.textColor == 0 ? colors.onSurface : Color(block.textColor),
    backgroundColor:
        block.highlightColor == 0 ? null : Color(block.highlightColor),
    decoration: decorations.isEmpty
        ? TextDecoration.none
        : TextDecoration.combine(decorations),
    height: 1.35,
  );
}

/// The single persistent toolbar at the bottom of the editor. Rides above the
/// keyboard when it is open. Combines block-type selection, inline formatting,
/// text/highlight colours, and add/delete for the active block.
class _BottomEditingBar extends StatelessWidget {
  const _BottomEditingBar({
    required this.block,
    required this.onTypeChanged,
    required this.onBlockChanged,
    required this.onAdd,
    required this.onDelete,
  });

  final NoteBlock block;
  final void Function(NoteBlockKind kind, [int headingLevel]) onTypeChanged;
  final ValueChanged<NoteBlock> onBlockChanged;
  final void Function(NoteBlockKind kind, [int headingLevel]) onAdd;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: GlassSurface(
        blur: 16,
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _AddBlockMenu(onAdd: onAdd),
              _dividerFor(colors),
              _TypeMenu(block: block, onTypeChanged: onTypeChanged),
              _dividerFor(colors),
              _FormatToggle(
                tooltip: 'Gras',
                icon: Icons.format_bold_rounded,
                selected: block.isBold,
                onPressed: () =>
                    onBlockChanged(block.copyWith(isBold: !block.isBold)),
              ),
              _FormatToggle(
                tooltip: 'Italique',
                icon: Icons.format_italic_rounded,
                selected: block.isItalic,
                onPressed: () =>
                    onBlockChanged(block.copyWith(isItalic: !block.isItalic)),
              ),
              _FormatToggle(
                tooltip: 'Souligner',
                icon: Icons.format_underlined_rounded,
                selected: block.isUnderlined,
                onPressed: () => onBlockChanged(
                  block.copyWith(isUnderlined: !block.isUnderlined),
                ),
              ),
              _FormatToggle(
                tooltip: 'Barrer',
                icon: Icons.format_strikethrough_rounded,
                selected: block.isStruckThrough,
                onPressed: () => onBlockChanged(
                  block.copyWith(isStruckThrough: !block.isStruckThrough),
                ),
              ),
              _ColorMenu(
                tooltip: 'Couleur du texte',
                icon: Icons.format_color_text_rounded,
                values: _textColors,
                selectedValue: block.textColor,
                onSelected: (value) =>
                    onBlockChanged(block.copyWith(textColor: value)),
              ),
              _ColorMenu(
                tooltip: 'Surligner',
                icon: Icons.format_color_fill_rounded,
                values: _highlightColors,
                selectedValue: block.highlightColor,
                onSelected: (value) =>
                    onBlockChanged(block.copyWith(highlightColor: value)),
              ),
              _dividerFor(colors),
              IconButton(
                tooltip: 'Supprimer le bloc',
                onPressed: onDelete,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dividerFor(ColorScheme colors) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: VerticalDivider(color: colors.outlineVariant, width: 1),
      );
}

class _AddBlockMenu extends StatelessWidget {
  const _AddBlockMenu({required this.onAdd});

  final void Function(NoteBlockKind kind, [int headingLevel]) onAdd;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Ajouter un bloc',
        icon: const Icon(Icons.add_rounded),
        onSelected: (value) {
          switch (value) {
            case 'p':
              onAdd(NoteBlockKind.paragraph);
            case 'h':
              onAdd(NoteBlockKind.heading, 2);
            case 'check':
              onAdd(NoteBlockKind.checkbox);
            case 'number':
              onAdd(NoteBlockKind.number);
            case 'ul':
              onAdd(NoteBlockKind.unorderedList);
            case 'ol':
              onAdd(NoteBlockKind.orderedList);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'p',
            child: ListTile(
              leading: Icon(Icons.notes_rounded),
              title: Text('Texte'),
            ),
          ),
          PopupMenuItem(
            value: 'h',
            child: ListTile(
              leading: Icon(Icons.title_rounded),
              title: Text('Titre'),
            ),
          ),
          PopupMenuItem(
            value: 'check',
            child: ListTile(
              leading: Icon(Icons.check_box_outlined),
              title: Text('Case à cocher'),
            ),
          ),
          PopupMenuItem(
            value: 'number',
            child: ListTile(
              leading: Icon(Icons.exposure_plus_1_rounded),
              title: Text('Nombre + unité'),
            ),
          ),
          PopupMenuItem(
            value: 'ul',
            child: ListTile(
              leading: Icon(Icons.format_list_bulleted_rounded),
              title: Text('Liste à puces'),
            ),
          ),
          PopupMenuItem(
            value: 'ol',
            child: ListTile(
              leading: Icon(Icons.format_list_numbered_rounded),
              title: Text('Liste numérotée'),
            ),
          ),
        ],
      );
}

class _TypeMenu extends StatelessWidget {
  const _TypeMenu({required this.block, required this.onTypeChanged});

  final NoteBlock block;
  final void Function(NoteBlockKind kind, [int headingLevel]) onTypeChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Type de bloc',
        onSelected: _applyType,
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'p', child: Text('Texte normal')),
          PopupMenuItem(value: 'h2', child: Text('Titre H2')),
          PopupMenuItem(value: 'h3', child: Text('Titre H3')),
          PopupMenuItem(value: 'h4', child: Text('Titre H4')),
          PopupMenuItem(value: 'h5', child: Text('Titre H5')),
          PopupMenuItem(value: 'h6', child: Text('Titre H6')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'check', child: Text('Case à cocher')),
          PopupMenuItem(value: 'number', child: Text('Nombre + unité')),
          PopupMenuItem(value: 'ul', child: Text('Liste à puces')),
          PopupMenuItem(value: 'ol', child: Text('Liste numérotée')),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              const Icon(Icons.title_rounded, size: 20),
              const SizedBox(width: 6),
              Text(
                _typeLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
      );

  String get _typeLabel => switch (block.kind) {
        NoteBlockKind.heading => 'H${block.headingLevel}',
        NoteBlockKind.checkbox => 'Case',
        NoteBlockKind.number => 'Nombre',
        NoteBlockKind.unorderedList => 'UL',
        NoteBlockKind.orderedList => 'OL',
        NoteBlockKind.paragraph => 'Texte',
      };

  void _applyType(String value) {
    switch (value) {
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        onTypeChanged(NoteBlockKind.heading, int.parse(value.substring(1)));
      case 'check':
        onTypeChanged(NoteBlockKind.checkbox);
      case 'number':
        onTypeChanged(NoteBlockKind.number);
      case 'ul':
        onTypeChanged(NoteBlockKind.unorderedList);
      case 'ol':
        onTypeChanged(NoteBlockKind.orderedList);
      default:
        onTypeChanged(NoteBlockKind.paragraph);
    }
  }
}

class _FormatToggle extends StatelessWidget {
  const _FormatToggle({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        isSelected: selected,
        onPressed: onPressed,
        icon: Icon(icon),
        selectedIcon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
        ),
      );
}

class _ColorMenu extends StatelessWidget {
  const _ColorMenu({
    required this.tooltip,
    required this.icon,
    required this.values,
    required this.selectedValue,
    required this.onSelected,
  });

  final String tooltip;
  final IconData icon;
  final List<int> values;
  final int selectedValue;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
        tooltip: tooltip,
        onSelected: onSelected,
        icon: Icon(icon),
        itemBuilder: (context) => [
          for (final value in values)
            PopupMenuItem(
              value: value,
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value == 0
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                          : Color(value),
                      border: Border.all(
                        color: value == selectedValue
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: value == selectedValue ? 3 : 1,
                      ),
                    ),
                    child: value == selectedValue
                        ? const Icon(Icons.check_rounded, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(value == 0 ? 'Automatique' : 'Couleur'),
                ],
              ),
            ),
        ],
      );
}

class _NoteBlockEditor extends StatefulWidget {
  const _NoteBlockEditor({
    required this.block,
    required this.orderedNumber,
    required this.requestFocus,
    required this.onFocused,
    required this.onChanged,
    required this.onListBreak,
    required this.onListShortcut,
    required this.onBackspaceEmpty,
    super.key,
  });

  final NoteBlock block;
  final int orderedNumber;
  final bool requestFocus;
  final VoidCallback onFocused;
  final ValueChanged<NoteBlock> onChanged;
  final void Function(NoteBlock block, String before, String after) onListBreak;
  final void Function(NoteBlock block, NoteBlockKind kind) onListShortcut;
  final ValueChanged<NoteBlock> onBackspaceEmpty;

  @override
  State<_NoteBlockEditor> createState() => _NoteBlockEditorState();
}

class _NoteBlockEditorState extends State<_NoteBlockEditor> {
  late final TextEditingController _textController;
  late final TextEditingController _numberController;
  late final TextEditingController _unitController;
  late final FocusNode _focusNode;

  bool get _isListLike =>
      widget.block.kind == NoteBlockKind.unorderedList ||
      widget.block.kind == NoteBlockKind.orderedList ||
      widget.block.kind == NoteBlockKind.checkbox;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.block.text);
    _numberController = TextEditingController(
      text: _formatNumber(widget.block.numberValue),
    );
    _unitController = TextEditingController(text: widget.block.unit);
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent)..addListener(_handleFocus);
    if (widget.requestFocus) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focusNode.requestFocus());
    }
  }

  @override
  void didUpdateWidget(covariant _NoteBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A conversion (markdown shortcut / list break) clears or rewrites the
    // controller itself before notifying the parent, so only resync when the
    // field is idle to avoid clobbering text the user is actively typing.
    if (!_focusNode.hasFocus && _textController.text != widget.block.text) {
      _textController.text = widget.block.text;
    }
    if (!_numberController.selection.isValid) {
      _numberController.text = _formatNumber(widget.block.numberValue);
    }
    if (widget.requestFocus && !oldWidget.requestFocus) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    _textController.dispose();
    _numberController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (_focusNode.hasFocus) widget.onFocused();
  }

  /// Backspace at the very start of an empty block removes its marker / merges
  /// it upward, mirroring Google Keep.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _textController.text.isEmpty &&
        widget.block.kind != NoteBlockKind.number) {
      widget.onBackspaceEmpty(widget.block);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Detects the markdown list prefixes (`- `, `* `, `1. `, `1) `) typed at the
  /// very start of a paragraph block.
  NoteBlockKind? _listShortcutFor(String value) {
    if (value == '- ' || value == '* ') return NoteBlockKind.unorderedList;
    if (value == '1. ' || value == '1) ') return NoteBlockKind.orderedList;
    return null;
  }

  void _onTextChanged(String value) {
    // Markdown shortcut: convert an empty paragraph into a list on the prefix.
    if (widget.block.kind == NoteBlockKind.paragraph) {
      final shortcut = _listShortcutFor(value);
      if (shortcut != null) {
        _textController.clear();
        widget.onListShortcut(widget.block, shortcut);
        return;
      }
    }

    // Enter inside a list/checkbox splits into a new item (or ends the list).
    if (_isListLike && value.contains('\n')) {
      final breakIndex = value.indexOf('\n');
      final before = value.substring(0, breakIndex);
      final after = value.substring(breakIndex + 1);
      _textController
        ..text = before
        ..selection = TextSelection.collapsed(offset: before.length);
      widget.onListBreak(widget.block, before, after);
      return;
    }

    widget.onChanged(widget.block.copyWith(text: value));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: _buildBlockContent(context),
      );

  Widget _buildBlockContent(BuildContext context) {
    final block = widget.block;
    final textField = _textField(context);
    return switch (block.kind) {
      NoteBlockKind.checkbox => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox.square(
                dimension: 24,
                child: Checkbox.adaptive(
                  value: block.isChecked,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => widget.onChanged(
                    block.copyWith(isChecked: value ?? false),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: textField),
          ],
        ),
      NoteBlockKind.unorderedList => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 10, right: 10),
              child: Text('•', style: TextStyle(fontSize: 20)),
            ),
            Expanded(child: textField),
          ],
        ),
      NoteBlockKind.orderedList => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 11, right: 8),
              child: Text(
                '${widget.orderedNumber}.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(child: textField),
          ],
        ),
      NoteBlockKind.number => _numberBlock(context),
      _ => textField,
    };
  }

  Widget _textField(BuildContext context) => TextField(
        controller: _textController,
        focusNode: _focusNode,
        maxLines: null,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        style: _noteBlockTextStyle(context, widget.block),
        decoration: InputDecoration(
          hintText: widget.block.kind == NoteBlockKind.heading
              ? 'Titre H${widget.block.headingLevel}'
              : 'Écrivez ici…',
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
        ),
        onChanged: _onTextChanged,
      );

  Widget _numberBlock(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _textField(context),
          Row(
            children: [
              IconButton(
                tooltip: 'Diminuer',
                visualDensity: VisualDensity.compact,
                onPressed: () => _increment(-1),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _numberController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed != null) {
                      widget.onChanged(
                          widget.block.copyWith(numberValue: parsed));
                    }
                  },
                ),
              ),
              IconButton(
                tooltip: 'Augmenter',
                visualDensity: VisualDensity.compact,
                onPressed: () => _increment(1),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'unité (kg, €, min…)',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (value) =>
                      widget.onChanged(widget.block.copyWith(unit: value)),
                ),
              ),
            ],
          ),
        ],
      );

  void _increment(double amount) {
    final current =
        double.tryParse(_numberController.text.replaceAll(',', '.')) ??
            widget.block.numberValue;
    final updated = current + amount;
    _numberController.text = _formatNumber(updated);
    _numberController.selection = TextSelection.collapsed(
      offset: _numberController.text.length,
    );
    widget.onChanged(widget.block.copyWith(numberValue: updated));
  }

  String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
