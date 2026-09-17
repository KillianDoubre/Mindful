import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/core/database/app_database.dart';
import 'package:mindful/core/services/productivity_repository.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/models/task_recurrence.dart';

import '../helpers/test_env.dart';

void main() {
  late AppDatabase db;
  final repository = ProductivityRepository.instance;

  setUpAll(() {
    mockNativeChannel();
    db = useInMemoryDatabase();
  });

  setUp(() async {
    // Tables are created on first use
    await repository.load(ProductivityItemType.note);
    await clearTables(db, ['productivity_items', 'task_completions']);
  });

  tearDownAll(() => db.close());

  Future<ProductivityItem> byId(ProductivityItemType type, int id) async =>
      (await repository.load(type)).singleWhere((item) => item.id == id);

  group('save', () {
    test('creates an item and returns its id', () async {
      final id = await repository.save(
        type: ProductivityItemType.task,
        draft: const ProductivityItemDraft(title: '  Courses  ', details: 'Lait '),
      );
      final item = await byId(ProductivityItemType.task, id);
      expect(item.title, 'Courses');
      expect(item.details, 'Lait');
      expect(item.isCompleted, isFalse);
      expect(item.type, ProductivityItemType.task);
    });

    test('keeps notes and tasks apart', () async {
      await repository.save(
        type: ProductivityItemType.note,
        draft: const ProductivityItemDraft(title: 'Note'),
      );
      await repository.save(
        type: ProductivityItemType.task,
        draft: const ProductivityItemDraft(title: 'Tâche'),
      );
      expect(
        (await repository.load(ProductivityItemType.note)).map((i) => i.title),
        ['Note'],
      );
      expect(
        (await repository.load(ProductivityItemType.task)).map((i) => i.title),
        ['Tâche'],
      );
    });

    test('new notes go first, new tasks go last', () async {
      for (final title in ['A', 'B', 'C']) {
        await repository.save(
          type: ProductivityItemType.note,
          draft: ProductivityItemDraft(title: title),
        );
        await repository.save(
          type: ProductivityItemType.task,
          draft: ProductivityItemDraft(title: title),
        );
      }
      expect(
        (await repository.load(ProductivityItemType.note)).map((i) => i.title),
        ['C', 'B', 'A'],
      );
      expect(
        (await repository.load(ProductivityItemType.task)).map((i) => i.title),
        ['A', 'B', 'C'],
      );
    });

    test('stores reminders, recurrence, pin and due date', () async {
      final due = DateTime(2026, 9, 20, 18, 30);
      final id = await repository.save(
        type: ProductivityItemType.task,
        draft: ProductivityItemDraft(
          title: 'Sport',
          dueAt: due,
          isPinned: true,
          reminderOffsets: const [60, 0, 60],
          recurrence: TaskRecurrence.weekly,
        ),
      );
      final item = await byId(ProductivityItemType.task, id);
      expect(item.dueAt, due);
      expect(item.isPinned, isTrue);
      expect(item.reminderOffsets, [0, 60]);
      expect(item.recurrence, TaskRecurrence.weekly);
    });

    test('an update without optional fields keeps them', () async {
      final id = await repository.save(
        type: ProductivityItemType.task,
        draft: const ProductivityItemDraft(
          title: 'Sport',
          isPinned: true,
          reminderOffsets: [15],
          recurrence: TaskRecurrence.daily,
        ),
      );
      await repository.save(
        type: ProductivityItemType.task,
        id: id,
        draft: const ProductivityItemDraft(title: 'Sport renommé'),
      );
      final item = await byId(ProductivityItemType.task, id);
      expect(item.title, 'Sport renommé');
      expect(item.isPinned, isTrue);
      expect(item.reminderOffsets, [15]);
      expect(item.recurrence, TaskRecurrence.daily);
    });

    test('an update can clear reminders, recurrence and the due date', () async {
      final id = await repository.save(
        type: ProductivityItemType.task,
        draft: ProductivityItemDraft(
          title: 'x',
          dueAt: DateTime(2026, 9, 20),
          reminderOffsets: const [15],
          recurrence: TaskRecurrence.daily,
        ),
      );
      await repository.save(
        type: ProductivityItemType.task,
        id: id,
        draft: const ProductivityItemDraft(
          title: 'x',
          reminderOffsets: [],
          recurrence: TaskRecurrence.none,
        ),
      );
      final item = await byId(ProductivityItemType.task, id);
      expect(item.dueAt, isNull);
      expect(item.reminderOffsets, isEmpty);
      expect(item.recurrence, TaskRecurrence.none);
    });

    test('an update never changes the item type', () async {
      final id = await repository.save(
        type: ProductivityItemType.note,
        draft: const ProductivityItemDraft(title: 'Note'),
      );
      await repository.save(
        type: ProductivityItemType.task,
        id: id,
        draft: const ProductivityItemDraft(title: 'Piratée'),
      );
      expect((await byId(ProductivityItemType.note, id)).title, 'Note');
    });
  });

  group('pin, delete, restore and reorder', () {
    test('setPinned toggles the flag', () async {
      final id = await repository.save(
        type: ProductivityItemType.note,
        draft: const ProductivityItemDraft(title: 'Note'),
      );
      final note = await byId(ProductivityItemType.note, id);
      await repository.setPinned(note, true);
      expect((await byId(ProductivityItemType.note, id)).isPinned, isTrue);
      await repository.setPinned(note, false);
      expect((await byId(ProductivityItemType.note, id)).isPinned, isFalse);
    });

    test('restore brings a deleted item back identical', () async {
      final id = await repository.save(
        type: ProductivityItemType.task,
        draft: ProductivityItemDraft(
          title: 'Important',
          details: 'Détails',
          colorValue: 7,
          dueAt: DateTime(2026, 9, 20, 9),
          isPinned: true,
          reminderOffsets: const [30],
          recurrence: TaskRecurrence.monthly,
        ),
      );
      final original = await byId(ProductivityItemType.task, id);
      await repository.delete(original);
      expect(await repository.load(ProductivityItemType.task), isEmpty);

      await repository.restore(original);
      final restored = await byId(ProductivityItemType.task, id);
      expect(restored.title, original.title);
      expect(restored.details, original.details);
      expect(restored.colorValue, original.colorValue);
      expect(restored.dueAt, original.dueAt);
      expect(restored.isPinned, original.isPinned);
      expect(restored.sortOrder, original.sortOrder);
      expect(restored.reminderOffsets, original.reminderOffsets);
      expect(restored.recurrence, original.recurrence);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('reorder stores the given order', () async {
      for (final title in ['A', 'B', 'C']) {
        await repository.save(
          type: ProductivityItemType.task,
          draft: ProductivityItemDraft(title: title),
        );
      }
      final tasks = await repository.load(ProductivityItemType.task);
      await repository.reorder(tasks.reversed.toList());
      expect(
        (await repository.load(ProductivityItemType.task)).map((i) => i.title),
        ['C', 'B', 'A'],
      );
    });
  });

  group('completion log', () {
    late ProductivityItem task;

    setUp(() async {
      final id = await repository.save(
        type: ProductivityItemType.task,
        draft: const ProductivityItemDraft(title: 'Méditer'),
      );
      task = await byId(ProductivityItemType.task, id);
    });

    test('records completions within a range', () async {
      await repository.logCompletion(task, at: DateTime(2026, 9, 14, 8));
      await repository.logCompletion(task, at: DateTime(2026, 9, 18, 8));
      await repository.logCompletion(task, at: DateTime(2026, 9, 22, 8));

      final week = await repository.loadCompletions(
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 21),
      );
      expect(week, hasLength(2));
      expect(week.first.completedAt, DateTime(2026, 9, 14, 8));
      expect(week.every((c) => c.title == 'Méditer'), isTrue);
      expect(week.every((c) => c.taskId == task.id), isTrue);
    });

    test('range end is exclusive', () async {
      await repository.logCompletion(task, at: DateTime(2026, 9, 21));
      expect(
        await repository.loadCompletions(
          DateTime(2026, 9, 14),
          DateTime(2026, 9, 21),
        ),
        isEmpty,
      );
    });

    test('deleteCompletion removes one entry', () async {
      final id = await repository.logCompletion(task, at: DateTime(2026, 9, 15));
      await repository.logCompletion(task, at: DateTime(2026, 9, 16));
      await repository.deleteCompletion(id);
      final left = await repository.loadCompletions(
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
      );
      expect(left.single.completedAt, DateTime(2026, 9, 16));
    });

    test('deleteLatestCompletion removes the newest entry of that task',
        () async {
      final otherId = await repository.save(
        type: ProductivityItemType.task,
        draft: const ProductivityItemDraft(title: 'Autre'),
      );
      final other = await byId(ProductivityItemType.task, otherId);
      await repository.logCompletion(task, at: DateTime(2026, 9, 15));
      await repository.logCompletion(task, at: DateTime(2026, 9, 17));
      await repository.logCompletion(other, at: DateTime(2026, 9, 18));

      await repository.deleteLatestCompletion(task.id);

      final left = await repository.loadCompletions(
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
      );
      expect(left.map((c) => c.completedAt), [
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 18),
      ]);
    });

    test('the log keeps the title after the task is gone', () async {
      await repository.logCompletion(task, at: DateTime(2026, 9, 15));
      await repository.delete(task);
      final left = await repository.loadCompletions(
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
      );
      expect(left.single.title, 'Méditer');
    });
  });
}
