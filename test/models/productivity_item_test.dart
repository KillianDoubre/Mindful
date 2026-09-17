import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/models/task_recurrence.dart';

ProductivityItem makeTask({
  int id = 1,
  String title = 'Tâche',
  bool isCompleted = false,
  DateTime? dueAt,
  int sortOrder = 0,
  List<int> reminders = const [],
  TaskRecurrence recurrence = TaskRecurrence.none,
  bool isPinned = false,
}) =>
    ProductivityItem(
      id: id,
      type: ProductivityItemType.task,
      title: title,
      details: 'détails',
      colorValue: 0,
      isCompleted: isCompleted,
      dueAt: dueAt,
      sortOrder: sortOrder,
      isPinned: isPinned,
      reminderOffsets: reminders,
      recurrence: recurrence,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('ProductivityItem.fromDatabase', () {
    test('reads every column', () {
      final item = ProductivityItem.fromDatabase({
        'id': 7,
        'item_type': 'task',
        'title': 'Courses',
        'details': 'Lait',
        'color_value': 42,
        'is_completed': 1,
        'due_at': DateTime(2026, 9, 16, 18).millisecondsSinceEpoch,
        'sort_order': 3,
        'is_pinned': 1,
        'reminders': '60,0',
        'recurrence': 'weekly',
        'created_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'updated_at': DateTime(2026, 2, 1).millisecondsSinceEpoch,
      });

      expect(item.id, 7);
      expect(item.type, ProductivityItemType.task);
      expect(item.title, 'Courses');
      expect(item.details, 'Lait');
      expect(item.colorValue, 42);
      expect(item.isCompleted, isTrue);
      expect(item.dueAt, DateTime(2026, 9, 16, 18));
      expect(item.sortOrder, 3);
      expect(item.isPinned, isTrue);
      expect(item.reminderOffsets, [0, 60]);
      expect(item.recurrence, TaskRecurrence.weekly);
      expect(item.createdAt, DateTime(2026, 1, 1));
      expect(item.updatedAt, DateTime(2026, 2, 1));
    });

    test('tolerates rows from older versions', () {
      final item = ProductivityItem.fromDatabase({'id': 1});
      expect(item.type, ProductivityItemType.note);
      expect(item.title, '');
      expect(item.details, '');
      expect(item.isCompleted, isFalse);
      expect(item.dueAt, isNull);
      expect(item.isPinned, isFalse);
      expect(item.reminderOffsets, isEmpty);
      expect(item.recurrence, TaskRecurrence.none);
    });

    test('unknown type defaults to note', () {
      expect(
        ProductivityItem.fromDatabase({'id': 1, 'item_type': 'x'}).type,
        ProductivityItemType.note,
      );
    });
  });

  group('reminder offsets encoding', () {
    test('parse ignores junk, negatives and duplicates and sorts', () {
      expect(parseReminderOffsets('60, 0,abc,-5,60,1440'), [0, 60, 1440]);
    });

    test('parse handles empty and null', () {
      expect(parseReminderOffsets(null), isEmpty);
      expect(parseReminderOffsets(''), isEmpty);
    });

    test('encode sorts and removes duplicates', () {
      expect(encodeReminderOffsets([60, 15, 60, 0]), '0,15,60');
      expect(encodeReminderOffsets([]), '');
    });

    test('encode then parse is lossless', () {
      const offsets = [0, 5, 90, 2880];
      expect(parseReminderOffsets(encodeReminderOffsets(offsets)), offsets);
    });
  });

  group('copyWith', () {
    test('keeps unchanged fields', () {
      final task = makeTask(
        reminders: [10],
        recurrence: TaskRecurrence.daily,
        isPinned: true,
      );
      final copy = task.copyWith(title: 'Nouveau');
      expect(copy.title, 'Nouveau');
      expect(copy.reminderOffsets, [10]);
      expect(copy.recurrence, TaskRecurrence.daily);
      expect(copy.isPinned, isTrue);
      expect(copy.id, task.id);
    });

    test('clearDueAt removes the due date', () {
      final task = makeTask(dueAt: DateTime(2026));
      expect(task.copyWith(clearDueAt: true).dueAt, isNull);
    });
  });

  group('ProductivityItemDraft.fromItem', () {
    final due = DateTime(2026, 9, 16, 18);
    final task = makeTask(
      title: 'Sport',
      dueAt: due,
      reminders: [0, 30],
      recurrence: TaskRecurrence.weekdays,
      isPinned: true,
    );

    test('copies every field', () {
      final draft = ProductivityItemDraft.fromItem(task);
      expect(draft.title, 'Sport');
      expect(draft.details, 'détails');
      expect(draft.dueAt, due);
      expect(draft.isCompleted, isFalse);
      expect(draft.isPinned, isTrue);
      expect(draft.reminderOffsets, [0, 30]);
      expect(draft.recurrence, TaskRecurrence.weekdays);
    });

    test('applies overrides', () {
      final next = DateTime(2026, 9, 17, 18);
      final draft = ProductivityItemDraft.fromItem(
        task,
        isCompleted: true,
        dueAt: next,
      );
      expect(draft.isCompleted, isTrue);
      expect(draft.dueAt, next);
    });

    test('clearDueAt wins over the stored date', () {
      expect(
        ProductivityItemDraft.fromItem(task, clearDueAt: true).dueAt,
        isNull,
      );
    });
  });

  test('a plain draft keeps stored optional fields', () {
    const draft = ProductivityItemDraft(title: 'x');
    expect(draft.isPinned, isNull);
    expect(draft.reminderOffsets, isNull);
    expect(draft.recurrence, isNull);
    expect(draft.isCompleted, isFalse);
    expect(draft.colorValue, 0);
  });
}
