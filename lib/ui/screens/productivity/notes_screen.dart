import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/models/note_document.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/providers/productivity/productivity_items_provider.dart';
import 'package:mindful/ui/common/default_fab_button.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/scaffold_shell.dart';
import 'package:mindful/ui/common/sliver_tabs_bottom_padding.dart';
import 'package:mindful/ui/screens/productivity/note_edit_icon.dart';
import 'package:mindful/ui/screens/productivity/note_editor_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

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
          actions: [
            IconButton(
              tooltip: 'Réorganiser les notes',
              onPressed: _showReorderHint,
              icon: const Icon(FluentIcons.re_order_dots_vertical_24_regular),
            ),
          ],
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
                    onTap: () => ref
                        .read(productivityItemsProvider(
                          ProductivityItemType.note,
                        ).notifier)
                        .refresh(),
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
      borderRadius: BorderRadius.circular(20),
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
    final visibleNotes = query.isEmpty
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
          icon: query.isEmpty
              ? FluentIcons.note_add_24_regular
              : FluentIcons.search_24_regular,
          title: query.isEmpty ? 'Une idée à garder ?' : 'Aucune note trouvée',
          subtitle: query.isEmpty
              ? 'Créez une note, puis maintenez-la pour la déplacer.'
              : 'Essayez une autre recherche.',
          onTap: query.isEmpty ? () => _openEditor(null) : null,
        ),
      ];
    }

    if (query.isNotEmpty) {
      return [
        SliverList.builder(
          itemCount: visibleNotes.length,
          itemBuilder: (context, index) => Padding(
            key: ValueKey(visibleNotes[index].id),
            padding: const EdgeInsets.only(bottom: 10),
            child: _NoteCard(
              note: visibleNotes[index],
              showDragHandle: false,
              onTap: () => _openEditor(visibleNotes[index]),
              onEdit: () => _openEditor(
                visibleNotes[index],
                startInEditMode: true,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverReorderableList(
        itemCount: allNotes.length,
        onReorderItem: (oldIndex, newIndex) => ref
            .read(productivityItemsProvider(ProductivityItemType.note).notifier)
            .reorder(oldIndex, newIndex),
        onReorderStart: (_) => HapticFeedback.mediumImpact(),
        itemBuilder: (context, index) {
          final note = allNotes[index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(note.id),
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NoteCard(
                note: note,
                showDragHandle: true,
                onTap: () => _openEditor(note),
                onEdit: () => _openEditor(note, startInEditMode: true),
              ),
            ),
          );
        },
      ),
    ];
  }

  Future<void> _openEditor(
    ProductivityItem? note, {
    bool startInEditMode = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NoteEditorScreen(
          note: note,
          startInEditMode: startInEditMode,
        ),
      ),
    );
  }

  void _showReorderHint() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
              'Maintenez une note, puis faites-la glisser où vous voulez.'),
        ),
      );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.showDragHandle,
    required this.onTap,
    required this.onEdit,
  });

  final ProductivityItem note;
  final bool showDragHandle;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final noteText = NoteDocument.decode(note.details).plainText;
    final hasCustomColor = note.colorValue != 0;
    final customColor = hasCustomColor ? Color(note.colorValue) : null;
    final cardColor = customColor == null
        ? colors.surfaceContainerHigh
        : Color.lerp(
            colors.surfaceContainerHigh,
            customColor,
            theme.brightness == Brightness.dark ? 0.20 : 0.58,
          );

    return GlassSurface(
      color: cardColor,
      showShadow: false,
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (noteText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          noteText,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.38,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Modifier la note',
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                      icon: NoteEditIcon(
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (showDragHandle)
                      Padding(
                        padding: const EdgeInsets.only(left: 2, right: 2),
                        child: Icon(
                          FluentIcons.re_order_dots_vertical_20_regular,
                          color:
                              colors.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
