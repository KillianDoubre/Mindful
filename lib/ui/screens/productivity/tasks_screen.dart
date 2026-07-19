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
import 'package:mindful/ui/screens/productivity/productivity_editor_sheet.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

enum _TaskFilter { pending, completed }

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _TaskFilter? _filter = _TaskFilter.pending;

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
          actions: [
            IconButton(
              tooltip: 'Réorganiser les tâches',
              onPressed: _showReorderHint,
              icon: const Icon(FluentIcons.re_order_dots_vertical_24_regular),
            ),
          ],
          fab: DefaultFabButton(
            heroTag: 'newTaskFab',
            label: 'Nouvelle tâche',
            icon: FluentIcons.add_20_filled,
            onPressed: () => _openEditor(),
          ),
          sliverBody: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
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
                    onTap: () => ref
                        .read(productivityItemsProvider(
                          ProductivityItemType.task,
                        ).notifier)
                        .refresh(),
                  ),
                ],
                data: _buildTaskSlivers,
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
        _TasksEmptyState(
          icon: FluentIcons.checkmark_circle_24_regular,
          title: 'Tout commence par une petite tâche',
          subtitle:
              'Ajoutez ce que vous voulez accomplir, avec ou sans échéance.',
          onTap: _openEditor,
        ),
      ];
    }

    final completed = tasks.where((task) => task.isCompleted).length;
    final visibleTasks = switch (_filter) {
      _TaskFilter.pending => tasks.where((task) => !task.isCompleted).toList(),
      _TaskFilter.completed => tasks.where((task) => task.isCompleted).toList(),
      null => tasks,
    };
    return [
      SliverToBoxAdapter(
        child: _TaskSummary(
          remaining: tasks.length - completed,
          completed: completed,
          selectedFilter: _filter,
          onFilterSelected: (filter) => setState(
            () => _filter = _filter == filter ? null : filter,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      if (visibleTasks.isEmpty)
        _TasksEmptyState(
          icon: _filter == _TaskFilter.completed
              ? FluentIcons.checkmark_circle_24_regular
              : FluentIcons.clock_24_regular,
          title: _filter == _TaskFilter.completed
              ? 'Aucune tâche terminée'
              : 'Aucune tâche à faire',
          subtitle: _filter == _TaskFilter.completed
              ? 'Les tâches accomplies apparaîtront ici.'
              : 'Toutes vos tâches sont terminées.',
        )
      else
        SliverReorderableList(
          itemCount: visibleTasks.length,
          onReorderItem: (oldIndex, newIndex) =>
              _reorderVisibleTasks(tasks, visibleTasks, oldIndex, newIndex),
          onReorderStart: (_) => HapticFeedback.mediumImpact(),
          itemBuilder: (context, index) {
            final task = visibleTasks[index];
            return ReorderableDelayedDragStartListener(
              key: ValueKey(task.id),
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskCard(
                  task: task,
                  onTap: () => _openEditor(task),
                  onCompletedChanged: () => ref
                      .read(productivityItemsProvider(
                        ProductivityItemType.task,
                      ).notifier)
                      .toggleCompleted(task),
                ),
              ),
            );
          },
        ),
    ];
  }

  Future<void> _reorderVisibleTasks(
    List<ProductivityItem> allTasks,
    List<ProductivityItem> visibleTasks,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;

    final reorderedVisible = [...visibleTasks];
    final moved = reorderedVisible.removeAt(oldIndex);
    reorderedVisible.insert(newIndex, moved);

    final visibleIds = visibleTasks.map((task) => task.id).toSet();
    var visibleIndex = 0;
    final reorderedAll = [
      for (final task in allTasks)
        if (visibleIds.contains(task.id))
          reorderedVisible[visibleIndex++]
        else
          task,
    ];

    await ref
        .read(productivityItemsProvider(ProductivityItemType.task).notifier)
        .setOrder(reorderedAll);
  }

  Future<void> _openEditor([ProductivityItem? task]) async {
    final result = await showProductivityEditor(
      context: context,
      type: ProductivityItemType.task,
      item: task,
    );
    if (result == null || !mounted) return;

    final notifier = ref.read(
      productivityItemsProvider(ProductivityItemType.task).notifier,
    );
    if (result.shouldDelete && task != null) {
      await notifier.delete(task);
    } else if (result.draft != null) {
      await notifier.save(result.draft!, id: task?.id);
    }
  }

  void _showReorderHint() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
              'Maintenez une tâche, puis faites-la glisser où vous voulez.'),
        ),
      );
  }
}

class _TaskSummary extends StatelessWidget {
  const _TaskSummary({
    required this.remaining,
    required this.completed,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final int remaining;
  final int completed;
  final _TaskFilter? selectedFilter;
  final ValueChanged<_TaskFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _SummaryPill(
            icon: FluentIcons.clock_20_regular,
            label: '$remaining à faire',
            color: colors.primaryContainer,
            isSelected: selectedFilter == _TaskFilter.pending,
            onTap: () => onFilterSelected(_TaskFilter.pending),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryPill(
            icon: FluentIcons.checkmark_circle_20_filled,
            label: '$completed terminée${completed == 1 ? '' : 's'}',
            color: colors.tertiaryContainer,
            isSelected: selectedFilter == _TaskFilter.completed,
            onTap: () => onFilterSelected(_TaskFilter.completed),
          ),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedScale(
            scale: isSelected ? 0.97 : 1,
            duration: const Duration(milliseconds: 160),
            child: GlassSurface(
              showShadow: isSelected,
              color: isSelected ? color : colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onCompletedChanged,
  });

  final ProductivityItem task;
  final VoidCallback onTap;
  final VoidCallback onCompletedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isOverdue = task.dueAt != null &&
        task.dueAt!.isBefore(DateTime.now()) &&
        !task.isCompleted;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: task.isCompleted ? 0.62 : 1,
      child: GlassSurface(
        showShadow: false,
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox.adaptive(
                    value: task.isCompleted,
                    onChanged: (_) => onCompletedChanged(),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (task.details.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              task.details,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                          if (task.dueAt != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isOverdue ? colors.error : colors.primary)
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isOverdue
                                        ? FluentIcons.warning_16_filled
                                        : FluentIcons.calendar_clock_16_regular,
                                    size: 16,
                                    color: isOverdue
                                        ? colors.error
                                        : colors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _formatDueDate(context, task.dueAt!),
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
                                        color: isOverdue
                                            ? colors.error
                                            : colors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 5),
                    child: Icon(
                      FluentIcons.re_order_dots_vertical_20_regular,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.65),
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

  String _formatDueDate(BuildContext context, DateTime dueAt) {
    final localizations = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dueAt.year, dueAt.month, dueAt.day);
    final days = date.difference(today).inDays;
    final dateLabel = switch (days) {
      0 => "Aujourd'hui",
      1 => 'Demain',
      -1 => 'Hier',
      _ => localizations.formatMediumDate(dueAt),
    };
    final timeLabel = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(dueAt),
    );
    return '$dateLabel • $timeLabel';
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
