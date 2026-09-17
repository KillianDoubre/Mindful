import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/core/database/app_database.dart';
import 'package:mindful/core/services/productivity_repository.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/models/task_recurrence.dart';
import 'package:mindful/providers/productivity/productivity_items_provider.dart';

import '../helpers/test_env.dart';

void main() {
  late AppDatabase db;
  late ProductivityItemsNotifier tasks;
  final repository = ProductivityRepository.instance;

  setUpAll(() {
    mockNativeChannel();
    db = useInMemoryDatabase();
  });

  setUp(() async {
    await repository.load(ProductivityItemType.task);
    await clearTables(db, ['productivity_items', 'task_completions']);
    nativeCalls.clear();
    tasks = ProductivityItemsNotifier(ProductivityItemType.task);
    await tasks.refresh();
  });

  tearDown(() => tasks.dispose());

  tearDownAll(() => db.close());

  Future<ProductivityItem> create(ProductivityItemDraft draft) async {
    final id = await tasks.save(draft);
    return tasks.state.value!.singleWhere((task) => task.id == id);
  }

  ProductivityItem current(int id) =>
      tasks.state.value!.singleWhere((task) => task.id == id);

  Future<int> completionsCount() async => (await repository.loadCompletions(
        DateTime(2000),
        DateTime(2100),
      ))
          .length;

  group('state', () {
    test('save refreshes the list', () async {
      await tasks.save(const ProductivityItemDraft(title: 'A'));
      expect(tasks.state.value!.map((t) => t.title), ['A']);
    });

    test('changes to tasks push reminders and suggestions to Android',
        () async {
      await tasks.save(const ProductivityItemDraft(title: 'A'));
      await pumpEventQueue();
      expect(callsTo('updateTaskReminders'), isNotEmpty);
      expect(callsTo('updateIntentionSuggestions'), isNotEmpty);
    });

    test('deleteById returns the removed task', () async {
      final task = await create(const ProductivityItemDraft(title: 'A'));
      final removed = await tasks.deleteById(task.id);
      expect(removed?.title, 'A');
      expect(tasks.state.value, isEmpty);
      expect(await tasks.deleteById(task.id), isNull);
    });

    test('restore undoes a delete', () async {
      final task = await create(const ProductivityItemDraft(title: 'A'));
      await tasks.delete(task);
      await tasks.restore(task);
      expect(current(task.id).title, 'A');
    });

    test('togglePinned flips the pin', () async {
      final task = await create(const ProductivityItemDraft(title: 'A'));
      await tasks.togglePinned(task);
      expect(current(task.id).isPinned, isTrue);
      await tasks.togglePinned(current(task.id));
      expect(current(task.id).isPinned, isFalse);
    });

    test('reorder moves an item', () async {
      for (final title in ['A', 'B', 'C']) {
        await tasks.save(ProductivityItemDraft(title: title));
      }
      await tasks.reorder(0, 2);
      expect(tasks.state.value!.map((t) => t.title), ['B', 'C', 'A']);
    });

    test('reorder ignores invalid positions', () async {
      await tasks.save(const ProductivityItemDraft(title: 'A'));
      await tasks.reorder(0, 5);
      await tasks.reorder(-1, 0);
      expect(tasks.state.value!.map((t) => t.title), ['A']);
    });
  });

  group('completing a one-off task', () {
    test('marks it done and logs it', () async {
      final task = await create(const ProductivityItemDraft(title: 'A'));
      final result = await tasks.completeTask(task);
      expect(result.nextDueAt, isNull);
      expect(current(task.id).isCompleted, isTrue);
      expect(await completionsCount(), 1);
    });

    test('keeps its other fields', () async {
      final task = await create(ProductivityItemDraft(
        title: 'A',
        details: 'd',
        dueAt: DateTime(2026, 9, 20),
        reminderOffsets: const [10],
        isPinned: true,
      ));
      await tasks.completeTask(task);
      final done = current(task.id);
      expect(done.details, 'd');
      expect(done.dueAt, DateTime(2026, 9, 20));
      expect(done.reminderOffsets, [10]);
      expect(done.isPinned, isTrue);
    });

    test('undo restores it and removes the log entry', () async {
      final task = await create(const ProductivityItemDraft(title: 'A'));
      final result = await tasks.completeTask(task);
      await tasks.undoCompletion(task, result);
      expect(current(task.id).isCompleted, isFalse);
      expect(await completionsCount(), 0);
    });

    test('unchecking removes the latest log entry', () async {
      final task = await create(const ProductivityItemDraft(title: 'A'));
      await tasks.completeTask(task);
      await tasks.uncompleteTask(current(task.id));
      expect(current(task.id).isCompleted, isFalse);
      expect(await completionsCount(), 0);
    });
  });

  group('completing a recurring task', () {
    final now = DateTime(2026, 9, 16, 12);

    test('moves it to the next occurrence instead of closing it', () async {
      final task = await create(ProductivityItemDraft(
        title: 'Sport',
        dueAt: DateTime(2026, 9, 16, 18),
        recurrence: TaskRecurrence.daily,
      ));
      final result = await tasks.completeTask(task, now: now);
      expect(result.nextDueAt, DateTime(2026, 9, 17, 18));
      final updated = current(task.id);
      expect(updated.isCompleted, isFalse);
      expect(updated.dueAt, DateTime(2026, 9, 17, 18));
      expect(updated.recurrence, TaskRecurrence.daily);
      expect(await completionsCount(), 1);
    });

    test('a late task jumps past today', () async {
      final task = await create(ProductivityItemDraft(
        title: 'Sport',
        dueAt: DateTime(2026, 9, 1, 8),
        recurrence: TaskRecurrence.weekly,
      ));
      final result = await tasks.completeTask(task, now: now);
      expect(result.nextDueAt!.isAfter(now), isTrue);
      expect(result.nextDueAt!.weekday, DateTime(2026, 9, 1).weekday);
    });

    test('without a due date it repeats from today', () async {
      final task = await create(const ProductivityItemDraft(
        title: 'Lire',
        recurrence: TaskRecurrence.daily,
      ));
      final result = await tasks.completeTask(task, now: now);
      expect(result.nextDueAt, DateTime(2026, 9, 17, 18));
    });

    test('each completion is logged', () async {
      var task = await create(ProductivityItemDraft(
        title: 'Sport',
        dueAt: DateTime(2026, 9, 16, 18),
        recurrence: TaskRecurrence.daily,
      ));
      for (var i = 0; i < 3; i++) {
        await tasks.completeTask(task, now: now.add(Duration(days: i)));
        task = current(task.id);
      }
      expect(await completionsCount(), 3);
      expect(task.dueAt, DateTime(2026, 9, 19, 18));
    });

    test('undo brings back the previous due date', () async {
      final task = await create(ProductivityItemDraft(
        title: 'Sport',
        dueAt: DateTime(2026, 9, 16, 18),
        recurrence: TaskRecurrence.daily,
      ));
      final result = await tasks.completeTask(task, now: now);
      await tasks.undoCompletion(task, result);
      expect(current(task.id).dueAt, DateTime(2026, 9, 16, 18));
      expect(await completionsCount(), 0);
    });

    test('undo of a task that had no due date clears it again', () async {
      final task = await create(const ProductivityItemDraft(
        title: 'Lire',
        recurrence: TaskRecurrence.daily,
      ));
      final result = await tasks.completeTask(task, now: now);
      await tasks.undoCompletion(task, result);
      expect(current(task.id).dueAt, isNull);
    });
  });
}
