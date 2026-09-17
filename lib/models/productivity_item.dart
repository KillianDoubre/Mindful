import 'package:mindful/models/task_recurrence.dart';

enum ProductivityItemType {
  note('note'),
  task('task');

  const ProductivityItemType(this.databaseValue);

  final String databaseValue;
}

class ProductivityItem {
  const ProductivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.details,
    required this.colorValue,
    required this.isCompleted,
    required this.dueAt,
    required this.sortOrder,
    this.isPinned = false,
    this.reminderOffsets = const [],
    this.recurrence = TaskRecurrence.none,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final ProductivityItemType type;
  final String title;
  final String details;
  final int colorValue;
  final bool isCompleted;
  final DateTime? dueAt;
  final int sortOrder;
  final bool isPinned;

  /// Reminders before [dueAt], in minutes (0 = at the due time).
  final List<int> reminderOffsets;

  /// How the task repeats once completed.
  final TaskRecurrence recurrence;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProductivityItem.fromDatabase(Map<String, Object?> data) {
    final typeValue = data['item_type'] as String?;
    return ProductivityItem(
      id: data['id'] as int,
      type: ProductivityItemType.values.firstWhere(
        (type) => type.databaseValue == typeValue,
        orElse: () => ProductivityItemType.note,
      ),
      title: data['title'] as String? ?? '',
      details: data['details'] as String? ?? '',
      colorValue: data['color_value'] as int? ?? 0,
      isCompleted: (data['is_completed'] as int? ?? 0) == 1,
      dueAt: switch (data['due_at']) {
        final int milliseconds =>
          DateTime.fromMillisecondsSinceEpoch(milliseconds),
        _ => null,
      },
      sortOrder: data['sort_order'] as int? ?? 0,
      isPinned: (data['is_pinned'] as int? ?? 0) == 1,
      reminderOffsets: parseReminderOffsets(data['reminders'] as String?),
      recurrence: TaskRecurrence.fromDatabase(data['recurrence'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        data['created_at'] as int? ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        data['updated_at'] as int? ?? 0,
      ),
    );
  }

  ProductivityItem copyWith({
    String? title,
    String? details,
    int? colorValue,
    bool? isCompleted,
    DateTime? dueAt,
    bool clearDueAt = false,
    int? sortOrder,
    bool? isPinned,
    List<int>? reminderOffsets,
    TaskRecurrence? recurrence,
    DateTime? updatedAt,
  }) =>
      ProductivityItem(
        id: id,
        type: type,
        title: title ?? this.title,
        details: details ?? this.details,
        colorValue: colorValue ?? this.colorValue,
        isCompleted: isCompleted ?? this.isCompleted,
        dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
        sortOrder: sortOrder ?? this.sortOrder,
        isPinned: isPinned ?? this.isPinned,
        reminderOffsets: reminderOffsets ?? this.reminderOffsets,
        recurrence: recurrence ?? this.recurrence,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class ProductivityItemDraft {
  const ProductivityItemDraft({
    required this.title,
    this.details = '',
    this.colorValue = 0,
    this.isCompleted = false,
    this.dueAt,
    this.isPinned,
    this.reminderOffsets,
    this.recurrence,
  });

  /// A draft carrying every field of [item], with some replaced.
  factory ProductivityItemDraft.fromItem(
    ProductivityItem item, {
    bool? isCompleted,
    DateTime? dueAt,
    bool clearDueAt = false,
  }) =>
      ProductivityItemDraft(
        title: item.title,
        details: item.details,
        colorValue: item.colorValue,
        isCompleted: isCompleted ?? item.isCompleted,
        dueAt: clearDueAt ? null : dueAt ?? item.dueAt,
        isPinned: item.isPinned,
        reminderOffsets: item.reminderOffsets,
        recurrence: item.recurrence,
      );

  final String title;
  final String details;
  final int colorValue;
  final bool isCompleted;
  final DateTime? dueAt;

  /// `null` keeps the stored value when updating an existing item.
  final bool? isPinned;

  /// `null` keeps the stored value when updating an existing item.
  final List<int>? reminderOffsets;

  /// `null` keeps the stored value when updating an existing item.
  final TaskRecurrence? recurrence;
}

/// A task marked as done, as recorded in the completion log.
class TaskCompletion {
  const TaskCompletion({
    required this.id,
    required this.taskId,
    required this.title,
    required this.completedAt,
  });

  final int id;
  final int taskId;
  final String title;
  final DateTime completedAt;
}

/// What completing a task did, so it can be undone.
class TaskCompletionResult {
  const TaskCompletionResult({required this.completionId, this.nextDueAt});

  final int completionId;

  /// Next occurrence for a recurring task, `null` otherwise.
  final DateTime? nextDueAt;
}

List<int> parseReminderOffsets(String? raw) {
  final offsets = (raw ?? '')
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .where((offset) => offset >= 0)
      .toSet()
      .toList()
    ..sort();
  return offsets;
}

String encodeReminderOffsets(List<int> offsets) =>
    (offsets.toSet().toList()..sort()).join(',');
