import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/providers/productivity/productivity_items_provider.dart';
import 'package:mindful/ui/common/default_fab_button.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/scaffold_shell.dart';
import 'package:mindful/ui/common/sliver_tabs_bottom_padding.dart';
import 'package:mindful/ui/screens/productivity/context_menu_card.dart';
import 'package:mindful/ui/screens/productivity/task_due.dart';
import 'package:mindful/ui/screens/productivity/task_editor_sheet.dart';

/// Tasks, organised like a to-do app built on the notes principles: quick
/// capture at the top, pending tasks grouped by due date, finished ones
/// folded away at the bottom, and everything editable in place.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  bool _showCompleted = false;

  /// Tasks swiped away, hidden until the database catches up.
  final Set<int> _hiddenIds = {};

  ProductivityItemsNotifier get _notifier => ref.read(
        productivityItemsProvider(ProductivityItemType.task).notifier,
      );

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(
      productivityItemsProvider(ProductivityItemType.task),
    );

    return ScaffoldShell(
      items: [
        NavbarItem(
          icon: FluentIcons.reading_list_20_regular,
          filledIcon: FluentIcons.reading_list_20_filled,
          titleText: 'Tâches',
          fab: DefaultFabButton(
            heroTag: 'newTaskFab',
            label: 'Nouvelle tâche',
            icon: FluentIcons.add_20_filled,
            onPressed: () => _openEditor(),
          ),
          sliverBody: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _QuickAddField(onSubmitted: _quickAdd),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              ...tasks.when(
                loading: () => [
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (_, __) => [
                  _TasksEmptyState(
                    icon: FluentIcons.warning_24_regular,
                    title: 'Impossible de charger les tâches',
                    subtitle: 'Touchez pour réessayer.',
                    onTap: () => _notifier.refresh(),
                  ),
                ],
                data: (all) => _buildTaskSlivers(
                  all.where((task) => !_hiddenIds.contains(task.id)).toList(),
                ),
              ),
              const SliverTabsBottomPadding(),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTaskSlivers(List<ProductivityItem> tasks) {
    if (tasks.isEmpty) {
      return [
        const _TasksEmptyState(
          icon: FluentIcons.checkmark_circle_24_regular,
          title: 'Tout commence par une petite tâche',
          subtitle: 'Écrivez-la ci-dessus et validez, c’est tout.',
        ),
      ];
    }

    final now = DateTime.now();
    final pending = tasks.where((task) => !task.isCompleted).toList();
    final completed = tasks.where((task) => task.isCompleted).toList();

    final groups = <DueGroup, List<ProductivityItem>>{};
    for (final task in pending) {
      groups.putIfAbsent(DueGroup.of(task.dueAt, now), () => []).add(task);
    }
    // Dated groups read in time order; undated ones keep the user's order
    for (final entry in groups.entries) {
      if (entry.key == DueGroup.none) continue;
      entry.value.sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    }

    return [
      if (pending.isEmpty)
        const SliverToBoxAdapter(child: _AllDoneBanner())
      else
        for (final group in DueGroup.values)
          if (groups[group]?.isNotEmpty ?? false) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                label: group.label,
                count: groups[group]!.length,
                color: group == DueGroup.overdue
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
            _taskList(groups[group]!, tasks),
          ],
      if (completed.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _CompletedHeader(
            count: completed.length,
            isExpanded: _showCompleted,
            onToggle: () => setState(() => _showCompleted = !_showCompleted),
            onClear: () => _clearCompleted(completed),
          ),
        ),
        if (_showCompleted) _taskList(completed, tasks),
      ],
    ];
  }

  Widget _taskList(
    List<ProductivityItem> visible,
    List<ProductivityItem> allTasks,
  ) =>
      SliverList.builder(
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final task = visible[index];
          return Padding(
            key: ValueKey('task-${task.id}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: _SwipeableTask(
              task: task,
              onComplete: () => _toggleCompleted(task),
              onDelete: () => _deleteWithUndo([task], swiped: true),
              child: ContextMenuCard<int>(
                dragData: task.isCompleted ? null : task.id,
                onAccept: (draggedId) => _moveTask(allTasks, draggedId, task),
                borderRadius: BorderRadius.circular(20),
                preview: _TaskCard(task: task),
                actions: _menuActions(task),
                child: _TaskCard(
                  task: task,
                  onTap: () => _openEditor(task),
                  onToggle: () => _toggleCompleted(task),
                ),
              ),
            ),
          );
        },
      );

  List<ContextMenuAction> _menuActions(ProductivityItem task) => [
        ContextMenuAction(
          icon: FluentIcons.edit_20_regular,
          label: 'Modifier',
          onTap: () => _openEditor(task),
        ),
        if (!task.isCompleted) ...[
          ContextMenuAction(
            icon: FluentIcons.calendar_today_20_regular,
            label: 'Pour aujourd’hui',
            onTap: () => _setDue(
              task,
              DueShortcut.today.resolve(DateTime.now(), task.dueAt),
            ),
          ),
          ContextMenuAction(
            icon: FluentIcons.calendar_arrow_right_20_regular,
            label: 'Reporter à demain',
            onTap: () => _setDue(
              task,
              DueShortcut.tomorrow.resolve(DateTime.now(), task.dueAt),
            ),
          ),
          if (task.dueAt != null)
            ContextMenuAction(
              icon: FluentIcons.calendar_cancel_20_regular,
              label: 'Retirer l’échéance',
              onTap: () => _setDue(task, null),
            ),
        ],
        ContextMenuAction(
          icon: FluentIcons.delete_20_regular,
          label: 'Supprimer',
          isDestructive: true,
          onTap: () => _deleteWithUndo([task]),
        ),
      ];

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _quickAdd(String title) async {
    HapticFeedback.lightImpact();
    await _notifier.save(ProductivityItemDraft(title: title));
  }

  Future<int> _saveTask(
    ProductivityItem task, {
    bool? isCompleted,
    DateTime? dueAt,
    bool clearDue = false,
  }) =>
      _notifier.save(
        ProductivityItemDraft(
          title: task.title,
          details: task.details,
          colorValue: task.colorValue,
          isCompleted: isCompleted ?? task.isCompleted,
          dueAt: clearDue ? null : dueAt ?? task.dueAt,
        ),
        id: task.id,
      );

  Future<void> _setDue(ProductivityItem task, DateTime? dueAt) =>
      _saveTask(task, dueAt: dueAt, clearDue: dueAt == null);

  Future<void> _toggleCompleted(ProductivityItem task) async {
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    final completing = !task.isCompleted;
    await _saveTask(task, isCompleted: completing);
    if (!completing) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 5),
          content: Text('« ${task.title} » terminée'),
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () => _saveTask(task, isCompleted: false),
          ),
        ),
      );
  }

  /// Moves the dragged task to the target's place. Dropping into another
  /// section also takes that section's due day.
  Future<void> _moveTask(
    List<ProductivityItem> allTasks,
    int draggedId,
    ProductivityItem target,
  ) async {
    final dragged = allTasks.where((task) => task.id == draggedId).firstOrNull;
    if (dragged == null) return;

    final now = DateTime.now();
    final targetGroup = DueGroup.of(target.dueAt, now);
    if (DueGroup.of(dragged.dueAt, now) != targetGroup) {
      final targetDue = target.dueAt;
      if (targetDue == null) {
        await _setDue(dragged, null);
      } else {
        final time = dragged.dueAt ?? targetDue;
        await _setDue(
          dragged,
          DateTime(
            targetDue.year,
            targetDue.month,
            targetDue.day,
            time.hour,
            time.minute,
          ),
        );
      }
    }

    final tasks = ref
            .read(productivityItemsProvider(ProductivityItemType.task))
            .valueOrNull ??
        allTasks;
    final from = tasks.indexWhere((task) => task.id == draggedId);
    final to = tasks.indexWhere((task) => task.id == target.id);
    if (from < 0 || to < 0) return;
    await _notifier.reorder(from, to);
  }

  Future<void> _openEditor([ProductivityItem? task]) async {
    final deletedId = await showTaskEditor(context, task: task);
    if (deletedId == null || !mounted) return;
    final latest = ref
        .read(productivityItemsProvider(ProductivityItemType.task))
        .valueOrNull
        ?.where((item) => item.id == deletedId)
        .firstOrNull;
    if (latest != null) await _deleteWithUndo([latest]);
  }

  Future<void> _clearCompleted(List<ProductivityItem> completed) =>
      _deleteWithUndo(completed);

  Future<void> _deleteWithUndo(
    List<ProductivityItem> tasks, {
    bool swiped = false,
  }) async {
    if (tasks.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final notifier = _notifier;
    // A swiped tile must leave the tree right away
    if (swiped) setState(() => _hiddenIds.addAll(tasks.map((t) => t.id)));

    for (final task in tasks) {
      await notifier.delete(task);
    }
    if (mounted) {
      setState(() => _hiddenIds.removeAll(tasks.map((t) => t.id)));
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 5),
          content: Text(
            tasks.length == 1
                ? 'Tâche supprimée'
                : '${tasks.length} tâches supprimées',
          ),
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () async {
              for (final task in tasks) {
                await notifier.restore(task);
              }
            },
          ),
        ),
      );
  }
}

/// Quick capture field. Kept apart from the page so typing only rebuilds
/// this row, not the whole scroll view.
class _QuickAddField extends StatefulWidget {
  const _QuickAddField({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  State<_QuickAddField> createState() => _QuickAddFieldState();
}

class _QuickAddFieldState extends State<_QuickAddField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    _controller.clear();
    // Keep the keyboard up to chain several tasks
    _focusNode.requestFocus();
    widget.onSubmitted(title);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassSurface(
      showShadow: false,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.only(left: 16, right: 6),
      child: Row(
        children: [
          Icon(FluentIcons.add_circle_20_regular, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              // The field sits at the top: never scroll the page to reveal it
              scrollPadding: EdgeInsets.zero,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: 'Ajouter une tâche',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => AnimatedScale(
              scale: value.text.trim().isEmpty ? 0 : 1,
              duration: const Duration(milliseconds: 160),
              child: IconButton.filled(
                tooltip: 'Ajouter',
                onPressed: _submit,
                icon: const Icon(FluentIcons.arrow_up_20_filled),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipe right to complete (the tile springs back and moves section), swipe
/// left to delete.
class _SwipeableTask extends StatelessWidget {
  const _SwipeableTask({
    required this.task,
    required this.onComplete,
    required this.onDelete,
    required this.child,
  });

  final ProductivityItem task;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('dismiss-${task.id}'),
      background: _SwipeBackground(
        color: colors.primary,
        icon: task.isCompleted
            ? FluentIcons.arrow_undo_20_regular
            : FluentIcons.checkmark_20_filled,
        label: task.isCompleted ? 'À refaire' : 'Terminée',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: colors.error,
        icon: FluentIcons.delete_20_regular,
        label: 'Supprimer',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onComplete();
          return false;
        }
        return true;
      },
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final content = [
      Icon(icon, color: color),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    ];
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft
            ? content
            : content.reversed.toList(),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, this.onTap, this.onToggle});

  final ProductivityItem task;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final due = task.dueAt;
    final details = task.details.trim();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: task.isCompleted ? 0.6 : 1,
      child: GlassSurface(
        showShadow: false,
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaskCheckCircle(
                    isChecked: task.isCompleted,
                    onTap: onToggle ?? () {},
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            details,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (due != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Flexible(
                                child: _DueChip(
                                  due: due,
                                  isCompleted: task.isCompleted,
                                ),
                              ),
                              if (task.reminderOffsets.isNotEmpty &&
                                  !task.isCompleted) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  FluentIcons.alert_16_regular,
                                  size: 15,
                                  color: colors.onSurfaceVariant,
                                ),
                                if (task.reminderOffsets.length > 1)
                                  Text(
                                    ' ${task.reminderOffsets.length}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.due, required this.isCompleted});

  final DateTime due;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final color = dueColor(context, due, isCompleted: isCompleted);
    final isOverdue = !isCompleted && due.isBefore(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue
                ? FluentIcons.warning_16_filled
                : FluentIcons.calendar_clock_16_regular,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              formatDue(context, due),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count, this.color});

  final String label;
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = color ?? colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedHeader extends StatelessWidget {
  const _CompletedHeader({
    required this.count,
    required this.isExpanded,
    required this.onToggle,
    required this.onClear,
  });

  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      count == 1 ? '1 terminée' : '$count terminées',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            TextButton(onPressed: onClear, child: const Text('Tout effacer')),
        ],
      ),
    );
  }
}

class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassSurface(
      showShadow: false,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(
            FluentIcons.checkmark_starburst_24_filled,
            color: colors.primary,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tout est fait',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  'Profitez-en, ou ajoutez la suite.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TasksEmptyState extends StatelessWidget {
  const _TasksEmptyState({
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
