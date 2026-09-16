/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/providers/productivity/productivity_items_provider.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/core/services/task_reminders_service.dart';
import 'package:mindful/ui/screens/productivity/task_due.dart';
import 'package:mindful/ui/screens/productivity/task_reminder_picker.dart';

/// Opens the task sheet. Returns the id of the task to delete when the user
/// chose "Supprimer", so the list can offer to undo it.
Future<int?> showTaskEditor(BuildContext context, {ProductivityItem? task}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // The sheet draws its own handle
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _TaskEditorSheet(task: task),
    );

/// Always-editable task sheet: no save button, every change is written
/// shortly after it happens and when the sheet closes.
class _TaskEditorSheet extends ConsumerStatefulWidget {
  const _TaskEditorSheet({this.task});

  final ProductivityItem? task;

  @override
  ConsumerState<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<_TaskEditorSheet> {
  static const _autoSaveDelay = Duration(milliseconds: 600);

  late final ProductivityItemsNotifier _tasks;
  late final TextEditingController _titleController;
  late final TextEditingController _detailsController;
  late bool _isCompleted;
  DateTime? _dueAt;
  late List<int> _reminders;
  int? _taskId;

  Timer? _saveTimer;
  Future<void> _saveQueue = Future.value();
  bool _hasUnsavedChanges = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _tasks = ref.read(
      productivityItemsProvider(ProductivityItemType.task).notifier,
    );
    _titleController = TextEditingController(text: widget.task?.title);
    _detailsController = TextEditingController(text: widget.task?.details);
    _isCompleted = widget.task?.isCompleted ?? false;
    _dueAt = widget.task?.dueAt;
    _reminders = [...?widget.task?.reminderOffsets];
    _taskId = widget.task?.id;
    _lastTitle = _titleController.text;
    _lastDetails = _detailsController.text;
    _titleController.addListener(_onTextChanged);
    _detailsController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (!_isDeleting) _flush();
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  // Controllers also notify on cursor moves
  String _lastTitle = '';
  String _lastDetails = '';

  void _onTextChanged() {
    if (_titleController.text == _lastTitle &&
        _detailsController.text == _lastDetails) {
      return;
    }
    _lastTitle = _titleController.text;
    _lastDetails = _detailsController.text;
    _markChanged();
  }

  void _markChanged() {
    _hasUnsavedChanges = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_autoSaveDelay, _flush);
  }

  Future<void> _flush() {
    _saveTimer?.cancel();
    return _saveQueue = _saveQueue.then((_) => _persist());
  }

  Future<void> _persist() async {
    if (!_hasUnsavedChanges) return;
    _hasUnsavedChanges = false;
    final title = _lastTitle.trim();
    // A task needs a title; clearing it keeps the last saved version
    if (title.isEmpty) return;
    _taskId = await _tasks.save(
      ProductivityItemDraft(
        title: title,
        details: _lastDetails,
        isCompleted: _isCompleted,
        dueAt: _dueAt,
        reminderOffsets: _reminders,
      ),
      id: _taskId,
    );
  }

  void _setDue(DateTime? value) {
    setState(() => _dueAt = value);
    _markChanged();
  }

  void _setReminders(List<int> reminders) {
    setState(() => _reminders = [...reminders]..sort());
    _markChanged();
  }

  void _toggleCompleted() {
    HapticFeedback.lightImpact();
    setState(() => _isCompleted = !_isCompleted);
    _markChanged();
  }

  Future<void> _delete() async {
    final id = _taskId;
    _isDeleting = true;
    _saveTimer?.cancel();
    if (id != null) await _flush();
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, keyboardInset + 8),
      child: GlassSurface(
        groupBlur: false,
        blur: 28,
        color: colors.surfaceContainer.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(30),
        child: Material(
          color: Colors.transparent,
          child: Theme(
            data: theme.copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TaskCheckCircle(
                          isChecked: _isCompleted,
                          onTap: _toggleCompleted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          autofocus: widget.task == null,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration: _isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Que faut-il faire ?',
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: "Plus d'options",
                        onSelected: (value) {
                          if (value == 'delete') _delete();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(FluentIcons.delete_20_regular),
                              title: Text('Supprimer la tâche'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 38, right: 8),
                    child: TextField(
                      controller: _detailsController,
                      maxLines: null,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ajouter des détails',
                        prefixIcon: Icon(
                          FluentIcons.text_align_left_20_regular,
                          size: 18,
                        ),
                        prefixIconConstraints: BoxConstraints(minWidth: 28),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DueSection(
                    dueAt: _dueAt,
                    onChanged: _setDue,
                    reminders: _reminders,
                    onRemindersChanged: _setReminders,
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

class _DueSection extends StatelessWidget {
  const _DueSection({
    required this.dueAt,
    required this.onChanged,
    required this.reminders,
    required this.onRemindersChanged,
  });

  final DateTime? dueAt;
  final ValueChanged<DateTime?> onChanged;
  final List<int> reminders;
  final ValueChanged<List<int>> onRemindersChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current = dueAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'ÉCHÉANCE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final shortcut in DueShortcut.values)
              ChoiceChip(
                label: Text(shortcut.label),
                selected: current != null && shortcut.matches(current),
                onSelected: (_) =>
                    onChanged(shortcut.resolve(DateTime.now(), current)),
              ),
            ActionChip(
              avatar: const Icon(FluentIcons.calendar_20_regular, size: 18),
              label: const Text('Choisir…'),
              onPressed: () => _pickDate(context),
            ),
          ],
        ),
        if (current != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                FluentIcons.calendar_clock_20_regular,
                color: dueColor(context, current, isCompleted: false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatDue(context, current),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: dueColor(context, current, isCompleted: false),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _pickTime(context),
                icon: const Icon(FluentIcons.clock_20_regular, size: 18),
                label: const Text('Heure'),
              ),
              IconButton(
                tooltip: "Retirer l'échéance",
                onPressed: () => onChanged(null),
                icon: const Icon(FluentIcons.dismiss_20_regular),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _RemindersSection(
            dueAt: current,
            reminders: reminders,
            onChanged: onRemindersChanged,
          ),
        ],
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final base = dueAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final time = dueAt == null
        ? const TimeOfDay(hour: defaultDueHour, minute: 0)
        : TimeOfDay.fromDateTime(dueAt!);
    onChanged(DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    ));
  }

  Future<void> _pickTime(BuildContext context) async {
    final current = dueAt!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    onChanged(DateTime(
      current.year,
      current.month,
      current.day,
      picked.hour,
      picked.minute,
    ));
  }
}

/// Notification reminders before the due time.
class _RemindersSection extends StatelessWidget {
  const _RemindersSection({
    required this.dueAt,
    required this.reminders,
    required this.onChanged,
  });

  final DateTime dueAt;
  final List<int> reminders;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'RAPPELS',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final offset in reminders)
              Opacity(
                // A reminder whose time has already passed will not ring
                opacity: dueAt.subtract(Duration(minutes: offset)).isAfter(now)
                    ? 1
                    : 0.45,
                child: InputChip(
                  avatar: const Icon(FluentIcons.alert_20_regular, size: 18),
                  label: Text(formatReminderOffset(offset)),
                  onDeleted: () => onChanged(
                    reminders.where((value) => value != offset).toList(),
                  ),
                ),
              ),
            ActionChip(
              avatar: const Icon(FluentIcons.add_20_regular, size: 18),
              label: Text(reminders.isEmpty ? 'Ajouter un rappel' : 'Rappel'),
              onPressed: () async {
                final picked = await showTaskReminderPicker(
                  context,
                  existing: reminders,
                );
                if (picked != null && !reminders.contains(picked)) {
                  onChanged([...reminders, picked]);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Round, animated completion toggle shared by the list and the sheet.
class TaskCheckCircle extends StatelessWidget {
  const TaskCheckCircle({
    super.key,
    required this.isChecked,
    required this.onTap,
    this.size = 26,
  });

  final bool isChecked;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      checked: isChecked,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: size,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isChecked ? colors.primary : Colors.transparent,
            border: Border.all(
              width: 2,
              color: isChecked ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
          child: AnimatedScale(
            scale: isChecked ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Icon(
              Icons.check_rounded,
              size: size * 0.66,
              color: colors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
