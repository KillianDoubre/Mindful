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

  Future<void> save(ProductivityItemDraft draft, {int? id}) async {
    await _repository.save(type: type, draft: draft, id: id);
    await refresh();
  }

  Future<void> delete(ProductivityItem item) async {
    await _repository.delete(item);
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
