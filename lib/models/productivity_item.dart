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
  });

  final String title;
  final String details;
  final int colorValue;
  final bool isCompleted;
  final DateTime? dueAt;

  /// `null` keeps the stored value when updating an existing item.
  final bool? isPinned;
}
