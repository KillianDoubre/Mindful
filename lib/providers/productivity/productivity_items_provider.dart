import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/core/services/productivity_repository.dart';
import 'package:mindful/models/productivity_item.dart';

final productivityItemsProvider = StateNotifierProvider.family<
    ProductivityItemsNotifier,
    AsyncValue<List<ProductivityItem>>,
    ProductivityItemType>((ref, type) => ProductivityItemsNotifier(type));

class ProductivityItemsNotifier
    extends StateNotifier<AsyncValue<List<ProductivityItem>>> {
  ProductivityItemsNotifier(this.type) : super(const AsyncLoading()) {
    refresh();
  }

  final ProductivityItemType type;
  final ProductivityRepository _repository = ProductivityRepository.instance;

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _repository.load(type));
  }

  /// Creates or updates an item and returns its id.
  Future<int> save(ProductivityItemDraft draft, {int? id}) async {
    final savedId = await _repository.save(type: type, draft: draft, id: id);
    await refresh();
    return savedId;
  }

  Future<void> delete(ProductivityItem item) async {
    await _repository.delete(item);
    await refresh();
  }

  /// Deletes the item with [id] and returns it as it was, so it can be restored.
  Future<ProductivityItem?> deleteById(int id) async {
    await refresh();
    final item = state.valueOrNull?.where((item) => item.id == id).firstOrNull;
    if (item == null) return null;
    await delete(item);
    return item;
  }

  Future<void> restore(ProductivityItem item) async {
    await _repository.restore(item);
    await refresh();
  }

  Future<void> togglePinned(ProductivityItem item) async {
    await _repository.setPinned(item, !item.isPinned);
    await refresh();
  }

  Future<void> toggleCompleted(ProductivityItem item) => save(
        ProductivityItemDraft(
          title: item.title,
          details: item.details,
          colorValue: item.colorValue,
          isCompleted: !item.isCompleted,
          dueAt: item.dueAt,
        ),
        id: item.id,
      );

  Future<void> reorder(int oldIndex, int newIndex) async {
    final previous = state.valueOrNull;
    if (previous == null ||
        oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= previous.length ||
        newIndex >= previous.length) {
      return;
    }

    final reordered = [...previous];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await setOrder(reordered);
  }

  Future<void> setOrder(List<ProductivityItem> reordered) async {
    final previous = state.valueOrNull;
    if (previous == null ||
        reordered.length != previous.length ||
        !reordered.map((item) => item.id).toSet().containsAll(
              previous.map((item) => item.id),
            )) {
      return;
    }

    state = AsyncData([
      for (var index = 0; index < reordered.length; index++)
        reordered[index].copyWith(sortOrder: index),
    ]);

    try {
      await _repository.reorder(reordered);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}
