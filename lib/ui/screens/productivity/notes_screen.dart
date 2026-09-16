import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/models/note_document.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/providers/productivity/productivity_items_provider.dart';
import 'package:mindful/ui/common/default_fab_button.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/scaffold_shell.dart';
import 'package:mindful/ui/common/sliver_tabs_bottom_padding.dart';
import 'package:mindful/ui/screens/productivity/context_menu_card.dart';
import 'package:mindful/ui/screens/productivity/note_editor_screen.dart';

const _gridSpacing = 10.0;

/// Google-Keep-like notes home: a two-column masonry of note cards, pinned
/// notes first, long-press to drag a card elsewhere.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  ProductivityItemsNotifier get _notifier => ref.read(
        productivityItemsProvider(ProductivityItemType.note).notifier,
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(
      productivityItemsProvider(ProductivityItemType.note),
    );

    return ScaffoldShell(
      items: [
        NavbarItem(
          icon: FluentIcons.note_20_regular,
          filledIcon: FluentIcons.note_20_filled,
          titleText: 'Notes',
          fab: DefaultFabButton(
            heroTag: 'newNoteFab',
            label: 'Nouvelle note',
            icon: FluentIcons.add_20_filled,
            onPressed: () => _openEditor(null),
          ),
          sliverBody: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildSearchField()),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              ...notes.when(
                loading: () => [
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (_, __) => [
                  _EmptyProductivityState(
                    icon: FluentIcons.warning_24_regular,
                    title: 'Impossible de charger les notes',
                    subtitle: 'Touchez pour réessayer.',
                    onTap: () => _notifier.refresh(),
                  ),
                ],
                data: _buildNotesSlivers,
              ),
              const SliverTabsBottomPadding(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    final colors = Theme.of(context).colorScheme;
    return GlassSurface(
      showShadow: false,
      borderRadius: BorderRadius.circular(28),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value.trim()),
        decoration: InputDecoration(
          hintText: 'Rechercher dans vos notes',
          prefixIcon: const Icon(FluentIcons.search_20_regular),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Effacer la recherche',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(FluentIcons.dismiss_circle_20_regular),
                ),
          border: InputBorder.none,
          filled: true,
          fillColor: colors.surfaceContainerHigh.withValues(alpha: 0.18),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  List<Widget> _buildNotesSlivers(List<ProductivityItem> allNotes) {
    final query = _query.toLowerCase();
    final isSearching = query.isNotEmpty;
    final visibleNotes = !isSearching
        ? allNotes
        : allNotes
            .where(
              (note) =>
                  note.title.toLowerCase().contains(query) ||
                  NoteDocument.decode(note.details)
                      .plainText
                      .toLowerCase()
                      .contains(query),
            )
            .toList();

    if (visibleNotes.isEmpty) {
      return [
        _EmptyProductivityState(
          icon: isSearching
              ? FluentIcons.search_24_regular
              : FluentIcons.note_add_24_regular,
          title: isSearching ? 'Aucune note trouvée' : 'Une idée à garder ?',
          subtitle: isSearching
              ? 'Essayez une autre recherche.'
              : 'Les notes que vous créez s’affichent ici.',
          onTap: isSearching ? null : () => _openEditor(null),
        ),
      ];
    }

    final pinned = visibleNotes.where((note) => note.isPinned).toList();
    final others = visibleNotes.where((note) => !note.isPinned).toList();

    Widget grid(List<ProductivityItem> notes) => SliverToBoxAdapter(
          child: _NotesMasonry(
            notes: notes,
            canReorder: !isSearching,
            onOpen: _openEditor,
            onTogglePin: _notifier.togglePinned,
            onDelete: (note) => _deleteWithUndo(note.id),
            onDropOnto: (draggedId, target) =>
                _moveNote(allNotes, draggedId, target),
          ),
        );

    return [
      if (pinned.isNotEmpty) ...[
        const _SectionLabel('Épinglées'),
        grid(pinned),
        if (others.isNotEmpty) const _SectionLabel('Autres'),
      ],
      if (others.isNotEmpty) grid(others),
    ];
  }

  /// Moves the dragged note to the target's place, taking the target's pinned
  /// state when dropped into the other section.
  Future<void> _moveNote(
    List<ProductivityItem> allNotes,
    int draggedId,
    ProductivityItem target,
  ) async {
    final dragged = allNotes.where((note) => note.id == draggedId).firstOrNull;
    if (dragged == null) return;
    if (dragged.isPinned != target.isPinned) {
      await _notifier.togglePinned(dragged);
    }

    final notes = ref
            .read(productivityItemsProvider(ProductivityItemType.note))
            .valueOrNull ??
        allNotes;
    final from = notes.indexWhere((note) => note.id == draggedId);
    final to = notes.indexWhere((note) => note.id == target.id);
    if (from < 0 || to < 0) return;
    await _notifier.reorder(from, to);
  }

  Future<void> _openEditor(ProductivityItem? note) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.of(context).push<NoteEditorResult>(
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(note: note),
      ),
    );
    if (result == null) return;

    if (result.discardedEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Note vide supprimée')),
        );
      return;
    }

    final deletedId = result.deletedNoteId;
    if (deletedId != null) {
      await _deleteWithUndo(deletedId, messenger: messenger);
    }
  }

  /// Deletes a note and offers to bring it back from the snackbar.
  Future<void> _deleteWithUndo(
    int noteId, {
    ScaffoldMessengerState? messenger,
  }) async {
    final scaffoldMessenger = messenger ?? ScaffoldMessenger.of(context);
    final notifier = _notifier;
    final deleted = await notifier.deleteById(noteId);
    if (deleted == null) return;
    scaffoldMessenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Note supprimée'),
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () => notifier.restore(deleted),
          ),
        ),
      );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
          child: Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
        ),
      );
}

/// Two-column masonry: each card goes to the currently shorter column, using
/// a cheap height estimate from its preview.
class _NotesMasonry extends StatelessWidget {
  const _NotesMasonry({
    required this.notes,
    required this.canReorder,
    required this.onOpen,
    required this.onTogglePin,
    required this.onDelete,
    required this.onDropOnto,
  });

  final List<ProductivityItem> notes;
  final bool canReorder;
  final ValueChanged<ProductivityItem> onOpen;
  final ValueChanged<ProductivityItem> onTogglePin;
  final ValueChanged<ProductivityItem> onDelete;
  final void Function(int draggedId, ProductivityItem target) onDropOnto;

  @override
  Widget build(BuildContext context) {
    final columns = [<Widget>[], <Widget>[]];
    final heights = [0.0, 0.0];

    for (final note in notes) {
      final preview = _NotePreviewData.from(note);
      final column = heights[0] <= heights[1] ? 0 : 1;
      heights[column] += preview.estimatedLines + 3;
      columns[column].add(
        Padding(
          key: ValueKey(note.id),
          padding: const EdgeInsets.only(bottom: _gridSpacing),
          child: _DraggableNoteCard(
            note: note,
            preview: preview,
            canReorder: canReorder,
            onTap: () => onOpen(note),
            onTogglePin: () => onTogglePin(note),
            onDelete: () => onDelete(note),
            onDropOnto: (draggedId) => onDropOnto(draggedId, note),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: _gridSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: columns[0],
            ),
          ),
          const SizedBox(width: _gridSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: columns[1],
            ),
          ),
        ],
      ),
    );
  }
}

/// A note card that opens on tap, with the long-press menu and drag & drop.
class _DraggableNoteCard extends StatelessWidget {
  const _DraggableNoteCard({
    required this.note,
    required this.preview,
    required this.canReorder,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
    required this.onDropOnto,
  });

  final ProductivityItem note;
  final _NotePreviewData preview;
  final bool canReorder;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final ValueChanged<int> onDropOnto;

  @override
  Widget build(BuildContext context) => ContextMenuCard<int>(
        // Reordering is off while searching; the menu still opens
        dragData: canReorder ? note.id : null,
        onAccept: onDropOnto,
        preview: _NoteCard(note: note, preview: preview),
        actions: [
          ContextMenuAction(
            icon: note.isPinned
                ? Icons.push_pin_rounded
                : Icons.push_pin_outlined,
            label: note.isPinned ? 'Désépingler' : 'Épingler',
            onTap: onTogglePin,
          ),
          ContextMenuAction(
            icon: Icons.edit_outlined,
            label: 'Modifier',
            onTap: onTap,
          ),
          ContextMenuAction(
            icon: Icons.delete_outline_rounded,
            label: 'Supprimer',
            isDestructive: true,
            onTap: onDelete,
          ),
        ],
        child: _NoteCard(note: note, preview: preview, onTap: onTap),
      );
}

/// The lines a card shows, derived once per build from the stored document.
class _NotePreviewData {
  const _NotePreviewData({
    required this.lines,
    required this.hasMore,
    required this.checkedCount,
    required this.estimatedLines,
  });

  static const _maxLines = 8;

  final List<NoteBlock> lines;
  final bool hasMore;
  final int checkedCount;
  final double estimatedLines;

  factory _NotePreviewData.from(ProductivityItem note) {
    final blocks = NoteDocument.decode(note.details).blocks;
    final open = blocks
        .where(
          (block) =>
              !(block.kind == NoteBlockKind.checkbox && block.isChecked) &&
              (block.text.trim().isNotEmpty ||
                  block.kind == NoteBlockKind.number),
        )
        .toList();
    final checkedCount = blocks
        .where(
          (block) => block.kind == NoteBlockKind.checkbox && block.isChecked,
        )
        .length;
    final lines = open.take(_maxLines).toList();

    var estimate = note.title.trim().isEmpty ? 0.0 : 1.5;
    for (final block in lines) {
      estimate += (1 + block.text.length ~/ 22).clamp(1, 4);
    }
    if (checkedCount > 0) estimate += 1;

    return _NotePreviewData(
      lines: lines,
      hasMore: open.length > _maxLines,
      checkedCount: checkedCount,
      estimatedLines: estimate,
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.preview,
    this.onTap,
  });

  final ProductivityItem note;
  final _NotePreviewData preview;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColor = note.colorValue == 0 ? null : Color(note.colorValue);
    final cardColor = customColor == null
        ? colors.surfaceContainerHigh
        : Color.lerp(
            colors.surfaceContainerHigh,
            customColor,
            theme.brightness == Brightness.dark ? 0.20 : 0.58,
          );
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      color: colors.onSurfaceVariant,
      height: 1.35,
    );

    var orderedNumber = 0;
    final lines = <Widget>[];
    for (final block in preview.lines) {
      orderedNumber =
          block.kind == NoteBlockKind.orderedList ? orderedNumber + 1 : 0;
      lines.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _PreviewLine(
            block: block,
            orderedNumber: orderedNumber,
            style: bodyStyle,
          ),
        ),
      );
    }

    return GlassSurface(
      color: cardColor,
      showShadow: false,
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            constraints: const BoxConstraints(minHeight: 132),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.title.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      note.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ...lines,
                if (preview.hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('…', style: bodyStyle),
                  ),
                if (preview.checkedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      preview.checkedCount == 1
                          ? '+ 1 élément coché'
                          : '+ ${preview.checkedCount} éléments cochés',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.block,
    required this.orderedNumber,
    required this.style,
  });

  final NoteBlock block;
  final int orderedNumber;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = block.text.trim();
    Widget marked(Widget marker, {int maxLines = 2}) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            marker,
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        );

    return switch (block.kind) {
      NoteBlockKind.checkbox => marked(
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_box_outline_blank_rounded,
              size: 16,
              color: style?.color,
            ),
          ),
        ),
      NoteBlockKind.unorderedList => marked(Text('•', style: style)),
      NoteBlockKind.orderedList =>
        marked(Text('$orderedNumber.', style: style)),
      NoteBlockKind.heading => Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style?.copyWith(fontWeight: FontWeight.w700),
        ),
      NoteBlockKind.number => Text(
          _numberText(block),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      NoteBlockKind.paragraph => Text(
          text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
    };
  }

  static String _numberText(NoteBlock block) {
    final value = block.numberValue == block.numberValue.roundToDouble()
        ? block.numberValue.toInt().toString()
        : block.numberValue.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    final measurement =
        [value, block.unit.trim()].where((part) => part.isNotEmpty).join(' ');
    final label = block.text.trim();
    return label.isEmpty ? measurement : '$label : $measurement';
  }
}

class _EmptyProductivityState extends StatelessWidget {
  const _EmptyProductivityState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
