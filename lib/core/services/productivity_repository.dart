import 'package:drift/drift.dart';
import 'package:mindful/core/services/drift_db_service.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/models/task_recurrence.dart';

/// Local persistence for personal notes and tasks.
///
/// The table is created lazily so existing personal databases gain the feature
/// without rewriting or risking the application's historical Drift migrations.
class ProductivityRepository {
  ProductivityRepository._();

  static final ProductivityRepository instance = ProductivityRepository._();

  Future<void>? _initialization;

  Future<void> _ensureInitialized() => _initialization ??= _createTable();

  Future<void> _createTable() async {
    final db = DriftDbService.instance.driftDb;
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS productivity_items (
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
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS productivity_items_type_order
      ON productivity_items(item_type, sort_order)
    ''');

    // Columns added after the table first shipped
    final columns = await db
        .customSelect('PRAGMA table_info(productivity_items)')
        .map((row) => row.read<String>('name'))
        .get();
    if (!columns.contains('recurrence')) {
      await db.customStatement(
        'ALTER TABLE productivity_items '
        "ADD COLUMN recurrence TEXT NOT NULL DEFAULT ''",
      );
    }
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS task_completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        completed_at INTEGER NOT NULL
      )
    ''');
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS task_completions_date
      ON task_completions(completed_at)
    ''');
    if (!columns.contains('reminders')) {
      await db.customStatement(
        'ALTER TABLE productivity_items '
        "ADD COLUMN reminders TEXT NOT NULL DEFAULT ''",
      );
    }
    if (!columns.contains('is_pinned')) {
      await db.customStatement(
        'ALTER TABLE productivity_items '
        'ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<List<ProductivityItem>> load(ProductivityItemType type) async {
    await _ensureInitialized();
    final rows = await DriftDbService.instance.driftDb.customSelect(
      '''
        SELECT * FROM productivity_items
        WHERE item_type = ?
        ORDER BY sort_order ASC, updated_at DESC
      ''',
      variables: [Variable.withString(type.databaseValue)],
    ).get();
    return rows.map((row) => ProductivityItem.fromDatabase(row.data)).toList();
  }

  /// Creates or updates an item and returns its id.
  ///
  /// New notes are placed first, like Google Keep; new tasks go last.
  Future<int> save({
    required ProductivityItemType type,
    required ProductivityItemDraft draft,
    int? id,
  }) async {
    await _ensureInitialized();
    final db = DriftDbService.instance.driftDb;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (id != null) {
      await db.customStatement(
        '''
          UPDATE productivity_items
          SET title = ?, details = ?, color_value = ?, is_completed = ?,
              due_at = ?, is_pinned = COALESCE(?, is_pinned),
              reminders = COALESCE(?, reminders),
              recurrence = COALESCE(?, recurrence), updated_at = ?
          WHERE id = ? AND item_type = ?
        ''',
        [
          draft.title.trim(),
          draft.details.trim(),
          draft.colorValue,
          draft.isCompleted ? 1 : 0,
          draft.dueAt?.millisecondsSinceEpoch,
          switch (draft.isPinned) {
            null => null,
            final pinned => pinned ? 1 : 0,
          },
          switch (draft.reminderOffsets) {
            null => null,
            final offsets => encodeReminderOffsets(offsets),
          },
          draft.recurrence?.databaseValue,
          now,
          id,
          type.databaseValue,
        ],
      );
      return id;
    }

    final placeFirst = type == ProductivityItemType.note;
    final orderRow = await db.customSelect(
      placeFirst
          ? '''
              SELECT COALESCE(MIN(sort_order), 1) - 1 AS next_order
              FROM productivity_items WHERE item_type = ?
            '''
          : '''
              SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order
              FROM productivity_items WHERE item_type = ?
            ''',
      variables: [Variable.withString(type.databaseValue)],
    ).getSingle();
    final nextOrder = orderRow.read<int>('next_order');

    return db.customInsert(
      '''
        INSERT INTO productivity_items (
          item_type, title, details, color_value, is_completed, due_at,
          sort_order, is_pinned, created_at, updated_at, reminders,
          recurrence
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withString(type.databaseValue),
        Variable.withString(draft.title.trim()),
        Variable.withString(draft.details.trim()),
        Variable.withInt(draft.colorValue),
        Variable.withInt(draft.isCompleted ? 1 : 0),
        Variable<int>(draft.dueAt?.millisecondsSinceEpoch),
        Variable.withInt(nextOrder),
        Variable.withInt((draft.isPinned ?? false) ? 1 : 0),
        Variable.withInt(now),
        Variable.withInt(now),
        Variable.withString(
          encodeReminderOffsets(draft.reminderOffsets ?? const []),
        ),
        Variable.withString(
          (draft.recurrence ?? TaskRecurrence.none).databaseValue,
        ),
      ],
    );
  }

  Future<void> setPinned(ProductivityItem item, bool isPinned) async {
    await _ensureInitialized();
    await DriftDbService.instance.driftDb.customStatement(
      'UPDATE productivity_items SET is_pinned = ? WHERE id = ?',
      [isPinned ? 1 : 0, item.id],
    );
  }

  /// Re-inserts a deleted item exactly as it was (same id, order and dates).
  Future<void> restore(ProductivityItem item) async {
    await _ensureInitialized();
    await DriftDbService.instance.driftDb.customInsert(
      '''
        INSERT OR REPLACE INTO productivity_items (
          id, item_type, title, details, color_value, is_completed, due_at,
          sort_order, is_pinned, created_at, updated_at, reminders,
          recurrence
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withInt(item.id),
        Variable.withString(item.type.databaseValue),
        Variable.withString(item.title),
        Variable.withString(item.details),
        Variable.withInt(item.colorValue),
        Variable.withInt(item.isCompleted ? 1 : 0),
        Variable<int>(item.dueAt?.millisecondsSinceEpoch),
        Variable.withInt(item.sortOrder),
        Variable.withInt(item.isPinned ? 1 : 0),
        Variable.withInt(item.createdAt.millisecondsSinceEpoch),
        Variable.withInt(item.updatedAt.millisecondsSinceEpoch),
        Variable.withString(encodeReminderOffsets(item.reminderOffsets)),
        Variable.withString(item.recurrence.databaseValue),
      ],
    );
  }

  /// Records that [task] was done and returns the log entry id.
  Future<int> logCompletion(ProductivityItem task, {DateTime? at}) async {
    await _ensureInitialized();
    return DriftDbService.instance.driftDb.customInsert(
      'INSERT INTO task_completions (task_id, title, completed_at) '
      'VALUES (?, ?, ?)',
      variables: [
        Variable.withInt(task.id),
        Variable.withString(task.title),
        Variable.withInt((at ?? DateTime.now()).millisecondsSinceEpoch),
      ],
    );
  }

  Future<void> deleteCompletion(int completionId) async {
    await _ensureInitialized();
    await DriftDbService.instance.driftDb.customStatement(
      'DELETE FROM task_completions WHERE id = ?',
      [completionId],
    );
  }

  /// Removes the most recent completion of [taskId], when a task is unchecked.
  Future<void> deleteLatestCompletion(int taskId) async {
    await _ensureInitialized();
    await DriftDbService.instance.driftDb.customStatement(
      '''
        DELETE FROM task_completions WHERE id = (
          SELECT id FROM task_completions WHERE task_id = ?
          ORDER BY completed_at DESC LIMIT 1
        )
      ''',
      [taskId],
    );
  }

  /// Completions within [start] (inclusive) and [end] (exclusive).
  Future<List<TaskCompletion>> loadCompletions(
    DateTime start,
    DateTime end,
  ) async {
    await _ensureInitialized();
    final rows = await DriftDbService.instance.driftDb.customSelect(
      '''
        SELECT * FROM task_completions
        WHERE completed_at >= ? AND completed_at < ?
        ORDER BY completed_at ASC
      ''',
      variables: [
        Variable.withInt(start.millisecondsSinceEpoch),
        Variable.withInt(end.millisecondsSinceEpoch),
      ],
    ).get();
    return [
      for (final row in rows)
        TaskCompletion(
          id: row.read<int>('id'),
          taskId: row.read<int>('task_id'),
          title: row.read<String>('title'),
          completedAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('completed_at'),
          ),
        ),
    ];
  }

  Future<void> delete(ProductivityItem item) async {
    await _ensureInitialized();
    await DriftDbService.instance.driftDb.customStatement(
      'DELETE FROM productivity_items WHERE id = ?',
      [item.id],
    );
  }

  Future<void> reorder(List<ProductivityItem> items) async {
    await _ensureInitialized();
    final db = DriftDbService.instance.driftDb;
    await db.transaction(() async {
      for (var index = 0; index < items.length; index++) {
        await db.customStatement(
          'UPDATE productivity_items SET sort_order = ? WHERE id = ?',
          [index, items[index].id],
        );
      }
    });
  }
}
