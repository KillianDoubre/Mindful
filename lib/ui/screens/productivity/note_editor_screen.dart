import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/models/note_document.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/providers/productivity/productivity_items_provider.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/mindful_background.dart';
import 'package:mindful/ui/screens/productivity/note_edit_icon.dart';

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

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.note,
    this.startInEditMode = false,
  });

  final ProductivityItem? note;
  final bool startInEditMode;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late List<NoteBlock> _blocks;
  late int _noteColorValue;
  late String _savedTitle;
  late List<NoteBlock> _savedBlocks;
  late int _savedNoteColorValue;
  late bool _isEditing;

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
    _savedTitle = widget.note?.title ?? '';
    _savedBlocks = [..._blocks];
    _savedNoteColorValue = _noteColorValue;
    _isEditing = widget.note == null || widget.startInEditMode;
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
    final colors = Theme.of(context).colorScheme;
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
          title: Text(
            widget.note == null
                ? 'Nouvelle note'
                : (_isEditing ? 'Modifier la note' : 'Note'),
          ),
          actions: [
            if (!_isEditing)
              IconButton(
                tooltip: 'Modifier la note',
                onPressed: _enterEditMode,
                icon: const NoteEditIcon(),
              ),
            if (_isEditing && widget.note != null)
              IconButton(
                tooltip: 'Supprimer la note',
                onPressed: _confirmDelete,
                icon: Icon(Icons.delete_outline_rounded, color: colors.error),
              ),
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
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
            if (_isEditing)
              Column(
                children: [
                  _buildTitleAndNoteColor(context),
                  if (activeBlock != null)
                    _FormattingToolbar(
                      block: activeBlock,
                      onTypeChanged: _changeActiveBlockType,
                      onChanged: _replaceBlock,
                    ),
                  Expanded(child: _buildBlocksList()),
                  _AddBlockBar(onAdd: _insertBlock),
                ],
              )
            else
              _buildReadOnlyView(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleAndNoteColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: GlassSurface(
        showShadow: false,
        color: _resolveNoteColor(theme, _noteColorValue),
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: 'Titre de la note',
                border: InputBorder.none,
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _noteColors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final value = _noteColors[index];
                  final isSelected = value == _noteColorValue;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label:
                        value == 0 ? 'Couleur automatique' : 'Couleur de note',
                    child: InkWell(
                      onTap: () {
                        setState(() => _noteColorValue = value);
                        _markDirty();
                      },
                      customBorder: const CircleBorder(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: value == 0
                              ? colors.surfaceContainerHighest
                              : Color(value),
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : colors.outlineVariant,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: isSelected
                            ? Icon(Icons.check_rounded,
                                size: 18, color: colors.onSurface)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyView(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        GlassSurface(
          color: _resolveNoteColor(theme, _noteColorValue),
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                _titleController.text,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: colors.outlineVariant.withValues(alpha: 0.65)),
              const SizedBox(height: 10),
              for (var index = 0; index < _blocks.length; index++)
                _ReadOnlyNoteBlock(
                  block: _blocks[index],
                  orderedNumber: _orderedNumberAt(index),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _enterEditMode,
          icon: NoteEditIcon(color: colors.onPrimary),
          label: const Text('Modifier cette note'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlocksList() => ReorderableListView.builder(
        buildDefaultDragHandles: false,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        itemCount: _blocks.length,
        onReorderItem: (oldIndex, newIndex) {
          if (oldIndex == newIndex) return;
          setState(() {
            final block = _blocks.removeAt(oldIndex);
            _blocks.insert(newIndex, block);
          });
          HapticFeedback.selectionClick();
          _markDirty();
        },
        proxyDecorator: (child, _, animation) => AnimatedBuilder(
          animation: animation,
          builder: (context, _) => Transform.scale(
            scale: 1 + animation.value * 0.025,
            child: Material(
              color: Colors.transparent,
              elevation: animation.value * 8,
              borderRadius: BorderRadius.circular(20),
              child: child,
            ),
          ),
        ),
        itemBuilder: (context, index) {
          final block = _blocks[index];
          return Padding(
            key: ValueKey(block.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: _NoteBlockEditor(
              block: block,
              index: index,
              orderedNumber: _orderedNumberAt(index),
              isActive: block.id == _activeBlockId,
              requestFocus: block.id == _focusBlockId,
              onFocused: () => setState(() {
                _activeBlockId = block.id;
                _focusBlockId = null;
              }),
              onChanged: _replaceBlock,
              onDelete: () => _removeBlock(block),
            ),
          );
        },
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
    if (_isEditing && !_isDirty && mounted) {
      setState(() => _isDirty = true);
    }
  }

  void _enterEditMode() {
    setState(() {
      _isEditing = true;
      _activeBlockId = _blocks.firstOrNull?.id;
    });
  }

  void _restoreSavedVersion() {
    setState(() {
      _isEditing = false;
      _isDirty = false;
      _blocks = [..._savedBlocks];
      _noteColorValue = _savedNoteColorValue;
      _activeBlockId = _blocks.firstOrNull?.id;
      _focusBlockId = null;
    });
    _titleController.text = _savedTitle;
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
      _savedTitle = title;
      _savedBlocks = [..._blocks];
      _savedNoteColorValue = _noteColorValue;
      if (widget.note == null) {
        setState(() => _isDirty = false);
        await Future<void>.delayed(Duration.zero);
        if (mounted) Navigator.pop(context);
      } else {
        setState(() {
          _isDirty = false;
          _isEditing = false;
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
      if (_isEditing && widget.note != null) {
        setState(() => _isEditing = false);
      } else {
        Navigator.pop(context);
      }
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
      if (widget.note != null) {
        _restoreSavedVersion();
      } else {
        setState(() => _isDirty = false);
        await Future<void>.delayed(Duration.zero);
        if (mounted) Navigator.pop(context);
      }
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

class _ReadOnlyNoteBlock extends StatelessWidget {
  const _ReadOnlyNoteBlock({
    required this.block,
    required this.orderedNumber,
  });

  final NoteBlock block;
  final int orderedNumber;

  @override
  Widget build(BuildContext context) {
    final style = _noteBlockTextStyle(context, block);
    final text = block.text.trim();
    final content = switch (block.kind) {
      NoteBlockKind.checkbox => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 10),
              child: Icon(
                block.isChecked
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 22,
              ),
            ),
            Expanded(child: SelectableText(text, style: style)),
          ],
        ),
      NoteBlockKind.unorderedList => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Text('•', style: TextStyle(fontSize: 22)),
            ),
            Expanded(child: SelectableText(text, style: style)),
          ],
        ),
      NoteBlockKind.orderedList => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: Text(
                '$orderedNumber.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(child: SelectableText(text, style: style)),
          ],
        ),
      NoteBlockKind.number => _ReadOnlyNumberBlock(block: block, style: style),
      _ => SelectableText(text, style: style),
    };

    if (text.isEmpty && block.kind != NoteBlockKind.number) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: block.kind == NoteBlockKind.heading ? 16 : 12,
      ),
      child: content,
    );
  }
}

class _ReadOnlyNumberBlock extends StatelessWidget {
  const _ReadOnlyNumberBlock({required this.block, required this.style});

  final NoteBlock block;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = block.numberValue == block.numberValue.roundToDouble()
        ? block.numberValue.toInt().toString()
        : block.numberValue.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.text.trim().isNotEmpty) ...[
          SelectableText(block.text.trim(), style: style),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            [value, block.unit.trim()]
                .where((part) => part.isNotEmpty)
                .join(' '),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
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

class _FormattingToolbar extends StatelessWidget {
  const _FormattingToolbar({
    required this.block,
    required this.onTypeChanged,
    required this.onChanged,
  });

  final NoteBlock block;
  final void Function(NoteBlockKind kind, [int headingLevel]) onTypeChanged;
  final ValueChanged<NoteBlock> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GlassSurface(
        showShadow: false,
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              PopupMenuButton<String>(
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
              ),
              VerticalDivider(color: colors.outlineVariant),
              _FormatToggle(
                tooltip: 'Gras',
                icon: Icons.format_bold_rounded,
                selected: block.isBold,
                onPressed: () =>
                    onChanged(block.copyWith(isBold: !block.isBold)),
              ),
              _FormatToggle(
                tooltip: 'Italique',
                icon: Icons.format_italic_rounded,
                selected: block.isItalic,
                onPressed: () =>
                    onChanged(block.copyWith(isItalic: !block.isItalic)),
              ),
              _FormatToggle(
                tooltip: 'Souligner',
                icon: Icons.format_underlined_rounded,
                selected: block.isUnderlined,
                onPressed: () => onChanged(
                  block.copyWith(isUnderlined: !block.isUnderlined),
                ),
              ),
              _FormatToggle(
                tooltip: 'Barrer',
                icon: Icons.format_strikethrough_rounded,
                selected: block.isStruckThrough,
                onPressed: () => onChanged(
                  block.copyWith(isStruckThrough: !block.isStruckThrough),
                ),
              ),
              _ColorMenu(
                tooltip: 'Couleur du texte',
                icon: Icons.format_color_text_rounded,
                values: _textColors,
                selectedValue: block.textColor,
                onSelected: (value) =>
                    onChanged(block.copyWith(textColor: value)),
              ),
              _ColorMenu(
                tooltip: 'Surligner',
                icon: Icons.format_color_fill_rounded,
                values: _highlightColors,
                selectedValue: block.highlightColor,
                onSelected: (value) =>
                    onChanged(block.copyWith(highlightColor: value)),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
        return;
      case 'check':
        onTypeChanged(NoteBlockKind.checkbox);
        return;
      case 'number':
        onTypeChanged(NoteBlockKind.number);
        return;
      case 'ul':
        onTypeChanged(NoteBlockKind.unorderedList);
        return;
      case 'ol':
        onTypeChanged(NoteBlockKind.orderedList);
        return;
      default:
        onTypeChanged(NoteBlockKind.paragraph);
        return;
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

class _AddBlockBar extends StatelessWidget {
  const _AddBlockBar({required this.onAdd});

  final void Function(NoteBlockKind kind, [int headingLevel]) onAdd;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: GlassSurface(
          blur: 16,
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _AddBlockButton(
                  icon: Icons.notes_rounded,
                  label: 'Texte',
                  onTap: () => onAdd(NoteBlockKind.paragraph),
                ),
                _AddBlockButton(
                  icon: Icons.title_rounded,
                  label: 'Titre',
                  onTap: () => onAdd(NoteBlockKind.heading, 2),
                ),
                _AddBlockButton(
                  icon: Icons.check_box_outlined,
                  label: 'Case',
                  onTap: () => onAdd(NoteBlockKind.checkbox),
                ),
                _AddBlockButton(
                  icon: Icons.exposure_plus_1_rounded,
                  label: 'Nombre',
                  onTap: () => onAdd(NoteBlockKind.number),
                ),
                _AddBlockButton(
                  icon: Icons.format_list_bulleted_rounded,
                  label: 'UL',
                  onTap: () => onAdd(NoteBlockKind.unorderedList),
                ),
                _AddBlockButton(
                  icon: Icons.format_list_numbered_rounded,
                  label: 'OL',
                  onTap: () => onAdd(NoteBlockKind.orderedList),
                ),
              ],
            ),
          ),
        ),
      );
}

class _AddBlockButton extends StatelessWidget {
  const _AddBlockButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
}

class _NoteBlockEditor extends StatefulWidget {
  const _NoteBlockEditor({
    required this.block,
    required this.index,
    required this.orderedNumber,
    required this.isActive,
    required this.requestFocus,
    required this.onFocused,
    required this.onChanged,
    required this.onDelete,
  });

  final NoteBlock block;
  final int index;
  final int orderedNumber;
  final bool isActive;
  final bool requestFocus;
  final VoidCallback onFocused;
  final ValueChanged<NoteBlock> onChanged;
  final VoidCallback onDelete;

  @override
  State<_NoteBlockEditor> createState() => _NoteBlockEditorState();
}

class _NoteBlockEditorState extends State<_NoteBlockEditor> {
  late final TextEditingController _textController;
  late final TextEditingController _numberController;
  late final TextEditingController _unitController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.block.text);
    _numberController = TextEditingController(
      text: _formatNumber(widget.block.numberValue),
    );
    _unitController = TextEditingController(text: widget.block.unit);
    _focusNode = FocusNode()..addListener(_handleFocus);
    if (widget.requestFocus) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focusNode.requestFocus());
    }
  }

  @override
  void didUpdateWidget(covariant _NoteBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassSurface(
      showShadow: false,
      color: widget.isActive
          ? colors.primaryContainer.withValues(alpha: 0.78)
          : colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildBlockContent(context)),
          Column(
            children: [
              ReorderableDragStartListener(
                index: widget.index,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Supprimer le bloc',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onDelete,
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockContent(BuildContext context) {
    final block = widget.block;
    final textField = _textField(context);
    return switch (block.kind) {
      NoteBlockKind.checkbox => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox.adaptive(
              value: block.isChecked,
              onChanged: (value) => widget.onChanged(
                block.copyWith(isChecked: value ?? false),
              ),
            ),
            Expanded(child: textField),
          ],
        ),
      NoteBlockKind.unorderedList => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 12, 8, 0),
              child: Text('•', style: TextStyle(fontSize: 22)),
            ),
            Expanded(child: textField),
          ],
        ),
      NoteBlockKind.orderedList => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 13, 8, 0),
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
        minLines: widget.block.kind == NoteBlockKind.heading ? 1 : 2,
        textCapitalization: TextCapitalization.sentences,
        style: _noteBlockTextStyle(context, widget.block),
        decoration: InputDecoration(
          hintText: widget.block.kind == NoteBlockKind.heading
              ? 'Votre titre H${widget.block.headingLevel}'
              : 'Écrivez ici…',
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        onChanged: (value) =>
            widget.onChanged(widget.block.copyWith(text: value)),
      );

  Widget _numberBlock(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _textField(context),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Diminuer',
                onPressed: () => _increment(-1),
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 94,
                child: TextField(
                  controller: _numberController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Valeur',
                    filled: true,
                    fillColor: colors.surface.withValues(alpha: 0.45),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
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
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Augmenter',
                onPressed: () => _increment(1),
                icon: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  decoration: InputDecoration(
                    labelText: 'Unité',
                    hintText: 'kg, €, min…',
                    filled: true,
                    fillColor: colors.surface.withValues(alpha: 0.45),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) =>
                      widget.onChanged(widget.block.copyWith(unit: value)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
