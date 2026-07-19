import 'package:drift/drift.dart';
import 'package:mindful/core/services/drift_db_service.dart';
import 'package:mindful/models/productivity_item.dart';

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

  Future<void> save({
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
              due_at = ?, updated_at = ?
          WHERE id = ? AND item_type = ?
        ''',
        [
          draft.title.trim(),
          draft.details.trim(),
          draft.colorValue,
          draft.isCompleted ? 1 : 0,
          draft.dueAt?.millisecondsSinceEpoch,
          now,
          id,
          type.databaseValue,
        ],
      );
      return;
    }

    final orderRow = await db.customSelect(
      '''
        SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order
        FROM productivity_items WHERE item_type = ?
      ''',
      variables: [Variable.withString(type.databaseValue)],
    ).getSingle();
    final nextOrder = orderRow.read<int>('next_order');

    await db.customStatement(
      '''
        INSERT INTO productivity_items (
          item_type, title, details, color_value, is_completed, due_at,
          sort_order, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        type.databaseValue,
        draft.title.trim(),
        draft.details.trim(),
        draft.colorValue,
        draft.isCompleted ? 1 : 0,
        draft.dueAt?.millisecondsSinceEpoch,
        nextOrder,
        now,
        now,
      ],
    );
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
