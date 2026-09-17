import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/core/services/productivity_repository.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/models/task_recurrence.dart';

import '../helpers/test_env.dart';

/// A database created by the first release of notes and tasks, before pins,
/// reminders, recurrence and the completion log existed.
void main() {
  test('upgrades an older table without losing data', () async {
    mockNativeChannel();
    final db = useInMemoryDatabase();
    await db.customStatement('''
      CREATE TABLE productivity_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_type TEXT NOT NULL,
        title TEXT NOT NULL,
        details TEXT NOT NULL DEFAULT '',
        color_value INTEGER NOT NULL DEFAULT 0,
        is_completed INTEGER NOT NULL DEFAULT 0,
        due_at INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    final now = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    await db.customStatement(
      '''
        INSERT INTO productivity_items
          (item_type, title, details, created_at, updated_at)
        VALUES ('task', 'Ancienne tâche', 'texte', ?, ?)
      ''',
      [now, now],
    );

    final repository = ProductivityRepository.instance;
    final tasks = await repository.load(ProductivityItemType.task);

    expect(tasks.single.title, 'Ancienne tâche');
    expect(tasks.single.details, 'texte');
    expect(tasks.single.isPinned, isFalse);
    expect(tasks.single.reminderOffsets, isEmpty);
    expect(tasks.single.recurrence, TaskRecurrence.none);

    final columns = await db
        .customSelect('PRAGMA table_info(productivity_items)')
        .map((row) => row.read<String>('name'))
        .get();
    expect(columns, containsAll(['is_pinned', 'reminders', 'recurrence']));

    // The new features work on the upgraded table
    await repository.save(
      type: ProductivityItemType.task,
      id: tasks.single.id,
      draft: const ProductivityItemDraft(
        title: 'Ancienne tâche',
        isPinned: true,
        reminderOffsets: [30],
        recurrence: TaskRecurrence.daily,
      ),
    );
    final upgraded =
        (await repository.load(ProductivityItemType.task)).single;
    expect(upgraded.isPinned, isTrue);
    expect(upgraded.reminderOffsets, [30]);
    expect(upgraded.recurrence, TaskRecurrence.daily);

    final completionId = await repository.logCompletion(upgraded);
    expect(completionId, greaterThan(0));

    await db.close();
  });
}
