import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/models/note_document.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/providers/productivity/productivity_items_provider.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/mindful_background.dart';
import 'package:mindful/ui/common/page_app_bar.dart';

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

const _frenchMonths = <String>[
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// What happened to the note when the editor closed, so the notes list can
/// show the matching feedback.
class NoteEditorResult {
  const NoteEditorResult.deleted(int this.deletedNoteId)
      : discardedEmpty = false;

  const NoteEditorResult.discardedEmpty()
      : deletedNoteId = null,
        discardedEmpty = true;

  /// Id of the note the user deleted from the editor (undoable).
  final int? deletedNoteId;

  /// The note ended up empty and was dropped.
  final bool discardedEmpty;
}

/// A full-screen, always-editable note canvas that behaves like Google Keep.
///
/// Reading and editing share the exact same surface, and there is no save
/// button: every change is written shortly after it happens and again when
/// leaving. A note left without title and content is discarded on close.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.note,
  });

  final ProductivityItem? note;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteSnapshot {
  const _NoteSnapshot({
    required this.title,
    required this.blocks,
    required this.colorValue,
  });

  final String title;
  final List<NoteBlock> blocks;
  final int colorValue;
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen>
    with WidgetsBindingObserver {
  static const _autoSaveDelay = Duration(milliseconds: 600);

  /// Edits closer together than this collapse into one undo step.
  static const _historyMergeWindow = Duration(seconds: 1);
  static const _maxHistory = 100;

  late final ProductivityItemsNotifier _notes;
  late final TextEditingController _titleController;
  late List<NoteBlock> _blocks;
  late int _noteColorValue;
  late bool _isPinned;
  late String _title;
  int? _noteId;
  DateTime? _updatedAt;

  String? _activeBlockId;
  String? _focusBlockId;
  bool _showFormatting = false;
  bool _showCheckedItems = true;

  Timer? _saveTimer;
  Future<void> _saveQueue = Future.value();
  bool _hasUnsavedChanges = false;
  bool _hasEdited = false;
  bool _isClosing = false;

  final List<_NoteSnapshot> _history = [];
  int _historyIndex = 0;
  DateTime _lastHistoryAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isRestoring = false;

  /// Bumped on undo/redo so every block editor remounts with restored text.
  int _revision = 0;

  NoteBlock? get _activeBlock {
    final id = _activeBlockId;
    if (id == null) return _blocks.firstOrNull;
    return _blocks.where((block) => block.id == id).firstOrNull ??
        _blocks.firstOrNull;
  }

  bool get _isEmpty =>
      _title.trim().isEmpty &&
      _blocks.every(
        (block) =>
            block.text.trim().isEmpty &&
            (block.kind != NoteBlockKind.number ||
                (block.numberValue == 0 && block.unit.trim().isEmpty)),
      );

  bool get _canUndo => _historyIndex > 0;

  bool get _canRedo => _historyIndex < _history.length - 1;

  @override
  void initState() {
    super.initState();
    _notes = ref.read(
      productivityItemsProvider(ProductivityItemType.note).notifier,
    );
    _title = widget.note?.title ?? '';
    _titleController = TextEditingController(text: _title);
    _blocks = NoteDocument.decode(widget.note?.details ?? '').blocks.toList();
    _noteColorValue = widget.note?.colorValue ?? 0;
    _isPinned = widget.note?.isPinned ?? false;
    _noteId = widget.note?.id;
    _updatedAt = widget.note?.updatedAt;
    _activeBlockId = _blocks.firstOrNull?.id;
    // A new note opens ready to type, like Keep
    if (widget.note == null) _focusBlockId = _blocks.firstOrNull?.id;
    _history.add(_snapshot());
    _titleController.addListener(_onTitleChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    // Route removed without going through _close (e.g. a deep link)
    if (_hasUnsavedChanges && !_isClosing) _flush();
    _titleController
      ..removeListener(_onTitleChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeBlock = _activeBlock;

    // Checked items sink to their own section; the stored order is kept so
    // unchecking puts an item back where it was.
    final openIndexes = <int>[];
    final checkedIndexes = <int>[];
    for (var index = 0; index < _blocks.length; index++) {
      final block = _blocks[index];
      (block.kind == NoteBlockKind.checkbox && block.isChecked
              ? checkedIndexes
              : openIndexes)
          .add(index);
    }

    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        // The app background sits behind the whole page, app bar included
        child: Stack(
          fit: StackFit.expand,
          children: [
            const MindfulBackground(),
            if (_noteColorValue != 0)
              ColoredBox(
                color: Color(_noteColorValue).withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.16 : 0.45,
                ),
              ),
            Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: true,
              appBar: PageAppBar(
                leading: IconButton(
                  tooltip: 'Retour',
                  onPressed: _close,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                actions: [
                  IconButton(
                    tooltip: _isPinned ? 'Désépingler' : 'Épingler',
                    onPressed: _togglePinned,
                    isSelected: _isPinned,
                    icon: const Icon(Icons.push_pin_outlined),
                    selectedIcon: const Icon(Icons.push_pin_rounded),
                  ),
                  PopupMenuButton<String>(
                    tooltip: "Plus d'options",
                    onSelected: (value) {
                      if (value == 'delete') _deleteNote();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Supprimer la note'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          // Keep the keyboard (and any active text selection) alive
                          // while scrolling — onDrag would dismiss both.
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.manual,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTitleField(theme),
                                const SizedBox(height: 4),
                                for (final index in openIndexes)
                                  _buildBlockEditor(index),
                                if (checkedIndexes.isNotEmpty) ...[
                                  _CheckedItemsHeader(
                                    count: checkedIndexes.length,
                                    isExpanded: _showCheckedItems,
                                    onTap: () => setState(
                                      () => _showCheckedItems =
                                          !_showCheckedItems,
                                    ),
                                  ),
                                  if (_showCheckedItems)
                                    for (final index in checkedIndexes)
                                      _buildBlockEditor(index),
                                ],
                              ],
                            ),
                            // Tapping below the note continues writing at its end
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _focusEnd,
                              child: const SizedBox(height: 160),
                            ),
                          ],
                        ),
                      ),
                      if (_showFormatting && activeBlock != null)
                        _FormattingBar(
                          block: activeBlock,
                          onTypeChanged: _changeActiveBlockType,
                          onBlockChanged: _replaceBlock,
                          onDelete: () => _removeBlock(activeBlock),
                        ),
                      _NoteBottomBar(
                        noteColorValue: _noteColorValue,
                        isFormattingOpen: _showFormatting,
                        editedLabel: _editedLabel,
                        canUndo: _canUndo,
                        canRedo: _canRedo,
                        onAdd: _insertBlock,
                        onColorSelected: _changeNoteColor,
                        onToggleFormatting: () =>
                            setState(() => _showFormatting = !_showFormatting),
                        onUndo: () => _restoreHistory(_historyIndex - 1),
                        onRedo: () => _restoreHistory(_historyIndex + 1),
                      ),
                    ],
                  ),
                ],
              ),
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

  Widget _buildBlockEditor(int index) {
    final block = _blocks[index];
    return _NoteBlockEditor(
      key: ValueKey('${block.id}#$_revision'),
      block: block,
      orderedNumber: _orderedNumberAt(index),
      requestFocus: block.id == _focusBlockId,
      onFocused: () => setState(() {
        _activeBlockId = block.id;
        _focusBlockId = null;
      }),
      onChanged: _replaceBlock,
      onListBreak: _handleListBreak,
      onListShortcut: _applyListShortcut,
      onBackspaceEmpty: _handleBackspaceEmpty,
    );
  }

  String get _editedLabel {
    final at = _updatedAt;
    if (at == null) return '';
    final now = DateTime.now();
    final time = '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(at.year, at.month, at.day))
        .inDays;
    if (days == 0) return 'Modifié à $time';
    if (days == 1) return 'Modifié hier à $time';
    final date = '${at.day} ${_frenchMonths[at.month - 1]}';
    return at.year == now.year
        ? 'Modifié le $date'
        : 'Modifié le $date ${at.year}';
  }

  int _orderedNumberAt(int index) {
    var number = 0;
    for (var current = index; current >= 0; current--) {
      if (_blocks[current].kind != NoteBlockKind.orderedList) break;
      number++;
    }
    return number;
  }

  // ---------------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------------

  void _onTitleChanged() {
    // The listener also fires on cursor moves
    if (_isRestoring || _titleController.text == _title) return;
    _title = _titleController.text;
    _onContentChanged(mergeWithPrevious: true);
  }

  void _replaceBlock(NoteBlock updated) {
    final index = _blocks.indexWhere((block) => block.id == updated.id);
    if (index < 0) return;
    final previous = _blocks[index];
    // Plain typing is merged into one undo step; any other change is its own
    final isTypingOnly = jsonEncode(
          updated
              .copyWith(
                text: previous.text,
                numberValue: previous.numberValue,
                unit: previous.unit,
              )
              .toJson(),
        ) ==
        jsonEncode(previous.toJson());
    setState(() {
      _blocks[index] = updated;
      _activeBlockId = updated.id;
    });
    _onContentChanged(mergeWithPrevious: isTypingOnly);
  }

  void _changeActiveBlockType(NoteBlockKind kind, [int headingLevel = 2]) {
    final block = _activeBlock;
    if (block == null) return;
    _replaceBlock(block.copyWith(kind: kind, headingLevel: headingLevel));
  }

  void _changeNoteColor(int value) {
    setState(() => _noteColorValue = value);
    _onContentChanged();
  }

  void _togglePinned() {
    setState(() => _isPinned = !_isPinned);
    _hasUnsavedChanges = true;
    _scheduleSave();
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
    _onContentChanged();
  }

  /// Puts the cursor at the end of the note, adding a text line if the last
  /// block is not an empty paragraph.
  void _focusEnd() {
    final last = _blocks.lastOrNull;
    if (last != null &&
        last.kind == NoteBlockKind.paragraph &&
        last.text.isEmpty) {
      setState(() {
        _activeBlockId = last.id;
        _focusBlockId = last.id;
        _revision++;
      });
      return;
    }
    _activeBlockId = last?.id;
    _insertBlock(NoteBlockKind.paragraph);
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
      _onContentChanged();
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
    _onContentChanged();
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
      _onContentChanged();
      return;
    }

    if (index > 0) {
      final previous = _blocks[index - 1];
      setState(() {
        _blocks.removeAt(index);
        _activeBlockId = previous.id;
        _focusBlockId = previous.id;
      });
      _onContentChanged();
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
    _onContentChanged();
  }

  // ---------------------------------------------------------------------------
  // Undo / redo
  // ---------------------------------------------------------------------------

  _NoteSnapshot _snapshot() => _NoteSnapshot(
        title: _title,
        blocks: List.of(_blocks),
        colorValue: _noteColorValue,
      );

  void _onContentChanged({bool mergeWithPrevious = false}) {
    if (_isRestoring) return;
    _recordHistory(mergeWithPrevious: mergeWithPrevious);
    _hasEdited = true;
    _hasUnsavedChanges = true;
    _scheduleSave();
  }

  void _recordHistory({required bool mergeWithPrevious}) {
    final now = DateTime.now();
    final canMerge = mergeWithPrevious &&
        _historyIndex > 0 &&
        _historyIndex == _history.length - 1 &&
        now.difference(_lastHistoryAt) < _historyMergeWindow;
    setState(() {
      if (canMerge) {
        _history[_historyIndex] = _snapshot();
      } else {
        _history
          ..removeRange(_historyIndex + 1, _history.length)
          ..add(_snapshot());
        if (_history.length > _maxHistory) _history.removeAt(0);
        _historyIndex = _history.length - 1;
      }
    });
    _lastHistoryAt = now;
  }

  void _restoreHistory(int index) {
    if (index < 0 || index >= _history.length) return;
    final snapshot = _history[index];
    FocusScope.of(context).unfocus();

    _isRestoring = true;
    _title = snapshot.title;
    _titleController.text = snapshot.title;
    _isRestoring = false;

    setState(() {
      _historyIndex = index;
      _blocks = List.of(snapshot.blocks);
      _noteColorValue = snapshot.colorValue;
      _activeBlockId = _blocks.firstOrNull?.id;
      _focusBlockId = null;
      _revision++;
    });
    // The next edit starts a fresh undo step
    _lastHistoryAt = DateTime.fromMillisecondsSinceEpoch(0);
    _hasEdited = true;
    _hasUnsavedChanges = true;
    _scheduleSave();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_autoSaveDelay, _flush);
  }

  /// Writes pending changes. Saves are chained so a new note is only
  /// inserted once, every later save updating that same row.
  Future<void> _flush() {
    _saveTimer?.cancel();
    return _saveQueue = _saveQueue.then((_) => _persist());
  }

  Future<void> _persist() async {
    if (!_hasUnsavedChanges) return;
    _hasUnsavedChanges = false;
    // Empty notes are never written; they are dropped on close instead
    if (_isEmpty) return;

    try {
      _noteId = await _notes.save(
        ProductivityItemDraft(
          title: _title,
          details: NoteDocument(List.of(_blocks)).encode(),
          colorValue: _noteColorValue,
          isPinned: _isPinned,
        ),
        id: _noteId,
      );
      if (mounted) setState(() => _updatedAt = DateTime.now());
    } catch (_) {
      _hasUnsavedChanges = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text("La note n'a pas pu être enregistrée."),
          ),
        );
    }
  }

  Future<void> _close() async {
    if (_isClosing) return;
    _isClosing = true;
    await _flush();

    NoteEditorResult? result;
    if (_isEmpty) {
      final id = _noteId;
      if (id != null) await _notes.deleteById(id);
      if (id != null || _hasEdited) {
        result = const NoteEditorResult.discardedEmpty();
      }
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _deleteNote() async {
    if (_isClosing) return;
    _isClosing = true;
    await _flush();
    if (!mounted) return;
    final id = _noteId;
    // The list performs the deletion so it can offer to undo it
    Navigator.of(context).pop(id == null ? null : NoteEditorResult.deleted(id));
  }
}

/// Divider row above checked items, collapsible like Keep's
/// "N checked items".
class _CheckedItemsHeader extends StatelessWidget {
  const _CheckedItemsHeader({
    required this.count,
    required this.isExpanded,
    required this.onTap,
  });

  final int count;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Divider(height: 1, color: colors.outlineVariant),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.expand_more_rounded
                      : Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  count == 1 ? '1 élément coché' : '$count éléments cochés',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Keep-style bottom bar: add, colour and formatting on the left, the last
/// edit time in the middle, undo/redo on the right.
class _NoteBottomBar extends StatelessWidget {
  const _NoteBottomBar({
    required this.noteColorValue,
    required this.isFormattingOpen,
    required this.editedLabel,
    required this.canUndo,
    required this.canRedo,
    required this.onAdd,
    required this.onColorSelected,
    required this.onToggleFormatting,
    required this.onUndo,
    required this.onRedo,
  });

  final int noteColorValue;
  final bool isFormattingOpen;
  final String editedLabel;
  final bool canUndo;
  final bool canRedo;
  final void Function(NoteBlockKind kind, [int headingLevel]) onAdd;
  final ValueChanged<int> onColorSelected;
  final VoidCallback onToggleFormatting;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: GlassSurface(
        blur: 16,
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            _AddBlockMenu(onAdd: onAdd),
            _ColorMenu(
              tooltip: 'Couleur de la note',
              icon: Icons.palette_outlined,
              values: _noteColors,
              selectedValue: noteColorValue,
              onSelected: onColorSelected,
            ),
            _FormatToggle(
              tooltip: 'Mise en forme',
              icon: Icons.text_format_rounded,
              selected: isFormattingOpen,
              onPressed: onToggleFormatting,
            ),
            Expanded(
              child: Text(
                editedLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'Annuler',
              onPressed: canUndo ? onUndo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: 'Rétablir',
              onPressed: canRedo ? onRedo : null,
              icon: const Icon(Icons.redo_rounded),
            ),
          ],
        ),
      ),
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

/// Formatting row for the active block, shown above the bottom bar when the
/// "Aa" button is on. Hidden by default so reading stays uncluttered.
class _FormattingBar extends StatelessWidget {
  const _FormattingBar({
    required this.block,
    required this.onTypeChanged,
    required this.onBlockChanged,
    required this.onDelete,
  });

  final NoteBlock block;
  final void Function(NoteBlockKind kind, [int headingLevel]) onTypeChanged;
  final ValueChanged<NoteBlock> onBlockChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      bottom: false,
      minimum: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: GlassSurface(
        blur: 16,
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
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
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent)
      ..addListener(_handleFocus);
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

  TextStyle _textStyle(BuildContext context) {
    final style = _noteBlockTextStyle(context, widget.block);
    if (widget.block.kind != NoteBlockKind.checkbox ||
        !widget.block.isChecked) {
      return style;
    }
    return style.copyWith(
      color: style.color?.withValues(alpha: 0.55),
      decoration: TextDecoration.lineThrough,
    );
  }

  Widget _textField(BuildContext context) => TextField(
        controller: _textController,
        focusNode: _focusNode,
        maxLines: null,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        style: _textStyle(context),
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
